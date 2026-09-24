import { createHash, createPublicKey, verify } from 'node:crypto';
import { constants } from 'node:fs';
import { open, readFile } from 'node:fs/promises';
import { join } from 'node:path';

const manifestKeys = ['schemaVersion', 'product', 'version', 'artifacts'];
const artifactKeys = ['platform', 'architecture', 'format', 'file', 'url', 'bytes', 'sha256'];
const tuples = new Set([
  'macos/universal/dmg',
  'ubuntu/amd64/deb',
  'ubuntu/arm64/deb',
  'nerves-rpi5/arm64/fw',
]);
const decoder = new TextDecoder('utf-8', { fatal: true });

function requireKeys(value, keys) {
  if (value === null || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).length !== keys.length ||
      !keys.every((key) => Object.hasOwn(value, key))) {
    throw new Error('invalid release manifest fields');
  }
}

function validArtifact(artifact, version) {
  requireKeys(artifact, artifactKeys);
  const tuple = `${artifact.platform}/${artifact.architecture}/${artifact.format}`;
  if (!tuples.has(tuple)) throw new Error('unsupported release target');
  if (typeof artifact.file !== 'string' ||
      !/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(artifact.file) ||
      artifact.file.includes('..') || !artifact.file.includes(version) ||
      !artifact.file.endsWith(`.${artifact.format}`)) {
    throw new Error('invalid release filename');
  }
  if (!Number.isSafeInteger(artifact.bytes) || artifact.bytes < 1 ||
      artifact.bytes > 8 * 1024 * 1024 * 1024) {
    throw new Error('invalid release byte count');
  }
  if (typeof artifact.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(artifact.sha256)) {
    throw new Error('invalid release digest');
  }
  if (typeof artifact.url !== 'string') throw new Error('invalid release URL');
  let url;
  try { url = new URL(artifact.url); } catch { throw new Error('invalid release URL'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash ||
      url.port || url.pathname.includes('%') ||
      /(^|\/)latest(\/|$)/i.test(url.pathname) ||
      !url.pathname.endsWith(`/v${version}/${artifact.file}`) ||
      artifact.url !== url.href) {
    throw new Error('invalid release URL');
  }
  return tuple;
}

export function parseManifest(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 2 || bytes.length > 64 * 1024) {
    throw new Error('invalid release manifest size');
  }
  let text;
  let manifest;
  try {
    text = decoder.decode(bytes);
    manifest = JSON.parse(text);
  } catch {
    throw new Error('invalid release manifest JSON');
  }
  if (JSON.stringify(manifest) + '\n' !== text) {
    throw new Error('release manifest must use exact compact JSON encoding');
  }
  requireKeys(manifest, manifestKeys);
  if (manifest.schemaVersion !== 1 || manifest.product !== 'io.frameshift.app' ||
      typeof manifest.version !== 'string' ||
      manifest.version.length > 32 ||
      !/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/.test(manifest.version) ||
      !Array.isArray(manifest.artifacts) || manifest.artifacts.length < 1 ||
      manifest.artifacts.length > 16) {
    throw new Error('invalid release manifest identity');
  }
  const names = new Set();
  const targets = new Set();
  for (const artifact of manifest.artifacts) {
    const target = validArtifact(artifact, manifest.version);
    if (names.has(artifact.file) || targets.has(target)) {
      throw new Error('duplicate release artifact');
    }
    names.add(artifact.file);
    targets.add(target);
  }
  return manifest;
}

async function verifyArtifact(directory, artifact) {
  const handle = await open(join(directory, artifact.file), constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size !== artifact.bytes) {
      throw new Error(`release artifact size mismatch: ${artifact.file}`);
    }
    const hash = createHash('sha256');
    for await (const chunk of handle.createReadStream({ autoClose: false })) hash.update(chunk);
    if (hash.digest('hex') !== artifact.sha256) {
      throw new Error(`release artifact digest mismatch: ${artifact.file}`);
    }
  } finally {
    await handle.close();
  }
}

export async function verifyRelease({ manifestPath, signaturePath, publicKeyPath,
                                      trustedKeyDigest, artifactDirectory }) {
  if (typeof trustedKeyDigest !== 'string' || !/^[0-9a-f]{64}$/.test(trustedKeyDigest)) {
    throw new Error('missing pinned release key fingerprint');
  }
  const [bytes, signature, pem] = await Promise.all([
    readFile(manifestPath), readFile(signaturePath), readFile(publicKeyPath),
  ]);
  const manifest = parseManifest(bytes);
  const key = createPublicKey(pem);
  const keyDigest = createHash('sha256').update(key.export({ type: 'spki', format: 'der' })).digest('hex');
  if (key.asymmetricKeyType !== 'ed25519' || keyDigest !== trustedKeyDigest ||
      signature.length !== 64 || !verify(null, bytes, key, signature)) {
    throw new Error('release signature or trusted key mismatch');
  }
  for (const artifact of manifest.artifacts) await verifyArtifact(artifactDirectory, artifact);
  return manifest;
}
