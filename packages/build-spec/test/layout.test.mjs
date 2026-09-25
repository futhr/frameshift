import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {layoutIdentity} from '../js/layout.mjs';
import {resolveContext} from '../js/context.mjs';

const read=name=>readFile(new URL('./fixtures/'+name+'.json',import.meta.url),'utf8');
const layout=await read('layout-v1');
const assembly=await read('context-v1/assembly');
const profiles=await Promise.all([0,1,2,3].map(n=>read('context-v1/profile-'+n)));
const mappings=await Promise.all([0,1].map(n=>read('context-v1/mapping-'+n)));
const canonical=await read('context-v1/context-layout');
const layoutId='sha256:9acb1b67fb0039448fb57f65f344be4ac0f33ca4f7ca49eaeed14db87e5bde01';
const contextId='sha256:69c6b95344c12fc9690e3a0d22ebf485c9931aa6d2c1f8923faa3b8d53e5ea3d';

test('layout and mixed-binding context match both golden identities',async()=>{
  assert.deepEqual(await layoutIdentity(layout),{ok:true,identity:layoutId});
  const result=await resolveContext(assembly,profiles,mappings,[layout]);
  assert.equal(result.ok,true);
  assert.equal(result.identity,contextId);
  assert.equal(result.canonical,canonical);
  assert.equal(result.context.layouts.toArray()[0].identity,layoutId);
  assert.deepEqual(result,await resolveContext(assembly,[...profiles].reverse(),[...mappings].reverse(),[layout]));
  const changed=await resolveContext(assembly,profiles,mappings,[layout.replace('"x":0','"x":1')]);
  assert.equal(changed.ok,true);
  assert.notEqual(changed.identity,contextId);
  assert.equal(changed.assembly_identity,result.assembly_identity);
  const future=await resolveContext(assembly,profiles,mappings,[layout.replace('rgb24-srgb-v1','future-encoder')]);
  assert.equal(future.ok,true);
});

test('stale and duplicate layout assignments refuse without erasing unresolved planning',async()=>{
  for(const changed of [layout.replace('"controller":"controller"','"controller":"absent"'),
    layout.replace('"display":"panel"','"display":"absent"'),layout.replace('fixture-v1','other-runtime')]) {
    assert.deepEqual(await resolveContext(assembly,profiles,mappings,[changed]),{ok:false,error:'invalid_reference'});
  }
  assert.deepEqual(await resolveContext(assembly,profiles,mappings,[layout,layout]),{ok:false,error:'duplicate_identifier'});
  assert.deepEqual(await resolveContext(assembly,profiles,mappings,[layout,layout.replace('"x":0','"x":1')]),{ok:false,error:'duplicate_identifier'});
  const incomplete=await resolveContext(assembly,[],[],[layout]);
  assert.equal(incomplete.ok,true);
  assert.equal(incomplete.context.resolution.missing.toArray().length,4);
});

test('layout types and combined budgets fail before cryptography',async context=>{
  let hashes=0;
  context.mock.method(globalThis.crypto.subtle,'digest',async()=>{hashes++;throw new Error('unexpected');});
  for(const bad of [null,{},[undefined],new Array(1),[{identity:layoutId,bytes:layout}]]) {
    assert.deepEqual(await resolveContext(assembly,profiles,mappings,bad),{ok:false,error:'invalid_document'});
  }
  for(const bad of [null,undefined,1,{},'{}','"\\uD800"']) assert.deepEqual(await layoutIdentity(bad),{ok:false,error:'invalid_document'});
  assert.deepEqual(await resolveContext(assembly,[],[],Array(65).fill('')),{ok:false,error:'invalid_count'});
  assert.deepEqual(await resolveContext(assembly,[],[],['x'.repeat(262145)]),{ok:false,error:'too_large'});
  assert.deepEqual(await resolveContext(assembly,Array(6).fill('x'.repeat(262144)),Array(5).fill('x'.repeat(262144)),Array(5).fill('x'.repeat(262144))),{ok:false,error:'too_large'});
  assert.equal(hashes,0);
});

test('layout collection is snapshotted before async hashing',async context=>{
  const layouts=[layout];
  const digest=globalThis.crypto.subtle.digest.bind(globalThis.crypto.subtle);
  context.mock.method(globalThis.crypto.subtle,'digest',async(...args)=>{
    layouts.splice(0,layouts.length,'{}');
    return digest(...args);
  });
  const result=await resolveContext(assembly,profiles,mappings,layouts);
  assert.equal(result.ok,true);
  assert.equal(result.identity,contextId);
});

test('noncanonical layouts and cryptography loss never produce substitute identities',async context=>{
  assert.deepEqual(await layoutIdentity(' '+layout),{ok:false,error:'noncanonical'});
  assert.deepEqual(await layoutIdentity(layout.replace('"schema":1','"schema":1,"approved":true')),{ok:false,error:'noncanonical'});
  context.mock.method(globalThis.crypto.subtle,'digest',async()=>{throw new Error('offline');});
  assert.deepEqual(await layoutIdentity(layout),{ok:false,error:'crypto_unavailable'});
  assert.deepEqual(await resolveContext(assembly,profiles,mappings,[layout]),{ok:false,error:'crypto_unavailable'});
});
