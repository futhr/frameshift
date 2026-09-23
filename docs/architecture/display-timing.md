# Display Timing and Pinned Artwork Loops

**Status:** protocol contract and implementation plan; physical energy defaults await measurement

## Terms and authority

`minimumDwellMs` is the receiver's hard lower bound between completed still
updates. An optional `recommendedDwellMs` is a profile suggestion for a new
cycling playlist, not a panel scan rate or a claim of optimal battery life.
`recommendationBasis` is either `measured-energy` (whole assembled frame,
including sleep, wake, contact, transfer, and refresh) or
`provisional-profile` (an explicit product starting point). The recommendation
must be at least the minimum. An operator override is stored per frame and
clamped to its current capability minimum when submitted. The host displays
the source and basis, and warns if a changed profile forces a longer dwell.

The Paper Waveshare E6 candidate manual calls for at least 180 seconds between
refreshes, at least one refresh per 24 hours while in use, and panel sleep or
power removal after refresh. The 180 seconds is a **minimum**, not the
energy-optimal interval. Until assembled-frame measurements exist, Frameshift
uses a provisional six-hour cycling suggestion for this candidate. Its
receiver advertises `minimumDwellMs: 180000`,
`recommendedDwellMs: 21600000`, and
`recommendationBasis: provisional-profile`. A 24-hour maintenance refresh of
unchanged content is a separate receiver policy and must not advance a
playlist or falsely report new art. This policy needs panel/controller
qualification before hardware release. [Waveshare E6 manual](https://www.waveshare.com/wiki/13.3inch_e-Paper_HAT%2B_%28E%29_Manual).

Photo and Pixel require continuous panel/backlight or matrix scan power while
visible. A longer artwork dwell alone has no established display-energy
benefit. Their candidate profiles advertise their safe minimum but no energy
recommendation; a user can choose an interval for aesthetic reasons. Brightness,
current limits, and scheduled off periods are the relevant power controls.
The [Waveshare P3 specification](https://www.waveshare.com/wiki/RGB-Matrix-P3-64x64)
lists each module at 5 V/4 A and up to 20 W, independent of artwork changes.

## Pinned loop intent

Pin is a library retention action. The explicit per-frame **Loop pinned
artwork** action takes an ordered snapshot of pinned master identifiers. Pinning
or unpinning later proposes a new revision; it does not silently mutate an
active frame playlist. The UI shows the included count, order, interval,
profile suggestion or user override, and pending/active status. Without a
paired frame it may prepare a draft but cannot claim a running loop.

The host renders every master for the exact selected frame profile, validates
capacity, transfers and verifies every immutable asset, then atomically
replaces the complete `cycle` playlist. If preparation fails, the old playlist
remains active. Removal cannot collect a referenced asset. A new single-image
Send explicitly suspends the loop or requires the user to resume it; the host
never races independent desired and playlist writers. The host persists an
idempotent intent, revision, target capability revision, and acknowledgement
under its single writer. A sleeping frame fetches the playlist body by revision
at contact after all assets, verifies it, and acknowledges installation; a
manifest containing only a revision is not sufficient to execute a loop.

## Receiver clock and failure behavior

The receiver owns relative dwell timing and cycles cached stills even when the
host is offline. The deadline is based on confirmed display completion, not
queue or transfer time. Paper uses an RTC wake, initializes the panel, refreshes,
confirms completion, cuts panel power, and sleeps. Photo holds the framebuffer;
Pixel scans the held buffer. Both swap only at a dwell boundary. No display
class interprets playlist entries as animation frames.

On boot, the receiver restores the playlist revision, current entry, and
deadline. It reconciles an interrupted refresh with physical truth before
advancing the index. Failure retains the last confirmed current image and
retries with bounded backoff; elapsed time never causes a burst of catch-up
refreshes. Monotonic time is used while awake. Sleep deadlines require a
qualified RTC and clock-error policy. A frame without that evidence must
advertise playlist cycling unavailable rather than let the Mac simulate a
running loop. State/telemetry distinguish playlist accepted, next wake,
refreshing, displayed, and failed. Tests cover long offline periods, restart,
power loss, clock jumps, full storage, unsupported dwell, and revision races.

## Qualification gate

For each exact hardware revision, record the measured full energy cycle at
several dwells and temperatures, sleep current, RTC drift, refresh duration,
and visible behavior. Replace the provisional Paper suggestion only when the
measurements support it. Show the measurement revision in capabilities and
retain it with each playlist intent so a firmware/profile change triggers
revalidation.
