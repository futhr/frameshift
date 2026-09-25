import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { profileIdentity } from '../js/profile.mjs';

const token = /^[A-Za-z0-9][A-Za-z0-9._+-]{0,95}$/;
const digest = /^[0-9a-f]{64}$/;
const require = (condition, code) => { if (!condition) throw new Error(code); };
const fields = (value, keys, code) => {
  require(value !== null && typeof value === 'object' && !Array.isArray(value), code);
  require(Object.keys(value).sort().join('|') === [...keys].sort().join('|'), code);
};
const text = (value, limit) => typeof value === 'string' && value.length > 0 && value.length <= limit;
const unique = (values, code) => require(new Set(values).size === values.length, code);

/** Offline integrity check for reviewed repository data, not source authentication. */
export async function validateCatalog(manifest, files) {
  fields(manifest, ['schema', 'sources', 'profiles'], 'invalid_manifest');
  require(manifest.schema === 1, 'unsupported_manifest');
  require(Array.isArray(manifest.sources) && manifest.sources.length > 0 && manifest.sources.length <= 1024, 'invalid_sources');
  require(Array.isArray(manifest.profiles) && manifest.profiles.length > 0 && manifest.profiles.length <= 256, 'invalid_profiles');
  for (const source of manifest.sources) validateSource(source);
  unique(manifest.sources.map((source) => source.digest), 'duplicate_source');
  const sources = new Map(manifest.sources.map((source) => [source.digest, source]));
  const referenced = new Set();
  const profiles = [];
  for (const entry of manifest.profiles) {
    validateEntry(entry);
    const bytes = files.get(entry.file);
    require(typeof bytes === 'string', 'missing_profile_file');
    const result = await profileIdentity(bytes);
    require(result.ok && result.identity === entry.identity, 'profile_identity_mismatch');
    const profile = JSON.parse(bytes);
    require(profile.id === entry.id && profile.revision === entry.revision, 'profile_revision_mismatch');
    const facts = [...profile.facts, ...profile.ports.flatMap((port) => port.facts)];
    for (const fact of facts) {
      for (const ref of fact.sources) {
        require(sources.get(ref.digest)?.revision === ref.revision, 'unresolved_source_revision');
        referenced.add(ref.digest);
      }
    }
    profiles.push(profile);
  }
  unique(manifest.profiles.map((entry) => `${entry.id}@${entry.revision}`), 'duplicate_profile_revision');
  unique(manifest.profiles.map((entry) => entry.file), 'duplicate_profile_file');
  require(files.size === manifest.profiles.length, 'orphan_profile_file');
  require(referenced.size === sources.size, 'orphan_source');
  return profiles;
}

function validateSource(source) {
  fields(source, ['digest', 'revision', 'url', 'title', 'media_type', 'byte_size', 'retrieved_on', 'retrieved_at'], 'invalid_source');
  require(typeof source.digest === 'string' && digest.test(source.digest), 'invalid_source_digest');
  require(typeof source.revision === 'string' && token.test(source.revision), 'invalid_source_revision');
  require(text(source.title, 200) && text(source.url, 2048), 'invalid_source_metadata');
  const url = new URL(source.url);
  require(url.protocol === 'https:' && !url.username && !url.password && !url.hash, 'invalid_source_url');
  require(['application/pdf', 'text/html'].includes(source.media_type), 'invalid_source_media');
  require(Number.isSafeInteger(source.byte_size) && source.byte_size > 0 && source.byte_size <= 64 * 1024 * 1024, 'invalid_source_size');
  require(typeof source.retrieved_on === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(source.retrieved_on), 'invalid_source_date');
  require(new Date(source.retrieved_on).toISOString().slice(0, 10) === source.retrieved_on, 'invalid_source_date');
  require(typeof source.retrieved_at === 'string' && new Date(source.retrieved_at).toISOString() === source.retrieved_at && source.retrieved_at.startsWith(source.retrieved_on), 'invalid_source_time');
}

function validateEntry(entry) {
  fields(entry, ['id', 'revision', 'identity', 'file', 'label', 'evidence_state', 'unresolved_gates'], 'invalid_profile_entry');
  require(typeof entry.id === 'string' && token.test(entry.id), 'invalid_profile_id');
  require(typeof entry.revision === 'string' && token.test(entry.revision), 'invalid_profile_revision');
  require(entry.file === `profiles/${entry.id}.${entry.revision}.json`, 'invalid_profile_file');
  require(typeof entry.identity === 'string' && /^sha256:[0-9a-f]{64}$/.test(entry.identity), 'invalid_profile_identity');
  require(text(entry.label, 160), 'invalid_profile_label');
  require(entry.evidence_state === 'candidate', 'unqualified_evidence_state');
  require(Array.isArray(entry.unresolved_gates) && entry.unresolved_gates.length > 0 && entry.unresolved_gates.length <= 32, 'invalid_profile_gates');
  require(entry.unresolved_gates.every((value) => typeof value === 'string' && token.test(value)), 'invalid_profile_gate');
  unique(entry.unresolved_gates, 'duplicate_profile_gate');
}

export async function loadCatalog() {
  const root = new URL('../../../data/physical/', import.meta.url);
  const raw = await readFile(new URL('manifest.json', root), 'utf8');
  require(Buffer.byteLength(raw) <= 262144, 'manifest_too_large');
  const manifest = JSON.parse(raw);
  require(raw === `${JSON.stringify(manifest, null, 2)}\n`, 'noncanonical_manifest');
  const names = await readdir(new URL('profiles/', root));
  const files = new Map();
  for (const name of names) {
    require(/^[A-Za-z0-9][A-Za-z0-9._+-]*\.json$/.test(name), 'unexpected_profile_file');
    files.set(`profiles/${name}`, await readFile(new URL(`profiles/${name}`, root), 'utf8'));
  }
  return { manifest, files };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { manifest, files } = await loadCatalog();
  const profiles = await validateCatalog(manifest, files);
  console.log(`${profiles.length} canonical candidate profiles; ${manifest.sources.length} source revisions resolve offline`);
}
