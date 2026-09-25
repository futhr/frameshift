// Independent rotated-corner construction: no compiler face-mapping table.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

function rotate(point, turns) {
  let [x, y] = point;
  for (let i = 0; i < turns; i++) [x, y] = [-y, x];
  return [x, y];
}
function bounds(rect, turns) {
  const points = [];
  for (const x of [rect[0], rect[2]]) {
    for (const y of [rect[1], rect[3]]) points.push(rotate([x, y], turns));
  }
  return [Math.min(...points.map(p => p[0])), Math.min(...points.map(p => p[1])),
    Math.max(...points.map(p => p[0])), Math.max(...points.map(p => p[1]))];
}
function shape(turns, worst) {
  const [width, height, left, right, top, bottom] = worst ? [22, 14, 2, 3, 4, 5] : [20, 12, 1, 2, 3, 4];
  const bare = bounds([0, 0, width, height], turns);
  const service = bounds([-left, -top, width + right, height + bottom], turns);
  return [service[0] - bare[0], service[1] - bare[1], service[2] - bare[0], service[3] - bare[1]];
}
function part(turns, position, id) {
  const best = shape(turns, false), worst = shape(turns, true);
  const negative = [[-best[0], -worst[0]], [-best[1], -worst[1]], [1, 1]];
  const positive = [[best[2], worst[2]], [best[3], worst[3]], [7, 8]];
  const checks = [];
  const extents = [];
  for (let axis = 0; axis < 3; axis++) {
    const p = position[axis];
    extents.push([p - negative[axis][1], p + positive[axis][1]]);
    for (const face of ['negative', 'positive']) {
      const required = face === 'negative' ? negative[axis] : positive[axis].map(n => n + p);
      const available = face === 'negative' ? [p, p] : axis === 2 ? [20, 22] : [40, 42];
      const pass = required[1] <= available[0];
      checks.push({code: `geometry.fit.${'xyz'[axis]}.${face}`, outcome: pass ? 'compatible' : 'incompatible',
        reason: pass ? 'within_bounds' : 'exceeds_capacity', instances: [id], required, available});
    }
  }
  return {checks, extents};
}
const lines = readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.equal(lines.length, 2048);
for (let seed = 0; seed < lines.length; seed++) {
  assert.equal(lines[seed].seed, seed);
  const a = part(Math.floor(seed / 512), [seed % 32, Math.floor(seed / 32) % 16, seed % 13], 'part-a');
  const b = part(0, [25, 10, 0], 'part-b');
  const separate = a.extents.some(([low, high], i) => high <= b.extents[i][0] || b.extents[i][1] <= low);
  const expected = [
    {code: 'geometry.enclosure', outcome: 'compatible', reason: 'single_enclosure', instances: ['frame'], required: null, available: null},
    ...a.checks, ...b.checks,
    {code: 'geometry.separation', outcome: separate ? 'compatible' : 'unknown',
      reason: separate ? 'separated_service_envelopes' : 'overlapping_service_envelopes',
      instances: ['part-a', 'part-b'], required: null, available: null}
  ];
  assert.deepEqual(lines[seed].findings, expected, `geometry mismatch for seed ${seed}`);
}
console.log('2,048 placements and all four rotations match the independent corner oracle');
