import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const records = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length, 256);
const bounds = (values) => [Math.min(...values), Math.max(...values)];
const power = (volts, currents) => {
  const products = volts.flatMap((v) => currents.map((i) => v * i / 1000));
  return [Math.floor(Math.min(...products)), Math.ceil(Math.max(...products))];
};
for (const [index, record] of records.entries()) {
  assert.equal(record.seed, index);
  // Enumerate all extreme source/drop choices at every hop. This does not call
  // the compiler's interval subtraction, demand sum, or milliwatt helpers.
  let arriving = record.voltage;
  for (let hop = 0; hop < record.length; hop++) {
    arriving = arriving.flatMap((v) => record.drop.map((drop) => v - drop));
  }
  let currents = [0];
  for (let branch = 0; branch < record.branches; branch++) {
    currents = currents.flatMap((sum) => record.current.map((load) => sum + load));
  }
  assert.deepEqual(record.effective_voltage, bounds(arriving), `voltage ${index}`);
  assert.deepEqual(record.effective_current, bounds(currents), `current ${index}`);
  assert.deepEqual(record.power, [power(record.voltage, currents), power(arriving, currents)], `power ${index}`);
}
console.log('256 passive chain/branch budgets match independent endpoint enumeration');
