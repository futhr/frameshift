# Hardware Principles

Reference frames are product interoperability and evidence targets within the
[Conjunct consumer profile](../architecture/conjunct-integration.md). Exact
manufacturer components and assembly choices produce a composition, procedures
and independent parts/list output. Company branding and seller/service roles
are separate inputs for any later admitted operation. Transactional shop work
is on hold. These physical requirements do not certify a setup.

## Non-negotiable

1. **The complete object is a thin picture frame.** Panel, controller, storage,
   battery/converter, connectors, cable bends, mounting, airflow, backing, and
   wood rebate all count. There is no arbitrary global diagonal ceiling;
   supported profiles retain actual physical and software bounds.
2. **No Raspberry Pi hardware in a reference build.** The frame uses the
   smallest non-Raspberry controller that satisfies its measured job.
3. **Still images only.** Hardware is not sized for video, animation, audio, or
   continuous network streaming.
4. **Last valid art survives failure.** Network, host, update, brownout, and
   transfer failures do not intentionally blank the display.
5. **Electrical safety is part of the design.** No exposed mains, unfused high-
   current distribution, unprotected battery, or unreviewed in-wall wiring.

## Selection principles

- Choose any frame class; there is no mandatory build order.
- As optional risk-reduction guidance, prototype the selected class's riskiest
  assumptions cheaply before premium hardware or finished joinery.
- Prefer raw panels for final thinness, but allow a donor monitor/development
  board when it is the fastest honest prototype.
- Move expensive generation and image transformation to the Mac.
- Treat panel, driver/controller, waveform/scan mode, firmware, and renderer
  profile as one qualified revision.
- Prefer replaceable display and power adapters over a universal board.
- Zero visible cable is a priority in mechanical/power research, not a reason
  to mislabel an emissive display as passive.
- Keep external supplies certified and outside the wood frame when practical.
- Make service access possible without stressing glass, FPC, or high-current
  connectors.
- Record provenance and license before reusing an upstream schematic, timing
  program, driver, or enclosure asset.

## Power honesty

- Paper may be battery-powered and fully off between refreshes.
- Photo needs continuous controller/backlight power while visible.
- Pixel needs continuous LED refresh and may approach high current.
- Brightness limits are electrical limits, not only UI preferences.
- Battery-life claims use full-device measurements over real cycles, not chip
  data-sheet sleep current.
- “No visible cable” can mean a concealed cable or powered mount. Document the
  actual energy path.

## Required build record

Every physical build records:

- builder, date, purpose, and photos;
- exact supplier, SKU, PCB/panel revision, lot markings, and data sheets;
- active area, panel outline, bezel, mass, center of gravity, and glass/FPC
  handling;
- front-to-back stack with maximum depth at every region;
- connector height, exit direction, cable bend radius, strain relief, and
  service path;
- supply voltage, protection, fuse strategy, wire gauge, connector current, and
  measured current/power by operating state;
- steady-state and worst-case temperatures inside the final material stack;
- firmware/toolchain commits and artifact/profile revision;
- display tests, failures, deviations, and whether the exact assembly passed.

One passing sample is prototype evidence, not a production tolerance study.
