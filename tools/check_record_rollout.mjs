import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { recordServer } from '../examples/rollout/server.mjs';

const active = JSON.parse(await readFile(new URL('../examples/rollout/manifest.json', import.meta.url)));
const staged = { ...active, current: 'v1' };
const original = { ...staged, profiles: staged.profiles.slice(0, 1) };
const activeLink = '/records/v2~Atbx25UEDm';
const bareLink = '/records/A6da';

async function withServer(policy, check) {
  const server = recordServer(JSON.stringify(policy));
  try {
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    await check(path => fetch(`http://127.0.0.1:${server.address().port}${path}`, {
      signal: AbortSignal.timeout(5_000),
    }));
  } finally {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
}

await withServer(original, async fetch => {
  const response = await fetch(bareLink);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).number, '12345');
  assert.equal((await fetch(activeLink)).status, 404);
});
await withServer(staged, async fetch => {
  const issued = await fetch('/record-links/12345');
  assert.equal(issued.status, 200);
  assert.deepEqual(await issued.json(), { href: '/records/v1~A6da' });
  const newResponse = await fetch(activeLink);
  assert.equal(newResponse.status, 200);
  assert.equal((await newResponse.json()).number, '12345');
});
await withServer(active, async fetch => {
  const issued = await fetch('/record-links/12345');
  assert.equal(issued.status, 200);
  assert.deepEqual(await issued.json(), { href: activeLink });
  for (const link of [bareLink, activeLink, '/records/v1~A6da']) {
    const response = await fetch(link);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { number: '12345', name: 'Warehouse inventory' });
  }
  for (const bad of ['/records/v9~A6da', '/records/v2~Atbx25UEDm~0', '/records/v1~bM', '/records/%2F', '/record-links/99999']) {
    assert.equal((await fetch(bad)).status, 404, bad);
  }
  const second = await fetch('/record-links/12346');
  const secondRecord = await fetch((await second.json()).href);
  assert.equal((await secondRecord.json()).number, '12346');
});
console.log('HTTP rollout passed original, reader staging, and writer switch with stable record identity.');
