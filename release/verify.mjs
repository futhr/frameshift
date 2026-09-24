#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { verifyRelease } from './manifest.mjs';

const [manifestPath, signaturePath, publicKeyPath, artifactDirectory, trustFile] =
  process.argv.slice(2);
if (!manifestPath || !signaturePath || !publicKeyPath || !artifactDirectory || !trustFile ||
    process.argv.length !== 7) {
  process.stderr.write('usage: node release/verify.mjs MANIFEST SIGNATURE PUBLIC_KEY ARTIFACT_DIR PINNED_KEY_SHA256_FILE\n');
  process.exit(64);
}

try {
  const trustedKeyDigest = (await readFile(trustFile, 'utf8')).trim();
  const manifest = await verifyRelease({ manifestPath, signaturePath, publicKeyPath,
    trustedKeyDigest, artifactDirectory });
  process.stdout.write(`verified ${manifest.version}: ${manifest.artifacts.length} exact artifacts\n`);
} catch (error) {
  process.stderr.write(`release verification refused: ${error.message}\n`);
  process.exitCode = 1;
}
