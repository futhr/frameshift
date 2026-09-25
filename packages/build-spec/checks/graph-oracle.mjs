import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const rows=(await readFile(process.argv[2],'utf8')).trim().split('\n').map(JSON.parse);
assert.equal(rows.length,512);
const names=['a','b','c'];
for(let mask=0;mask<512;mask++){
  // Independent transitive closure, rather than the production reachability walk.
  const reach=names.map((_,i)=>names.map((_,j)=>Boolean(mask & (1 << (3*i+j)))));
  for(let k=0;k<3;k++) for(let i=0;i<3;i++) for(let j=0;j<3;j++) reach[i][j] ||= reach[i][k] && reach[k][j];
  assert.equal(rows[mask].mask,mask);
  assert.deepEqual(rows[mask].cycles,names.filter((_,i)=>reach[i][i]),`cycle members for graph ${mask}`);
}
console.log('All 512 three-vertex directed graphs match the independent closure oracle');
