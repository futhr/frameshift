// Undirected transitive closure; independent of the production visited walk.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const rows = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(rows.length, 512);
for (let mask = 0; mask < 512; mask++) {
  const reach = Array.from({length:3}, (_, i) => Array.from({length:3}, (_, j) => i === j));
  for (let i=0; i<3; i++) for (let j=0; j<3; j++) if (mask & (1 << (i*3+j))) reach[i][j] = reach[j][i] = true;
  for (let k=0; k<3; k++) for (let i=0; i<3; i++) for (let j=0; j<3; j++) reach[i][j] ||= reach[i][k] && reach[k][j];
  const seen = new Set(), groups = [];
  for (let i=0; i<3; i++) if (!seen.has(i)) {
    const group = [];
    for (let j=0; j<3; j++) if (reach[i][j]) { seen.add(j); group.push('abc'[j]); }
    groups.push(group);
  }
  assert.deepEqual(rows[mask], {mask, groups});
}
console.log('All 512 port-graph edge subsets match independent undirected closure');
