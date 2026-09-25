import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {test} from 'node:test';
import {buildIdentity,profilePins} from '../js/build.mjs';
const bytes=await readFile(new URL('./fixtures/assembly-v1.json', import.meta.url),'utf8');
const identity='sha256:9be6b6faa2c8f8bc87f1bde825e257a51728710dd424d0f71f0275be9e3b3a20';
const encode=(value)=>JSON.stringify(value)+'\n';

test('standard Web Crypto matches the assembly golden fixture and exact pins',async()=>{
  assert.deepEqual(await buildIdentity(bytes),{ok:true,identity});
  assert.deepEqual(profilePins(bytes),{ok:true,pins:['sha256:'+'a'.repeat(64),'sha256:'+'b'.repeat(64)]});
  const value=JSON.parse(bytes);
  assert.deepEqual(Object.keys(value),['class','connections','dependencies','instances','intent','schema','semantics']);
  assert.equal(value.instances[0].id,'controller');
  assert.equal(value.intent.ambient_mc.min,-1000);
  assert.equal(value.intent.storage_bytes,1000000);
});

test('quantities, placements, intent and exact profile pins affect identity',async()=>{
  for(const change of [
    v=>v.instances.push({...v.instances[1],id:'panel2'}),
    v=>v.instances[1].placement.rotation=90,
    v=>v.intent.storage_bytes++,
    v=>v.instances[1].profile='sha256:'+'c'.repeat(64),
    v=>v.connections=[],
    v=>v.dependencies=[],
  ]){
    const value=JSON.parse(bytes); change(value);
    const result=await buildIdentity(encode(value));
    assert.equal(result.ok,true);
    assert.notEqual(result.identity,identity);
  }
});

test('untrusted structure never turns into authority or a silent default',async()=>{
  for(const value of [null,{},42,undefined])assert.deepEqual(await buildIdentity(value),{ok:false,error:'invalid_document'});
  for(const change of [
    v=>v.price=0,
    v=>v.accepted=true,
    v=>v.intent.artwork='private',
    v=>delete v.intent.firmware,
    v=>v.instances[0].profile='latest',
    v=>v.connections[0].to.instance='missing',
    v=>v.intent.storage_bytes=9007199254740992,
  ]){
    const value=JSON.parse(bytes);change(value);
    assert.equal((await buildIdentity(encode(value))).ok,false);
  }
  assert.deepEqual(profilePins(' ' + bytes),{ok:false,error:'noncanonical'});
});

test('unavailable digest capability cannot supply a substitute identity',async()=>{
  const original=Object.getOwnPropertyDescriptor(globalThis,'crypto');
  try{
    Object.defineProperty(globalThis,'crypto',{value:undefined,configurable:true});
    assert.deepEqual(await buildIdentity(bytes),{ok:false,error:'crypto_unavailable'});
  }finally{Object.defineProperty(globalThis,'crypto',original);}
});
