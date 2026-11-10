import assert from 'node:assert/strict';
import Sqids from 'sqids';
import { runMoonBit, selectedTargets } from './runner.mjs';

const reference = new Sqids();
const fromJavaScript = [7, 3, 12345];
const fromMoonBit = [12345, Number.MAX_SAFE_INTEGER];
const jsId = reference.encode(fromJavaScript);

for (const target of selectedTargets(process.argv.slice(2))) {
  const [decoded, encoded] = runMoonBit(target, [
    { id: jsId },
    { numbers: fromMoonBit.map(String) },
  ]);
  assert.deepEqual(decoded, { value: fromJavaScript.map(String) });
  assert.equal(typeof encoded.value, 'string', JSON.stringify(encoded));
  const jsNumbers = reference.decode(encoded.value);
  assert.deepEqual(jsNumbers, fromMoonBit);
  console.log(`JavaScript → MoonBit/${target}: ${jsId} → ${JSON.stringify(decoded.value.map(Number))}`);
  console.log(`MoonBit/${target} → JavaScript: ${encoded.value} → ${JSON.stringify(jsNumbers)}`);
}
