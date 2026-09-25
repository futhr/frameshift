import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';

const records=readFileSync(process.argv[2],'utf8').trim().split('\n').map(JSON.parse);
assert.equal(records.length,7);
const root=new URL('../test/fixtures/context-v1/',import.meta.url);
const write=process.argv[3]==='--write';
if(write) mkdirSync(root,{recursive:true});
const digest=(domain,bytes)=>'sha256:'+createHash('sha256').update(domain+'\n'+bytes).digest('hex');
const json=value=>JSON.stringify(value)+'\n';
function fixture(name,bytes){
  const path=new URL(name+'.json',root);
  if(write) writeFileSync(path,bytes);
  else assert.equal(readFileSync(path,'utf8'),bytes,name);
}
const pins=new Map();
for(const [index,p] of records.filter(r=>r.kind==='profile').entries()){
  pins.set(p.pin,digest('frameshift.profile.v1',p.bytes));
  fixture('profile-'+index,p.bytes);
}
const assembly=JSON.parse(records.find(r=>r.kind==='assembly').bytes);
for(const i of assembly.instances){assert.ok(pins.has(i.profile));i.profile=pins.get(i.profile);}
const assemblyBytes=json(assembly);
fixture('assembly',assemblyBytes);
const mappings=[];
for(const [index,m] of records.filter(r=>r.kind==='mapping').entries()){
  const doc=JSON.parse(m.bytes);
  assert.ok(pins.has(doc.profile));
  doc.profile=pins.get(doc.profile);
  const bytes=json(doc);
  mappings.push(digest('frameshift.signal-mapping.v1',bytes));
  fixture('mapping-'+index,bytes);
}
const canonical=json({
  assembly:digest('frameshift.build.v1',assemblyBytes),
  bindings:mappings.sort().map(identity=>({identity,kind:'signal-mapping'})),
  compiler:assembly.semantics,
  schema:1,
});
fixture('context',canonical);
console.log(digest('frameshift.compilation.v1',canonical));
