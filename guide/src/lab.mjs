import * as kernel from './kernel/frameshift_decisions/frameshift_decisions.mjs';
import { Ok, toList } from './kernel/prelude.mjs';

export const examples = Object.freeze({
  paper: Object.freeze({
    name: 'Paper', maker: 'Waveshare E6 candidate', width: 1600, height: 1200,
    profile: 'paper-e6-panel-packed', packing: 'indexed', minimumMs: 180_000,
    suggestionMs: 21_600_000, power: 'Bistable image; refresh consumes power.',
    route: 'pull',
  }),
  photo: Object.freeze({
    name: 'Photo', maker: 'BOE QHD geometry candidate', width: 2560, height: 1440,
    profile: 'photo-srgb-rgb24', packing: 'rgb', minimumMs: 30_000,
    suggestionMs: null, power: 'Backlight stays powered while visible.',
    route: 'direct',
  }),
  pixel: Object.freeze({
    name: 'Pixel', maker: 'Six Waveshare P3 modules candidate', width: 192, height: 128,
    profile: 'pixel-srgb-rgb24', packing: 'rgb', minimumMs: 30_000,
    suggestionMs: null, power: 'LED scan power depends on brightness and content.',
    route: 'direct',
  }),
});

export function profileDecision(kind) {
  const example = examples[kind];
  if (!example) throw new RangeError('Unknown frame class');
  const candidate = new kernel.RasterCandidate(
    example.profile, example.width, example.height, example.width * example.height * 3,
    example.packing, 8, 'none', 1, 'not-applicable',
  );
  const result = kernel.select_rgb24_profile(
    toList([candidate]), example.profile, 'continuous', toList(['srgb']), 'srgb',
  );
  return result instanceof Ok ? { admitted: true, id: result[0] } :
    { admitted: false, reason: result[0].constructor.name };
}

export function dwellDecision(kind, seconds) {
  const example = examples[kind];
  if (!example) throw new RangeError('Unknown frame class');
  if (!Number.isSafeInteger(seconds) || seconds < 1 || seconds > 86_400) {
    return { admitted: false, reason: 'Choose 1 to 86,400 whole seconds.' };
  }
  const result = kernel.select_dwell(example.minimumMs, seconds * 1000);
  return result instanceof Ok ? { admitted: true, seconds: result[0] / 1000 } :
    { admitted: false, reason: result[0].constructor.name };
}

export function centerCrop(sourceWidth, sourceHeight, targetWidth, targetHeight) {
  if (![sourceWidth, sourceHeight, targetWidth, targetHeight]
    .every(value => Number.isSafeInteger(value) && value > 0)) {
    throw new RangeError('Crop dimensions must be positive whole numbers');
  }
  const sourceRatio = sourceWidth / sourceHeight;
  const targetRatio = targetWidth / targetHeight;
  if (sourceRatio > targetRatio) {
    const width = sourceHeight * targetRatio;
    return { x: (sourceWidth - width) / 2, y: 0, width, height: sourceHeight };
  }
  const height = sourceWidth / targetRatio;
  return { x: 0, y: (sourceHeight - height) / 2, width: sourceWidth, height };
}

export function newSession(kind = 'paper') {
  if (!examples[kind]) throw new RangeError('Unknown frame class');
  return {
    kind, revision: 0, current: 'Previous still', desired: null,
    status: 'Select a still and queue a simulated revision.',
  };
}

export function queue(session) {
  if (session.revision >= 9_999) {
    return { ...session, status: 'Lab revision limit reached. Reset to start again.' };
  }
  const revision = session.revision + 1;
  const desired = {
    revision, label: `Still ${revision}`, request: `request-${revision}`,
    digest: `illustrative-digest-${revision}`,
  };
  return {
    ...session, revision, desired,
    status: `Revision ${revision} is desired. The previous still remains current.`,
  };
}

export function attempt(session, event) {
  if (!session.desired) return { ...session, status: 'Queue a simulated still first.' };
  const { desired } = session;
  const example = examples[session.kind];
  const wrongRevision = event === 'version';
  const wrongDigest = event === 'digest';
  let result;
  if (example.route === 'pull') {
    const refresh = event === 'confirm' || wrongRevision || wrongDigest ?
      'displayed' : event === 'unknown' ? 'unknown' : 'not-requested';
    result = kernel.pull_confirmation(
      desired.revision, desired.digest,
      desired.revision + Number(wrongRevision),
      wrongDigest ? 'different-digest' : desired.digest,
      'verified', refresh,
    );
  } else {
    const outcome = event === 'confirm' || wrongRevision || wrongDigest ?
      'displayed' : event === 'unknown' ? 'unknown' : 'pending';
    result = kernel.direct_confirmation(
      desired.revision, desired.request, desired.digest, 'pending',
      desired.revision + Number(wrongRevision), desired.request,
      wrongDigest ? 'different-digest' : desired.digest, outcome,
    );
  }
  if (result instanceof Ok && result[0] instanceof kernel.Commit) {
    return {
      ...session, current: desired.label, desired: null,
      status: `${desired.label} is current after a matching displayed confirmation.`,
    };
  }
  const explanation = {
    loss: 'Transfer interrupted. The previous still remains current.',
    restart: 'Receiver restarted with the previous still. Desired revision is still pending.',
    version: 'Revision mismatch refused. Current remains unchanged.',
    digest: 'Digest mismatch refused. Current remains unchanged.',
    unknown: 'Display outcome unknown. Current remains unchanged until confirmation.',
  };
  if (!Object.hasOwn(explanation, event)) throw new RangeError('Unknown simulation event');
  return { ...session, status: explanation[event] };
}
