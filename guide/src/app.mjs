import { attempt, centerCrop, dwellDecision, examples, newSession, profileDecision, queue } from './lab.mjs';

const byId = id => document.getElementById(id);
const choices = [...document.querySelectorAll('[data-kind]')];
const events = [...document.querySelectorAll('[data-event]')];
let session = newSession();
let image = null;
let imageSelection = 0;

function renderPreview() {
  const example = examples[session.kind];
  const canvas = byId('preview');
  byId('preview-ratio').textContent = `${example.width} × ${example.height}`;
  if (!image) {
    canvas.hidden = true;
    byId('preview-empty').hidden = false;
    return;
  }
  canvas.width = 800;
  canvas.height = Math.round(800 * example.height / example.width);
  const context = canvas.getContext('2d', { alpha: false });
  const crop = centerCrop(image.width, image.height, example.width, example.height);
  context.imageSmoothingEnabled = session.kind !== 'pixel';
  context.drawImage(image, crop.x, crop.y, crop.width, crop.height,
    0, 0, canvas.width, canvas.height);
  canvas.hidden = false;
  byId('preview-empty').hidden = true;
}

function render() {
  const example = examples[session.kind];
  for (const choice of choices) {
    choice.setAttribute('aria-pressed', String(choice.dataset.kind === session.kind));
  }
  const profile = profileDecision(session.kind);
  byId('profile-result').textContent = profile.admitted ?
    'RGB24 profile admitted in software' : 'Panel profile not yet supported';
  byId('profile-detail').textContent = profile.admitted ?
    'The shared kernel accepts this illustrative RGB24 capability. No physical controller has been qualified.' :
    'The current shared selector handles RGB24 only. This candidate needs exact panel packing and a qualified renderer.';
  byId('profile-size').textContent = `${example.width} × ${example.height}`;
  byId('profile-maker').textContent = example.maker;
  byId('handoff').href = `frameshift://setup?${new URLSearchParams({
    v: '1', class: session.kind, profile: example.profile,
  })}`;
  byId('dwell-basis').textContent = example.suggestionMs ?
    'Six hours is a provisional Paper cycling suggestion, not a measured battery optimum. Minimum: 180 seconds.' :
    `${example.power} This example uses a simulated 30-second minimum; interval is not an energy recommendation.`;
  const dwell = dwellDecision(session.kind, Number(byId('dwell').value));
  byId('dwell-result').textContent = dwell.admitted ?
    dwell.seconds === Number(byId('dwell').value) ? `${dwell.seconds}s selected` :
      `${dwell.seconds}s minimum applied` : dwell.reason;
  byId('current').textContent = session.current;
  byId('desired').textContent = session.desired ?
    `${session.desired.label} · pending` : 'None queued';
  byId('simulation-status').textContent = session.kind === 'paper' ?
    `${session.status} Paper delivery here is conceptual; its artifact profile is not admitted.` :
    session.status;
  renderPreview();
}

for (const choice of choices) {
  choice.addEventListener('click', () => {
    session = newSession(choice.dataset.kind);
    byId('dwell').value = String((examples[session.kind].suggestionMs ?? 300_000) / 1000);
    render();
  });
}

byId('dwell').addEventListener('input', render);
byId('queue').addEventListener('click', () => { session = queue(session); render(); });
byId('reset').addEventListener('click', () => {
  imageSelection += 1;
  if (image) image.close();
  image = null;
  byId('sample').value = '';
  byId('sample-detail').textContent = 'Your image stays in this browser tab.';
  session = newSession(session.kind);
  render();
});
for (const event of events) {
  event.addEventListener('click', () => {
    session = attempt(session, event.dataset.event);
    render();
  });
}

byId('sample').addEventListener('change', async event => {
  const selection = ++imageSelection;
  const file = event.target.files?.[0];
  if (!file) return;
  const detail = byId('sample-detail');
  if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type) ||
      file.size === 0 || file.size > 8 * 1024 * 1024) {
    detail.textContent = 'Choose a PNG, JPEG, or WebP image up to 8 MiB.';
    event.target.value = '';
    return;
  }
  let decoded;
  try {
    decoded = await createImageBitmap(file);
  } catch {
    if (selection !== imageSelection) return;
    detail.textContent = 'The image could not be decoded.';
    event.target.value = '';
    return;
  }
  if (selection !== imageSelection) {
    decoded.close();
    return;
  }
  if (decoded.width > 8192 || decoded.height > 8192 ||
      decoded.width * decoded.height > 16_777_216) {
    decoded.close();
    detail.textContent = 'Decoded images must fit within 8192 pixels per side and 16 million pixels total.';
    event.target.value = '';
    return;
  }
  if (image) image.close();
  image = decoded;
  detail.textContent = `${file.name} · ${image.width} × ${image.height} · local preview only`;
  renderPreview();
});

render();
