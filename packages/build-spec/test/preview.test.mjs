import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {planningPreview} from '../js/preview.mjs';

const read=name=>readFile(new URL(`./fixtures/context-v1/${name}.json`,import.meta.url),'utf8');
const assembly=await read('assembly');
const profiles=await Promise.all([0,1,2,3].map(n=>read('profile-'+n)));
const mappings=await Promise.all([0,1].map(n=>read('mapping-'+n)));

test('browser preview runs every frame stage over verified exact inputs',async()=>{
  const result=await planningPreview(assembly,profiles,mappings);
  assert.equal(result.ok,true);
  assert.ok(['unknown','incompatible'].includes(result.status));
  assert.deepEqual(result.stages.map(stage=>stage.name),[
    'graph','completeness','geometry','viewing','power_interfaces',
    'power_loads','power_contracts','thermal','mounting','signals',
    'signal_routes','operation','artifacts',
  ]);
  assert.ok(result.stages.some(stage=>stage.findings.toArray().length>0));
  assert.deepEqual(result,await planningPreview(assembly,[...profiles].reverse(),[...mappings].reverse()));
});

test('browser preview refuses changed profile identity and untrusted documents',async()=>{
  const changed=profiles[0].replace('"part_revision":"R1"','"part_revision":"R2"');
  assert.deepEqual(await planningPreview(assembly,[changed,...profiles.slice(1)],mappings),{ok:false,error:'unreferenced_profile'});
  assert.deepEqual(await planningPreview(assembly,profiles,[null]),{ok:false,error:'invalid_document'});
});
