import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {profileIdentity} from '../js/profile.mjs';
import {resolveBuild} from '../js/build.mjs';
const first=await readFile(new URL('./fixtures/profile-v1.json',import.meta.url),'utf8');
const second=first.replace('"id":"fixture-0"','"id":"fixture-1"');
const firstId=(await profileIdentity(first)).identity;
const secondId=(await profileIdentity(second)).identity;
const plan=(await readFile(new URL('./fixtures/assembly-v1.json',import.meta.url),'utf8')).replace('sha256:'+'a'.repeat(64),firstId).replace('sha256:'+'b'.repeat(64),secondId);

test('exact content resolution preserves order independence and missing profiles',async()=>{
  const result=await resolveBuild(plan,[first,second]);
  assert.equal(result.ok,true);
  assert.deepEqual(result,await resolveBuild(plan,[second,first]));
  assert.deepEqual(result.resolution.missing.toArray(),[]);
  assert.equal(result.resolution.profiles.toArray().length,2);
  const partial=await resolveBuild(plan,[first]);
  assert.deepEqual(partial.resolution.missing.toArray(),[secondId]);
  const empty=await resolveBuild(plan,[]);
  assert.deepEqual(empty.resolution.missing.toArray(),[firstId,secondId].sort());
});

test('tampered, duplicate and extra profiles cannot satisfy an unchanged pin',async()=>{
  assert.deepEqual(await resolveBuild(plan,[first,first]),{ok:false,error:'duplicate_identifier'});
  assert.deepEqual(await resolveBuild(plan,[first+' ']),{ok:false,error:'noncanonical'});
  const changed=first.replace('"max":1010','"max":1011');
  assert.deepEqual(await resolveBuild(plan,[changed,second]),{ok:false,error:'unreferenced_profile'});
  assert.deepEqual(await resolveBuild(plan,[{identity:firstId,canonical:second}]),{ok:false,error:'invalid_document'});
});

test('shared budgets refuse types, sparse arrays, count, per-document and total bytes',async()=>{
  for(const profiles of [null,{},[undefined],new Array(1)]) assert.deepEqual(await resolveBuild(plan,profiles),{ok:false,error:'invalid_document'});
  assert.deepEqual(await resolveBuild(null,[]),{ok:false,error:'invalid_document'});
  assert.deepEqual(await resolveBuild(plan,Array(65).fill('')),{ok:false,error:'invalid_count'});
  assert.deepEqual(await resolveBuild(plan,[' '.repeat(262145)]),{ok:false,error:'too_large'});
  assert.deepEqual(await resolveBuild(plan,Array(16).fill(' '.repeat(262144))),{ok:false,error:'too_large'});
  assert.deepEqual(await resolveBuild(plan,['é'.repeat(131073)]),{ok:false,error:'too_large'});
});

test('crypto loss fails closed even when no profile body was supplied',async()=>{
  const original=Object.getOwnPropertyDescriptor(globalThis,'crypto');
  try{
    Object.defineProperty(globalThis,'crypto',{value:undefined,configurable:true});
    assert.deepEqual(await resolveBuild(plan,[]),{ok:false,error:'crypto_unavailable'});
  }finally{Object.defineProperty(globalThis,'crypto',original);}
});
