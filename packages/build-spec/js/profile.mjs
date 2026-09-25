import { identity_payload } from '../build/dev/javascript/frameshift_build/frameshift_build.mjs';
import { canonicalIdentity } from './identity.mjs';

/** Validates the shared format before hashing. Does not grant compatibility. */
export function profileIdentity(text) {
  return canonicalIdentity(text, identity_payload);
}
