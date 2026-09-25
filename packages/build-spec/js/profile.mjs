import { identity_payload, refusal_code } from '../build/dev/javascript/frameshift_build/frameshift_build.mjs';
import { Result$isOk, Result$Ok$0, Result$Error$0 } from '../build/dev/javascript/prelude.mjs';

/** Validates the shared format before hashing. Does not grant compatibility. */
export async function profileIdentity(text) {
  if (typeof text !== 'string') return { ok: false, error: 'invalid_document' };
  const result = identity_payload(text);
  if (!Result$isOk(result)) return { ok: false, error: refusal_code(Result$Error$0(result)) };
  const payload = new TextEncoder().encode(Result$Ok$0(result));
  try {
    const digest = await globalThis.crypto.subtle.digest('SHA-256', payload);
    const hex = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
    return { ok: true, identity: `sha256:${hex}` };
  } catch {
    return { ok: false, error: 'crypto_unavailable' };
  }
}
