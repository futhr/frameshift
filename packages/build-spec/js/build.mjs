import { identity_payload, profile_pins } from '../build/dev/javascript/frameshift_build/frameshift_build/assembly.mjs';
import { refusal_code } from '../build/dev/javascript/frameshift_build/frameshift_build.mjs';
import { Result$isOk, Result$Ok$0, Result$Error$0, toList } from '../build/dev/javascript/prelude.mjs';
import { budget, resolve } from '../build/dev/javascript/frameshift_build/frameshift_build/resolution.mjs';
import { canonicalIdentity } from './identity.mjs';
import { profileIdentity } from './profile.mjs';

/** Structural identity only; profile resolution and compatibility are separate. */
export function buildIdentity(text) {
  return canonicalIdentity(text, identity_payload);
}

export function profilePins(text) {
  if (typeof text !== 'string') return { ok: false, error: 'invalid_document' };
  const result = profile_pins(text);
  return Result$isOk(result)
    ? { ok: true, pins: Result$Ok$0(result).toArray() }
    : { ok: false, error: refusal_code(Result$Error$0(result)) };
}

/** Recomputes every pin; no caller-supplied digest or latest-revision lookup. */
export async function resolveBuild(text, profiles) {
  if (typeof text !== 'string' || !Array.isArray(profiles)) return {ok:false,error:'invalid_document'};
  if (profiles.length > 64) return {ok:false,error:'invalid_count'};
  // Iteration also exposes sparse array entries instead of silently skipping them.
  const snapshot = [];
  for (const bytes of profiles) {
    if (typeof bytes !== 'string') return {ok:false,error:'invalid_document'};
    snapshot.push(bytes);
  }
  profiles = snapshot;
  const admission = budget(text, toList(profiles));
  if (!Result$isOk(admission)) return {ok:false,error:refusal_code(Result$Error$0(admission))};
  const build = await buildIdentity(text);
  if (!build.ok) return build;
  const pairs = [];
  for (const bytes of profiles) {
    const profile = await profileIdentity(bytes);
    if (!profile.ok) return profile;
    pairs.push([profile.identity, bytes]);
  }
  const result = resolve(text, toList(pairs));
  return Result$isOk(result)
    ? {ok:true,identity:build.identity,resolution:Result$Ok$0(result)}
    : {ok:false,error:refusal_code(Result$Error$0(result))};
}
