// Independent finite-cell coverage, not the production edge/interval sweep.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const candidates = [[0,0,1,1],[0,0,1,2],[0,0,2,1],[0,0,2,2],[0,1,1,2],[0,1,2,2],[1,0,2,1],[1,0,2,2],[1,1,2,2]];
const lines = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(lines.length, 512);
for (let mask = 0; mask < 512; mask++) {
  const selected = candidates.filter((_, bit) => mask & (1 << bit));
  const cells = [[0,0],[0,1],[1,0],[1,1]];
  const covered = cells.every(([x,y]) => selected.some(([l,t,r,b]) => l <= x && t <= y && r >= x + 1 && b >= y + 1));
  assert.deepEqual(lines[mask], {mask, covered});
}
console.log('All 512 rectangle subsets match the independent cell coverage oracle');
