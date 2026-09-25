import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const records = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length, 256);
const bounds = (values) => [Math.min(...values), Math.max(...values)];
const temperature = (values, operating) => ({
  required: bounds(values),
  outcome: values.every((v) => v >= operating[0] && v <= operating[1]) ? 'compatible' : 'incompatible',
});
for (const [index, record] of records.entries()) {
  assert.equal(record.seed, index);
  const inside = record.ambient.flatMap((a) => record.rise.map((r) => a + r));
  let heat = record.frame_heat;
  for (let unit = 0; unit < record.count; unit++) {
    heat = heat.flatMap((sum) => record.heat.map((h) => sum + h));
  }
  assert.deepEqual(record.actual, [
    temperature(inside, record.operating),
    temperature(record.ambient, record.operating),
    { required: bounds(heat), outcome: heat.every((h) => h <= record.capacity) ? 'compatible' : 'incompatible' },
  ], `thermal ${index}`);
}
console.log('256 thermal fixtures match independent extreme-choice enumeration');
