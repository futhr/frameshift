import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import { mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { parseManifest, verifyRelease } from './manifest.mjs';

const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

function manifestFor(bytes) {
  return {
    schemaVersion: 1,
    product: 'io.frameshift.app',
    version: '1.2.3',
    artifacts: [{
      platform: 'macos',
      architecture: 'universal',
      format: 'dmg',
      file: 'Frameshift-1.2.3.dmg',
      url: 'https://example.com/releases/v1.2.3/Frameshift-1.2.3.dmg',
      bytes: bytes.length,
      sha256: digest(bytes),
    }],
  };
}

test('signature, pinned key, and exact artifact bytes are all required', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'frameshift-release-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const artifactBytes = Buffer.from('fixture DMG bytes');
  const manifest = manifestFor(artifactBytes);
  const manifestBytes = Buffer.from(JSON.stringify(manifest) + '\n');
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const trustedKeyDigest = digest(publicKey.export({ type: 'spki', format: 'der' }));
  const manifestPath = join(directory, 'manifest.json');
  const signaturePath = join(directory, 'manifest.sig');
  const publicKeyPath = join(directory, 'release.pub.pem');
  const artifactPath = join(directory, manifest.artifacts[0].file);
  await Promise.all([
    writeFile(manifestPath, manifestBytes),
    writeFile(signaturePath, sign(null, manifestBytes, privateKey)),
    writeFile(publicKeyPath, publicKey.export({ type: 'spki', format: 'pem' })),
    writeFile(artifactPath, artifactBytes),
  ]);
  const options = { manifestPath, signaturePath, publicKeyPath, trustedKeyDigest,
    artifactDirectory: directory };
  assert.deepEqual(await verifyRelease(options), manifest);
  await assert.rejects(verifyRelease({ ...options, trustedKeyDigest: digest('wrong key') }),
    /trusted key mismatch/);

  await writeFile(artifactPath, Buffer.from('fixture DMG byte!'));
  await assert.rejects(verifyRelease(options), /digest mismatch/);
  await writeFile(artifactPath, artifactBytes);

  await writeFile(manifestPath, Buffer.from(JSON.stringify({ ...manifest, artifacts: [{
    ...manifest.artifacts[0], sha256: digest('forged artifact'),
  }] }) + '\n'));
  await assert.rejects(verifyRelease(options), /signature or trusted key mismatch/);
  await writeFile(manifestPath, manifestBytes);

  await rm(artifactPath);
  await symlink(manifestPath, artifactPath);
  await assert.rejects(verifyRelease(options));
});

test('schema rejects duplicate JSON, mutable URLs, duplicate targets, and traversal', () => {
  const manifest = manifestFor(Buffer.from('fixture'));
  const encoded = (value) => Buffer.from(JSON.stringify(value) + '\n');
  assert.deepEqual(parseManifest(encoded(manifest)), manifest);
  const duplicate = JSON.stringify(manifest).replace('"version":"1.2.3",',
    '"version":"1.2.3","version":"1.2.3",') + '\n';
  assert.throws(() => parseManifest(Buffer.from(duplicate)), /compact JSON/);
  assert.throws(() => parseManifest(encoded({ ...manifest, artifacts: [
    manifest.artifacts[0], manifest.artifacts[0],
  ] })), /duplicate release artifact/);
  assert.throws(() => parseManifest(encoded({ ...manifest, artifacts: [{
    ...manifest.artifacts[0], file: '../Frameshift-1.2.3.dmg',
  }] })), /invalid release filename/);
  assert.throws(() => parseManifest(encoded({ ...manifest, artifacts: [{
    ...manifest.artifacts[0], url: 'http://example.com/latest/Frameshift-1.2.3.dmg',
  }] })), /invalid release URL/);
  assert.throws(() => parseManifest(encoded({ ...manifest, artifacts: [{
    ...manifest.artifacts[0], url: 'https://example.com/latest/v1.2.3/Frameshift-1.2.3.dmg',
  }] })), /invalid release URL/);
  assert.throws(() => parseManifest(encoded({ ...manifest, artifacts: [{
    ...manifest.artifacts[0], platform: 'windows',
  }] })), /unsupported release target/);
});
