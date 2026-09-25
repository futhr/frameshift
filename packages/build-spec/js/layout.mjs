import { identity_payload } from '../build/dev/javascript/frameshift_build/frameshift_build/artifact.mjs';
import { canonicalIdentity } from './identity.mjs';

/** Identifies a logical layout. No artwork or runtime admission is implied. */
export function layoutIdentity(text) {
  return canonicalIdentity(text, identity_payload);
}
