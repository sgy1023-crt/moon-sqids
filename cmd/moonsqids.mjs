import { open, mkdtemp, link, unlink, rmdir } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { openRegistry, checkUpgrade } from '../_build/js/release/build/cmd/bridge/bridge.js';

const MAX_ROW_BYTES = 4096;
const MAX_MANIFEST_BYTES = 1024 * 1024;
const WRITE_BUFFER_SIZE = 64 * 1024;
const utf8 = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true });

async function manifest(path) {
  const file = await open(path, 'r');
  try {
    const stat = await file.stat();
    if (!stat.isFile() || stat.size > MAX_MANIFEST_BYTES) {
      throw new Error(`Expected a manifest file of at most ${MAX_MANIFEST_BYTES} bytes: ${path}`);
    }
    const bytes = Buffer.alloc(MAX_MANIFEST_BYTES + 1);
    let offset = 0;
    while (offset < bytes.length) {
      const { bytesRead } = await file.read(bytes, offset);
      if (bytesRead === 0) break;
      offset += bytesRead;
    }
    if (offset > MAX_MANIFEST_BYTES) throw new Error(`Manifest grew past the size limit: ${path}`);
    return utf8.decode(bytes.subarray(0, offset)).replace(/^\uFEFF/, '');
  } finally {
    await file.close();
  }
}

async function* lines(path) {
  const row = Buffer.alloc(MAX_ROW_BYTES);
  let used = 0;
  let overflow = false;
  const read = createReadStream(path);
  for await (const chunk of read) {
    for (let start = 0; start < chunk.length;) {
      const newline = chunk.indexOf(10, start);
      const end = newline === -1 ? chunk.length : newline;
      if (!overflow) {
        overflow = end - start > row.length - used;
        if (!overflow) used += chunk.copy(row, used, start, end);
      }
      if (newline === -1) break;
      yield overflow ? null : row.subarray(0, used);
      used = 0;
      overflow = false;
      start = newline + 1;
    }
  }
  if (overflow || used > 0) yield overflow ? null : row.subarray(0, used);
}

function planRow(run, bytes, line) {
  if (bytes === null) return { line, error: 'row_too_long' };
  let id;
  try {
    id = utf8.decode(bytes).replace(/\r$/, '');
    if (line === 1) id = id.replace(/^\uFEFF/, '');
  } catch (error) {
    if (!(error instanceof TypeError) || error.code !== 'ERR_ENCODING_INVALID_ENCODED_DATA') throw error;
    return { line, error: 'invalid_utf8' };
  }
  return { line, source_id: id, ...JSON.parse(run('plan', id)) };
}

async function plan(manifestPath, inputPath, reportPath) {
  const run = openRegistry(await manifest(manifestPath));
  const ready = JSON.parse(run('ready', ''));
  if (ready.error) throw new Error(`${ready.error}: ${ready.detail}`);

  const destination = resolve(reportPath);
  // The staging file shares the destination filesystem. An exclusive hard link
  // publishes a completed report and fails if another job already created it.
  const directory = await mkdtemp(join(dirname(destination), '.moonsqids-'));
  const staging = join(directory, 'report.jsonl');
  const counts = { rows: 0, changed: 0, unchanged: 0, rejected: 0 };
  try {
    const report = await open(staging, 'wx', 0o600);
    try {
      let batch = '';
      for await (const bytes of lines(inputPath)) {
        const row = planRow(run, bytes, ++counts.rows);
        if (row.error) counts.rejected++;
        else if (row.changed) counts.changed++;
        else counts.unchanged++;
        batch += JSON.stringify(row) + '\n';
        if (batch.length >= WRITE_BUFFER_SIZE) {
          await report.writeFile(batch);
          batch = '';
        }
      }
      await report.writeFile(batch);
      await report.sync();
    } finally {
      await report.close();
    }
    await link(staging, destination);
  } finally {
    try {
      await unlink(staging);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    } finally {
      await rmdir(directory);
    }
  }
  console.log(JSON.stringify(counts));
  return counts.rejected ? 2 : 0;
}

async function main([command, ...args]) {
  if (command === 'plan' && args.length === 3) return await plan(...args);
  if ((command === 'check-upgrade' || command === 'check-issuer') && args.length === 2) {
    const result = JSON.parse(checkUpgrade(
      await manifest(args[0]), await manifest(args[1]), command === 'check-issuer',
    ));
    if (result.error) throw new Error(`${result.error}: ${result.detail}`);
    console.log(JSON.stringify(result));
    return 0;
  }
  const usage = 'Usage: moonsqids check-upgrade OLD.json NEW.json\n'
    + '       moonsqids check-issuer READERS.json WRITER.json\n'
    + '       moonsqids plan MANIFEST.json INPUT.txt NEW-REPORT.jsonl';
  if (command === '--help' && args.length === 0) {
    console.log(usage);
    return 0;
  }
  throw new Error(usage);
}

try {
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
