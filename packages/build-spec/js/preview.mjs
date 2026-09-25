import { evaluate } from '../build/dev/javascript/frameshift_build/frameshift_build/compiler/preview.mjs';
import { Outcome$isIncompatible } from '../build/dev/javascript/frameshift_decisions/frameshift_physical.mjs';
import { refusal_code } from '../build/dev/javascript/frameshift_build/frameshift_build.mjs';
import { Result$isOk, Result$Ok$0, Result$Error$0 } from '../build/dev/javascript/prelude.mjs';
import { resolveContext } from './context.mjs';

/** Runs the retained frame checks over verified exact bytes; never grants admission. */
export async function planningPreview(bytes, profiles, mappings, layouts = []) {
  const resolved = await resolveContext(bytes, profiles, mappings, layouts);
  if (!resolved.ok) return resolved;
  const result = evaluate(resolved.context);
  if (!Result$isOk(result)) return {ok:false,error:refusal_code(Result$Error$0(result))};
  const preview = Result$Ok$0(result);
  return {
    ok:true,
    identity:resolved.identity,
    assembly_identity:resolved.assembly_identity,
    status:Outcome$isIncompatible(preview.status) ? 'incompatible' : 'unknown',
    stages:preview.stages.toArray(),
  };
}
