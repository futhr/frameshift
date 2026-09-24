# Linux and Raspberry Pi Hosts

**Status:** normative platform-port requirements; no Linux/Pi release is yet qualified

## Roles

Ubuntu on amd64 or arm64 is the general Linux host. Raspberry Pi 5 with
supported Ubuntu Server arm64 is a headless host using the same application
release contract. A Pi 5 Nerves image is a separately packaged dedicated
bridge/appliance. These are external hosts or bridges; no Raspberry Pi is part
of a Frameshift reference-frame bill of materials.

All roles consume the same domain commands, frame protocol, immutable library,
qualification identities, and authoritative Delivery state. Optional Apple
Vision, MediaGenerationKit, Keychain, and UI facilities report unavailable
through explicit adapters. Local import and rendering remain usable without
an AI provider. A Linux graphical shell is a separate UI qualification; the
headless service and local command/diagnostic CLI are the initial Linux
interface.

## Ubuntu host

- Package target-specific OTP and Exqlite releases plus the native Zig raster
  worker; verify all NIF/shared-library dependencies on clean supported images.
- Run as an unprivileged dedicated service identity through systemd, with
  private state and runtime directories, bounded resources, restart policy,
  and an explicit stop/disable/remove path. The service must not run as root.
- Use separate command and read-only diagnostic Unix sockets with peer
  credentials and private permissions. An administrator grants command access
  to an explicit local control group and diagnostic access to a distinct
  observer group; commands retain durable replay receipts and user attribution.
  Before changing permissions or binding either socket, the service checks the
  directory itself with `lstat` and rejects a symlink or non-directory without
  touching its target. It refuses to replace a live socket. Group ownership
  and admission need installed Linux tests; the current Mac private-user socket
  policy does not establish that access model.
  The Linux CLI must cover import, target discovery/pairing, send, state, and
  recovery as well as diagnostics. No general LAN control endpoint is exposed.
- For import, the CLI opens the caller's file and streams bounded bytes into a
  service-owned staging area over authenticated local IPC. The service does
  not follow caller-provided filesystem paths or require access to the caller's
  home directory.
- Use journald for redacted operational logs and `journalctl` for reading them;
  keep SQLite audit and bounded metrics separate. Ship `frameshiftctl` for
  read-only health, metrics, and audit queries alongside its authenticated
  local command surface.
- Provide a credential adapter with protected file or systemd credential
  loading. TPM-backed encrypted credentials are used only where the selected
  installation supports them; no private key goes into a unit environment
  variable or the metadata database. Define backup and identity-recovery paths.
- Store artwork and SQLite metadata on a qualified local filesystem. Install,
  upgrade, downgrade rejection, database migration, full-disk, power-loss, and
  backup/restore tests run on amd64 and arm64.

## Nerves Pi 5 bridge

Use the official `nerves_system_rpi5` as the base when a dedicated appliance
provides value beyond Ubuntu. Its firmware and root filesystem are updated as
a Nerves image, with persistent application data on `/data`. The bridge must
validate newly booted firmware or revert; signing and anti-rollback policy are
release gates. If it hosts the full library, SQLite and objects reside on
`/data` and pass the same storage tests; a simple relay bridge need not hold a
second authoritative library.

Nerves has no systemd journal. Send sanitized OTP operational records to a
bounded circular `logger_disk_log_h` sink on persistent storage and expose the
same diagnostic CLI contract. A hardware-backed device identity such as
NervesKey is a candidate only after physical provisioning and replacement
tests; otherwise the image must disclose and qualify its chosen custody
method. A NervesHub service is optional, not required for local artwork.

## Qualification

Record exact OS/image, CPU architecture, OTP, NIF, renderer, filesystem, and
storage medium. Run portable contract suites, clean install/update/removal,
network partition, denied credentials, power interruption, and independent
frame interoperability. Measure idle CPU, memory, wakeups, storage wear, and
the metrics/log disk ceiling. A Pi appliance claim additionally needs signed
firmware recovery, physical service access, and secure identity provisioning.

Upstream evidence: [Nerves Pi 5 system](https://github.com/nerves-project/nerves_system_rpi5),
[NervesHub firmware signing](https://docs.nerves-hub.org/nerves-hub/setup/firmware-signing-keys),
[systemd credentials](https://systemd.io/CREDENTIALS/), and
[OTP circular logger](https://www.erlang.org/docs/26/man/logger_disk_log_h.html).
