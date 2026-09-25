// Enumerate physical corner positions over every endpoint combination of all
// six independent intervals. Production code instead propagates edge intervals.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
function rotate(x, y, turns) {
  for (let i = 0; i < turns; i++) [x, y] = [-y, x];
  return [x, y];
}
function corners(l, t, r, b, turns) {
  const points = [];
  for (const x of [l, r]) for (const y of [t, b]) points.push(rotate(x, y, turns));
  return [Math.min(...points.map(p => p[0])), Math.min(...points.map(p => p[1])),
    Math.max(...points.map(p => p[0])), Math.max(...points.map(p => p[1]))];
}
const lines = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(lines.length, 256);
for (let seed = 0; seed < lines.length; seed++) {
  const row = lines[seed];
  assert.equal(row.seed, seed);
  const keys = ['outline.width', 'outline.height', 'active.width', 'active.height', 'active.offset.x', 'active.offset.y'];
  const extents = [];
  for (let mask = 0; mask < 64; mask++) {
    const [w,h,aw,ah,x,y] = keys.map((key, i) => row.facts[key][(mask >> i) & 1]);
    const outer = corners(0, 0, w, h, seed % 4);
    const inner = corners(x, y, x + aw, y + ah, seed % 4);
    extents.push(inner.map((v, i) => v - outer[i % 2] + (i % 2 === 0 ? seed % 11 : seed % 7)));
  }
  const low = i => Math.min(...extents.map(r => r[i]));
  const high = i => Math.max(...extents.map(r => r[i]));
  assert.deepEqual(row.possible, [low(0), low(1), high(2), high(3)]);
  assert.deepEqual(row.guaranteed, [high(0), high(1), low(2), low(3)]);
}
console.log('256 interval projections match independent corner enumeration over 64 bound combinations each');
