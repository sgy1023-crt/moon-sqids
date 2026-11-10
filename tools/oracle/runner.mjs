import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const targets = ['native', 'js'];
const timeoutMs = 60_000;
const maxBatchBytes = 16_000;

export function selectedTargets(args) {
  if (args.length === 0) return targets;
  if (args.length === 1 && targets.includes(args[0])) return args;
  throw new Error('Expected an optional backend (native or js)');
}

export function runMoonBit(target, requests) {
  const deadline = Date.now() + timeoutMs;
  return batchesOf(requests).flatMap(batch => {
    const timeout = deadline - Date.now();
    if (timeout <= 0) throw new Error(`${target} exceeded ${timeoutMs} ms`);

    const result = spawnSync('moon', ['run', '--target', target, '--quiet', 'examples/interop'], {
      cwd: root,
      encoding: 'utf8',
      env: { ...process.env, MOONSQIDS_INTEROP_BATCH: JSON.stringify(batch) },
      timeout,
    });
    if (result.error || result.status !== 0) {
      throw new Error(
        `${target} interop runner failed (${result.error ?? result.signal ?? result.status})\n`
        + `${result.stderr}\n${result.stdout}`,
      );
    }

    const replies = JSON.parse(result.stdout);
    if (!Array.isArray(replies) || replies.length !== batch.length) {
      throw new Error(`${target} runner returned ${JSON.stringify(replies)} for ${batch.length} requests`);
    }
    return replies;
  });
}

function batchesOf(requests) {
  const batches = [];
  let batch = [];
  let bytes = 2;
  for (const request of requests) {
    const size = Buffer.byteLength(JSON.stringify(request)) + 1;
    if (size + 2 > maxBatchBytes) throw new Error('Interop request exceeds the batch size limit');
    if (bytes + size > maxBatchBytes) {
      batches.push(batch);
      batch = [];
      bytes = 2;
    }
    batch.push(request);
    bytes += size;
  }
  if (batch.length > 0) batches.push(batch);
  return batches;
}
