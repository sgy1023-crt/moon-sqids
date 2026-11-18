import assert from 'node:assert/strict';
import { once } from 'node:events';
import { open, mkdtemp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';

const fixture = 'examples/rollout/manifest.json';
const work = await mkdtemp(join(tmpdir(), 'moonsqids-cli-'));
const input = join(work, 'ids.txt');
const report = join(work, 'report.jsonl');
const v2 = 'v2~Atbx25UEDm';
const cli = (args) => spawnSync(process.execPath, ['cmd/moonsqids.mjs', ...args], {
  encoding: 'utf8',
  timeout: 60_000,
});
const plan = (source, target) => cli(['plan', fixture, source, target]);

try {
  const data = Buffer.concat([
    Buffer.from(`\uFEFFA6da\r\nv1~A6da\n${v2}\nv9~A6da\n`),
    Buffer.alloc(70_000, 97),
    Buffer.from([10, 0xff, 10]),
    Buffer.from('v1~bM'),
  ]);
  await writeFile(input, data);
  const result = plan(input, report);
  assert.equal(result.status, 2, result.error?.message ?? result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { rows: 7, changed: 2, unchanged: 1, rejected: 4 });
  const saved = await readFile(report, 'utf8');
  const rows = saved.trimEnd().split('\n').map(JSON.parse);
  assert.deepEqual(rows.map(row => row.line), [1, 2, 3, 4, 5, 6, 7]);
  for (const row of rows.slice(0, 3)) {
    assert.equal(row.target_id, v2);
    assert.deepEqual(row.numbers, ['12345']);
  }
  assert.deepEqual(rows.slice(3).map(row => row.error), [
    'unknown_version', 'row_too_long', 'invalid_utf8', 'field_out_of_range',
  ]);

  assert.equal(plan(input, report).status, 1);
  assert.equal(await readFile(report, 'utf8'), saved);
  assert.equal(plan(input, input).status, 1);
  assert.deepEqual(await readFile(input), data);
  const repeat = join(work, 'repeat.jsonl');
  assert.equal(plan(input, repeat).status, 2);
  assert.equal(await readFile(repeat, 'utf8'), saved);
  assert.equal(plan(join(work, 'missing-input'), join(work, 'missing-report')).status, 1);

  const previous = JSON.parse(await readFile(fixture, 'utf8'));
  previous.current = 'v1';
  const previousPath = join(work, 'old.json');
  await writeFile(previousPath, JSON.stringify(previous));
  const check = cli(['check-upgrade', previousPath, fixture]);
  assert.equal(check.status, 0, check.error?.message ?? check.stderr);
  previous.profiles[0].alphabet = previous.profiles[0].alphabet.slice(1) + 'a';
  await writeFile(previousPath, JSON.stringify(previous));
  const incompatible = cli(['check-upgrade', fixture, previousPath]);
  assert.equal(incompatible.status, 1);
  assert.match(incompatible.stderr, /incompatible_upgrade.*ChangedVersion/);

  const batchSize = 100_000;
  const batchInput = join(work, '100k.txt');
  await writeFile(batchInput, 'A6da\n'.repeat(batchSize));
  const interrupted = join(work, 'interrupted.jsonl');
  const child = spawn(process.execPath, ['cmd/moonsqids.mjs', 'plan', fixture, batchInput, interrupted], {
    stdio: 'ignore',
  });
  const exited = once(child, 'exit');
  // Observe a nonempty staged report before simulating process loss.
  const deadline = performance.now() + 10_000;
  let sawProgress = false;
  try {
    while (performance.now() < deadline && child.exitCode === null) {
      const names = await readdir(work);
      for (const name of names.filter(name => name.startsWith('.moonsqids-'))) {
        const bytes = await stat(join(work, name, 'report.jsonl')).then(file => file.size, error => {
          if (error.code === 'ENOENT') return 0;
          throw error;
        });
        if (bytes > 0) sawProgress = true;
      }
      if (sawProgress) break;
      await new Promise(resolve => setTimeout(resolve, 5));
    }
    assert.ok(sawProgress, 'the interrupted run must have staged data');
  } finally {
    child.kill();
    await exited;
  }
  await assert.rejects(stat(interrupted), { code: 'ENOENT' });
  assert.equal((await stat(batchInput)).size, 5 * batchSize);

  const started = performance.now();
  const retried = plan(batchInput, interrupted);
  const elapsed = performance.now() - started;
  assert.equal(retried.status, 0, retried.error?.message ?? retried.stderr);
  assert.deepEqual(JSON.parse(retried.stdout), { rows: batchSize, changed: batchSize, unchanged: 0, rejected: 0 });
  const output = await open(interrupted);
  try {
    const end = Buffer.alloc(512);
    const size = (await output.stat()).size;
    await output.read(end, 0, end.length, size - end.length);
    const last = JSON.parse(end.toString('utf8').trimEnd().split('\n').at(-1));
    assert.equal(last.line, batchSize);
    assert.equal(last.target_id, v2);
  } finally {
    await output.close();
  }
  console.log(`Migration CLI passed mixed rows, invalid UTF-8, long rows, overwrite protection, and retry after interruption (${batchSize} IDs in ${Math.round(elapsed)} ms).`);
} finally {
  await rm(work, { recursive: true, force: true });
}
