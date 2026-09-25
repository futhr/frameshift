import { identity_payload } from '../build/dev/javascript/frameshift_build/frameshift_build/mapping.mjs';
import { canonicalIdentity } from './identity.mjs';

/** Validates exact sourced bytes. Identity does not grant mapping admission. */
export function mappingIdentity(text) {
  return canonicalIdentity(text, identity_payload);
}
