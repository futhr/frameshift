import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const records=readFileSync(process.argv[2],'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length,256);
for(const [seed,record] of records.entries()){
  assert.equal(record.seed,seed);
  const [cw,ch]=record.canvas;
  const [w,h]=record.native;
  // Enumerate actual integer pixel addresses. The compiler uses interval edges,
  // rectangle union and integer products instead of constructing pixel sets.
  const tiles=new Map(record.tiles.map(t=>{
    const pixels=[];
    for(let y=0;y<h;y++) for(let x=0;x<w;x++){
      const [rx,ry]=t.rotation===0?[x,y]:t.rotation===90?[h-1-y,x]
        :t.rotation===180?[w-1-x,h-1-y]:[y,w-1-x];
      pixels.push([t.x+rx,t.y+ry]);
    }
    return [t.id,pixels];
  }));
  const sets=new Map([...tiles].map(([id,pixels])=>[id,new Set(pixels.map(p=>p.join(',')))]));
  const payload=[];
  let covered=true;
  for(let y=0;y<ch;y++) for(let x=0;x<cw;x++){
    payload.push(0,0,0);
    covered &&= [...sets.values()].some(s=>s.has(`${x},${y}`));
  }
  const retained=record.slots.map(n=>Array.from({length:n},()=>payload).flat().length);
  for(const finding of record.actual){
    let passes;
    let required=null;
    const [first,second]=finding.instances;
    switch(finding.code){
      case 'artifact.tile_width':
        required=[Math.max(...tiles.get(first).map(p=>p[0]))+1];
        required.push(required[0]);
        passes=tiles.get(first).every(([x])=>x<cw);
        break;
      case 'artifact.tile_height':
        required=[Math.max(...tiles.get(first).map(p=>p[1]))+1];
        required.push(required[0]);
        passes=tiles.get(first).every(([,y])=>y<ch);
        break;
      case 'artifact.coverage': passes=covered; break;
      case 'artifact.tile_separation': passes=![...sets.get(first)].some(p=>sets.get(second).has(p)); break;
      case 'artifact.payload_limit': required=[payload.length,payload.length];passes=payload.length<=1_000_000;break;
      case 'artifact.retained_payload':required=retained;passes=retained[1]<=record.budget;break;
      default:assert.fail(finding.code);
    }
    assert.deepEqual(finding.required,required,`operands ${seed} ${finding.code}`);
    assert.equal(finding.outcome,passes?'compatible':'incompatible',`outcome ${seed} ${finding.code}`);
  }
}
console.log('256 artifact layouts match independent pixel and retained-byte enumeration');
