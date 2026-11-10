import { isDeepStrictEqual } from 'node:util';
import Sqids from 'sqids';
import { runMoonBit, selectedTargets } from './runner.mjs';

const seed = 0x4d535149;
const max = Number.MAX_SAFE_INTEGER;
const defaultAlphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const shuffledAlphabet = 'FxnXM1kBN6cuhsAvjW3Co7l2RePyY8DwaU04Tzt9fHQrqSVKdpimLGIJOgb5ZE';

const configs = [
  ['default', {}],
  ['without blocklist', { blocklist: [] }],
  ['padded', { min_length: 10 }],
  ['maximum padding', { min_length: 255 }],
  ['shuffled', { alphabet: shuffledAlphabet, min_length: 24 }],
  ['short alphabet', { alphabet: 'abc', min_length: 255 }],
  ['ASCII punctuation and controls', { alphabet: 'aB! \t\n\0', min_length: 10, blocklist: [] }],
  ['uppercase alphabet', { alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', blocklist: ['sxnzkl'] }],
  ['regeneration', { blocklist: [
    '86Rf07', 'se8ojK', 'ArUO', '86u', 'vFo', 'JSwXFaosAN', 'OCjV9JK64o', 'rBHf', '79SM', '7tE6',
    'lP3i', 'hfxX', '', 'ab', 'zz!',
  ] }],
  ['exhausted alphabet', { alphabet: 'abc', min_length: 3, blocklist: ['cab', 'abc', 'bca'] }],
];

function seededGenerator() {
  let state = seed;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state >>> 0;
  };
}

function makeCases() {
  const random = seededGenerator();
  const numbers = [
    [], [0], [1, 2, 3], [12345], [7, 3, 12345], [100], [1000], [100000], [4572721],
    [max], [0, max], [max - 1, 0, max], [1_000_000, 2_000_000], [100, 202, 303, 404],
    [101, 202, 303, 404, 505, 606, 707], Array.from({ length: 100 }, (_, index) => index),
  ];
  for (let index = 0; index < 64; index++) {
    numbers.push(Array.from({ length: 1 + (random() % 12) }, (_, position) => {
      if (position % 3 === 0) return random() % 256;
      if (position % 3 === 1) return random();
      return (random() % (2 ** 21)) * (2 ** 32) + random();
    }));
  }

  const cases = [];
  for (const [label, options] of configs) {
    const reference = referenceCodec(options);
    for (const values of numbers) {
      const request = { ...options, numbers: values.map(String) };
      const expected = expectedEncode(reference, values);
      cases.push({ label, request, expected });
      if ('value' in expected) cases.push(decodeCase(label, options, reference, expected.value));
    }

    for (const values of [[-1], [max + 1], [1, max + 1]]) {
      cases.push({
        label,
        request: { ...options, numbers: values.map(String) },
        expected: expectedEncode(reference, values),
      });
    }

    const alphabet = options.alphabet ?? defaultAlphabet;
    const validArbitraryId = () => Array.from({ length: random() % 45 }, () =>
      alphabet[random() % alphabet.length]).join('');
    const ids = [
      '', '86Rf07*', '86Rf07xd4z*', '雪', 'aho1e', 'se8ojk', 'bMM', 'pup591lWlB',
      ...Array.from({ length: 20 }, validArbitraryId),
    ];
    for (const id of ids) cases.push(decodeCase(label, options, reference, id));
  }

  for (const options of [
    { alphabet: '' }, { alphabet: 'ab' }, { alphabet: 'abca' }, { alphabet: 'abé' },
    { min_length: -1 }, { min_length: 256 },
  ]) {
    let expected;
    try {
      referenceCodec(options);
    } catch {
      expected = { error: 'config' };
    }
    if (!expected) throw new Error(`Oracle accepted invalid options ${JSON.stringify(options)}`);
    cases.push({ label: 'invalid config', request: { ...options, numbers: ['0'] }, expected });
  }
  return cases;
}

function referenceCodec(options) {
  return new Sqids({
    alphabet: options.alphabet,
    minLength: options.min_length,
    blocklist: options.blocklist === undefined ? undefined : new Set(options.blocklist),
  });
}

function expectedEncode(reference, values) {
  try {
    return { value: reference.encode(values) };
  } catch (error) {
    if (!/Encoding supports numbers between|Reached max attempts to re-generate the ID/.test(error.message)) {
      throw error;
    }
    return { error: 'encode' };
  }
}

function decodeCase(label, options, reference, id) {
  const decoded = reference.decode(id);
  // JS returns unsafe numbers. The MoonBit API rejects a value outside the shared range.
  const expected = decoded.every(Number.isSafeInteger)
    ? { value: decoded.map(String) }
    : { error: 'decode' };
  return { label, request: { ...options, id }, expected };
}

const cases = makeCases();
let failures = 0;
for (const target of selectedTargets(process.argv.slice(2))) {
  let actual;
  try {
    actual = runMoonBit(target, cases.map(test => test.request));
  } catch (error) {
    console.error(error);
    failures++;
    continue;
  }

  let mismatches = 0;
  for (const [index, { label, request, expected }] of cases.entries()) {
    const reply = actual[index];
    const matches = 'error' in expected
      ? reply?.error === expected.error && !('value' in reply)
      : isDeepStrictEqual(reply, expected);
    if (matches) continue;
    mismatches++;
    console.error(JSON.stringify({ target, index, label, request, expected, actual: reply }));
  }
  failures += mismatches;
  console.log(`${target}: ${cases.length - mismatches}/${cases.length} matched sqids@0.3.0, `
    + `${mismatches} mismatches (seed 0x${seed.toString(16)})`);
}
if (failures > 0) process.exitCode = 1;
