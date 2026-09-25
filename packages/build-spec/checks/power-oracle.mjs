// Independent enumeration of each integer point in the finite voltage domain.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const lines = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(lines.length, 441);
const seen = new Set();
for (const row of lines) {
  for (const range of [row.output, row.input]) {
    assert.equal(range.length, 2);
    assert.ok(range.every(n => Number.isInteger(n) && n >= 0 && n <= 5));
    assert.ok(range[0] <= range[1]);
  }
  const key = JSON.stringify([row.output, row.input]);
  assert.ok(!seen.has(key));
  seen.add(key);
  const points = ([low, high]) => Array.from({length: high - low + 1}, (_, i) => low + i);
  const permitted = new Set(points(row.input));
  const contained = points(row.output).every(point => permitted.has(point));
  assert.equal(row.outcome, contained ? 'compatible' : 'incompatible');
}
console.log('All 441 finite voltage interval pairs match independent point containment');
