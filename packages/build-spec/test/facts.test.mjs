import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolveBuild} from '../js/build.mjs';
import {component, port, status_code} from '../build/dev/javascript/frameshift_build/frameshift_build/compiler/facts.mjs';
const base=new URL('../../../data/physical/',import.meta.url);
const manifest=JSON.parse(await readFile(new URL('manifest.json',base),'utf8'));
const template=JSON.parse(await readFile(new URL('./fixtures/assembly-v1.json',import.meta.url),'utf8'));

async function candidate(id){
  const entry=manifest.profiles.find(v=>v.id===id);
  const bytes=await readFile(new URL(entry.file,base),'utf8');
  const profile=JSON.parse(bytes);
  const plan=structuredClone(template);
  plan.class=profile.classes[0];
  for(const instance of plan.instances)instance.profile=entry.identity;
  const result=await resolveBuild(JSON.stringify(plan)+'\n',[bytes]);
  assert.equal(result.ok,true);
  const instance=result.resolution.assembly.instances.toArray()[0];
  return {read:key=>component(instance,key,result.resolution),port:(id,key)=>port(instance,id,key,result.resolution)};
}

test('Paper keeps full-depth absence and both thermal conflict citations',async()=>{
  const p=await candidate('waveshare-13.3-e6-panel');
  assert.equal(status_code(p.read('active.width').status),'usable');
  assert.equal(status_code(p.read('outline.depth').status),'missing_fact');
  const thermal=p.read('temperature.operating');
  assert.equal(status_code(thermal.status),'conflicting_fact');
  assert.equal(thermal.sources.toArray().length,2);
  assert.equal(status_code(p.read('refresh.energy_recommended').status),'missing_fact');
});

test('Photo nominal geometry and conditional electrical ratings remain insufficient',async()=>{
  const p=await candidate('boe-mv270qhm-n40-p1');
  assert.equal(status_code(p.read('outline.width').status),'missing_fact');
  assert.equal(status_code(p.read('power.maximum').status),'missing_fact');
  assert.equal(status_code(p.port('logic','input.voltage').status),'missing_fact');
  assert.equal(status_code(p.port('backlight','current.maximum').status),'missing_fact');
  assert.equal(status_code(p.read('temperature.operating').status),'missing_fact');
});

test('Pixel nameplate values and HUB75 labels cannot supply admitted bounds or pinout',async()=>{
  const p=await candidate('waveshare-p3-64x64-22100');
  assert.equal(status_code(p.read('outline.width').status),'missing_fact');
  assert.equal(status_code(p.read('power.maximum').status),'missing_fact');
  assert.equal(status_code(p.port('dc','current.maximum').status),'missing_fact');
  assert.equal(status_code(p.port('hub75-in','pinout.contract').status),'missing_fact');
});
