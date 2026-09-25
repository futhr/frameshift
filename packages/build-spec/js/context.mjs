import { canonical, identity_payload, resolve } from '../build/dev/javascript/frameshift_build/frameshift_build/context.mjs';
import { context_budget } from '../build/dev/javascript/frameshift_build/frameshift_build/resolution.mjs';
import { refusal_code } from '../build/dev/javascript/frameshift_build/frameshift_build.mjs';
import { Result$isOk, Result$Ok$0, Result$Error$0, toList } from '../build/dev/javascript/prelude.mjs';
import { canonicalIdentity } from './identity.mjs';
import { buildIdentity } from './build.mjs';
import { profileIdentity } from './profile.mjs';
import { mappingIdentity } from './mapping.mjs';

function inputTypes(documents) {
  if (!Array.isArray(documents)) return {ok:false,error:'invalid_document'};
  if (documents.length > 64) return {ok:false,error:'invalid_count'};
  const snapshot = [];
  for (const bytes of documents) {
    if (typeof bytes !== 'string') return {ok:false,error:'invalid_document'};
    snapshot.push(bytes);
  }
  return {ok:true,value:snapshot};
}

function normalize(result) {
  return Result$isOk(result) ? {ok:true,value:Result$Ok$0(result)}
    : {ok:false,error:refusal_code(Result$Error$0(result))};
}

async function hash(documents, identity) {
  const pairs = [];
  for (const bytes of documents) {
    const result = await identity(bytes);
    if (!result.ok) return result;
    pairs.push([result.identity,bytes]);
  }
  return {ok:true,value:toList(pairs)};
}

/** Verifies every document before building a context. Does not admit its evidence. */
export async function resolveContext(bytes, profiles, mappings) {
  if (typeof bytes !== 'string') return {ok:false,error:'invalid_document'};
  const profileInput = inputTypes(profiles);
  if (!profileInput.ok) return profileInput;
  const mappingInput = inputTypes(mappings);
  if (!mappingInput.ok) return mappingInput;
  const budget = normalize(context_budget(bytes,toList(profileInput.value),toList(mappingInput.value)));
  if (!budget.ok) return budget;
  const assembly = await buildIdentity(bytes);
  if (!assembly.ok) return assembly;
  const profilePairs = await hash(profileInput.value,profileIdentity);
  if (!profilePairs.ok) return profilePairs;
  const mappingPairs = await hash(mappingInput.value,mappingIdentity);
  if (!mappingPairs.ok) return mappingPairs;
  const result = normalize(resolve(bytes,profilePairs.value,mappingPairs.value));
  if (!result.ok) return result;
  const context = result.value;
  const encoded = normalize(canonical(assembly.identity,context));
  if (!encoded.ok) return encoded;
  const identified = await canonicalIdentity(assembly.identity,id => identity_payload(id,context));
  if (!identified.ok) return identified;
  return {ok:true,identity:identified.identity,assembly_identity:assembly.identity,canonical:encoded.value,context};
}
