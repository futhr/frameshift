import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const records = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length, 256);
for (const [index, record] of records.entries()) {
  assert.equal(record.seed, index);
  const names = record.nodes.map((n) => n.id);
  // Boolean transitive closure finds each unique descendant. The production
  // compiler instead follows single input feeds and recursively adds payloads.
  const reach = names.map((from) => names.map((to) => record.edges.some((edge) => edge[0] === from && edge[1] === to)));
  for (let k = 0; k < names.length; k++) {
    for (let i = 0; i < names.length; i++) {
      for (let j = 0; j < names.length; j++) reach[i][j] ||= reach[i][k] && reach[k][j];
    }
  }
  assert.ok(names.every((_, i) => !reach[i][i]));
  const frame = names.indexOf('frame');
  const expected = record.nodes.map((node, i) => {
    const descendants = record.nodes.filter((_, j) => reach[i][j]);
    const payload = descendants.reduce(([low, high], child) => [low + child.mass[0], high + child.mass[1]], [0, 0]);
    const input = i === frame ? null : [node.mass[0] + payload[0], node.mass[1] + payload[1]];
    assert.equal(record.edges.filter((edge) => edge[1] === node.id).length, i === frame ? 0 : 1);
    assert.ok(i === frame || reach[frame][i]);
    return { id: node.id, input, payload: descendants.length ? payload : null, root: 'frame' };
  });
  assert.deepEqual(record.actual, expected, `mounting tree ${index}`);
}
console.log('256 mounting trees match independent descendant-set mass accounting');
