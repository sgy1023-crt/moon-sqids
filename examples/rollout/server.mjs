import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { openRegistry } from '../../_build/js/release/build/cmd/bridge/bridge.js';

const records = new Map([
  ['12345', { number: '12345', name: 'Warehouse inventory' }],
  ['12346', { number: '12346', name: 'Shipping manifest' }],
]);

function respond(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

export function recordServer(manifest) {
  const run = openRegistry(manifest);
  const ready = JSON.parse(run('ready', ''));
  if (!ready.ok) throw new Error(ready.detail);

  return createServer((request, response) => {
    if (request.method !== 'GET') {
      response.setHeader('allow', 'GET');
      return respond(response, 405, { error: 'method_not_allowed' });
    }
    const path = request.url.split('?', 1)[0];
    const lookup = /^\/records\/([A-Za-z0-9_~-]+)$/.exec(path);
    if (lookup) {
      const decoded = JSON.parse(run('decode', lookup[1]));
      const record = records.get(decoded.numbers?.[0]);
      if (!record) return respond(response, 404, { error: 'record_not_found' });
      return respond(response, 200, record);
    }
    const issue = /^\/record-links\/([0-9]+)$/.exec(path);
    if (issue && records.has(issue[1])) {
      const result = JSON.parse(run('encode', JSON.stringify([issue[1]])));
      if (result.error) return respond(response, 500, { error: result.error });
      return respond(response, 200, { href: `/records/${result.id}` });
    }
    return respond(response, 404, { error: 'record_not_found' });
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const path = process.argv[2] ?? new URL('./manifest.json', import.meta.url);
  const server = recordServer(await readFile(path, 'utf8'));
  server.listen(8080, '127.0.0.1', () => console.log('http://127.0.0.1:8080'));
}
