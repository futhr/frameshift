# Release manifest verification

`manifest.mjs` verifies one detached Ed25519 signature against a separately
pinned SHA-256 fingerprint of the public key's DER SPKI bytes, then reads and
hashes every exact local archive. The verifier accepts no placeholder artifact.

```sh
./scripts/check release
mise exec -- node release/verify.mjs MANIFEST.json MANIFEST.sig RELEASE.pub.pem ARTIFACT_DIR TRUSTED_KEY_SHA256_FILE
```

The trust file must come from the owner-approved publication configuration, not
from the release download. No production key or release files are in this
repository yet. The [release contract](../docs/architecture/release-manifest.md)
lists the additional signing and installed acceptance gates.
