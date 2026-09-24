# Static installation guide

This directory builds the illustrative Frameshift field guide and offline
browser lab. It is a development artifact, not a published installer or
physical frame validation. The requirements are in
[browser guide simulation](../docs/architecture/guide-simulation.md) and
[implementation plan](../docs/architecture/implementation-plan.md).

Run `./scripts/check guide` from the repository root to compile the pinned
Gleam JavaScript target, produce `guide/dist`, and test the lab state model.
On a Mac with Chrome, run `./scripts/check guide-browser` to exercise the
page at a real mobile viewport, check accessible names and keyboard actions,
reject invalid files, load a local still, and verify delivery recovery after
the local HTTP server stops. Set `FRAMESHIFT_GUIDE_SCREENSHOT_DIR` to a
directory to save the desktop, mobile, and lab screenshots from that smoke
test.

`guide/wrangler.jsonc` points Workers Static Assets at `guide/dist`. Its
`workers_dev` setting is disabled. A domain owner must separately configure
the intended hostname and public release artifact channel before any
deployment. The guide contains no live download links until a checked release
manifest and signed artifacts exist. The source repository's visibility is
not part of this deployment path.

The three compressed frame illustrations come from the maintainer's desktop
`Frameshift.html` visual draft. The Frameshift SVG is the existing macOS mark.
No externally loaded fonts, scripts, trackers, or image hosts are required.
