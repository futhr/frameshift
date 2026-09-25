import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const records = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length, 512);
const possible = [0, 1, 2].flatMap((from) => [1, 2, 3].map((to) => [from, to]));
for (const [mask, record] of records.entries()) {
  assert.equal(record.mask, mask);
  const edges = possible.filter((_, bit) => mask & (1 << bit));
  const degree = [0, 1, 2, 3].map((node) => edges.filter(([, to]) => to === node).length);
  // Remove all ambiguous feeds. Boolean closure then identifies the single
  // predecessor component of the display, without the compiler's port walk.
  const single = edges.filter(([, to]) => degree[to] === 1);
  const reach = [0, 1, 2, 3].map((from) => [0, 1, 2, 3].map((to) =>
    single.some(([a, b]) => a === from && b === to)));
  for (let k = 0; k < 4; k++) {
    for (let i = 0; i < 4; i++) {
      for (let j = 0; j < 4; j++) reach[i][j] ||= reach[i][k] && reach[k][j];
    }
  }
  const ancestors = [0, 1, 2, 3].filter((i) => i === 3 || reach[i][3]);
  const cycle = ancestors.some((i) => reach[i][i]);
  const self = single.some(([from, to]) => from === to && ancestors.includes(from));
  const root = reach[0][3];
  assert.ok(!(root && cycle));
  const expected = root ? 'compatible' : cycle ? 'incompatible' : 'unknown';
  const reason = root ? 'controller_route_present'
    : self ? 'self_connection'
    : cycle ? 'signal_route_cycle'
    : ancestors.some((i) => degree[i] > 1) ? 'multiple_signal_feeds' : 'missing_signal_feed';
  assert.equal(record.outcome, expected, `route mask ${mask}`);
  assert.equal(record.reason, reason, `route reason ${mask}`);
  assert.equal(new Set(record.inputs.map(JSON.stringify)).size, record.inputs.length);
}
console.log('All 512 directed signal topologies match an independent matrix-closure oracle');
