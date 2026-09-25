import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { loadCatalog, validateCatalog } from '../checks/catalog.mjs';

const catalog = await loadCatalog();
const profiles = await validateCatalog(catalog.manifest, catalog.files);
const byClass = (name) => profiles.find((profile) => profile.classes.includes(name));
const fact = (profile, key) => profile.facts.find((item) => item.key === key);

test('all three baselines retain unqualified hardware and missing assembly constraints', () => {
  assert.deepEqual(profiles.flatMap((profile) => profile.classes).sort(), ['paper', 'photo', 'pixel']);
  for (const profile of profiles) {
    assert.equal(profile.part_revision, 'unverified');
    for (const key of ['outline.depth', 'connector.clearance', 'cable.clearance', 'mount.pattern', 'assembly.thermal', 'firmware.contract', 'protocol.contract', 'artifact.contract', 'storage.capacity']) {
      assert.equal(fact(profile, key).value.state, 'missing', `${profile.id}: ${key}`);
    }
    assert.equal(fact(profile, 'refresh.energy_recommended').value.state, 'missing');
  }
});

test('Paper retains native axes, drawing tolerances, temperature conflict and separate refresh advice', () => {
  const paper = byClass('paper');
  assert.equal(fact(paper, 'raster.width').value.max, 1200);
  assert.equal(fact(paper, 'raster.height').value.max, 1600);
  assert.deepEqual(fact(paper, 'active.width').value, { max: 202900, min: 202700, state: 'known' });
  assert.equal(fact(paper, 'temperature.operating').value.state, 'conflicting');
  assert.equal(fact(paper, 'temperature.operating').sources.length, 2);
  assert.equal(fact(paper, 'layer.active_with_film.depth').value.max, 1000);
  assert.equal(fact(paper, 'refresh.recommended_minimum').value.max, 180000);
  assert.equal(fact(paper, 'refresh.recommended_maximum').value.max, 86400000);
});

test('Photo preserves mechanical scope conflict and separate conditional backlight requirements', () => {
  const photo = byClass('photo');
  assert.equal(fact(photo, 'mechanical.model_scope').value.state, 'conflicting');
  assert.equal(fact(photo, 'outline.width.nominal').value.max, 608800);
  assert.equal(fact(photo, 'outline.width').value.state, 'missing');
  assert.equal(fact(photo, 'power.maximum').value.state, 'missing');
  const backlight = photo.ports.find((port) => port.id === 'backlight');
  assert.equal(backlight.required, true);
  assert.equal(backlight.facts.find((item) => item.key === 'driver.contract').value.state, 'missing');
  assert.equal(backlight.facts.find((item) => item.key === 'channels').value.max, 4);
});

test('Pixel nominal nameplate data cannot imply an admitted pinout or tolerance', () => {
  const pixel = byClass('pixel');
  assert.equal(fact(pixel, 'outline.width.nominal').value.max, 192000);
  assert.equal(fact(pixel, 'outline.width').value.state, 'missing');
  assert.equal(fact(pixel, 'power.nameplate').value.max, 20000);
  const signal = pixel.ports.find((port) => port.id === 'hub75-in');
  assert.deepEqual(signal.facts.find((item) => item.key === 'connector.label.legacy').value.terms, ['HUB75E']);
  assert.deepEqual(signal.facts.find((item) => item.key === 'connector.label.current').value.terms, ['HUB75']);
  assert.equal(signal.facts.find((item) => item.key === 'pinout.contract').value.state, 'missing');
});

test('tampering, unresolved references, duplicate revisions and orphan files fail admission', async () => {
  const fresh = () => structuredClone(catalog.manifest);
  const badHash = fresh(); badHash.profiles[0].identity = `sha256:${'0'.repeat(64)}`;
  await assert.rejects(validateCatalog(badHash, catalog.files), /profile_identity_mismatch/);
  const badSource = fresh(); badSource.sources[0].revision = 'wrong';
  await assert.rejects(validateCatalog(badSource, catalog.files), /unresolved_source_revision/);
  const missingSource = fresh(); missingSource.sources.pop();
  await assert.rejects(validateCatalog(missingSource, catalog.files), /unresolved_source_revision/);
  const duplicateSource = fresh(); duplicateSource.sources.push(duplicateSource.sources[0]);
  await assert.rejects(validateCatalog(duplicateSource, catalog.files), /duplicate_source/);
  const duplicateProfile = fresh(); duplicateProfile.profiles.push(duplicateProfile.profiles[0]);
  await assert.rejects(validateCatalog(duplicateProfile, catalog.files), /duplicate_profile_revision/);
  const unsafePath = fresh(); unsafePath.profiles[0].file = '../secret.json';
  await assert.rejects(validateCatalog(unsafePath, catalog.files), /invalid_profile_file/);
  const elevated = fresh(); elevated.profiles[0].evidence_state = 'validated';
  await assert.rejects(validateCatalog(elevated, catalog.files), /unqualified_evidence_state/);
  const files = new Map(catalog.files); files.set('profiles/orphan.json', '{}\n');
  await assert.rejects(validateCatalog(catalog.manifest, files), /orphan_profile_file/);
  files.delete('profiles/orphan.json'); files.delete(catalog.manifest.profiles[0].file);
  await assert.rejects(validateCatalog(catalog.manifest, files), /missing_profile_file/);
});
