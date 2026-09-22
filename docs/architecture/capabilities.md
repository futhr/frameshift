# Capability Model

FrameShift targets capabilities rather than named hardware.

A 27-inch IPS panel, A2 color e-paper panel and 192x128 RGB matrix differ electrically but can consume the same conceptual artwork if the host understands their constraints.

## Continuous-color raster

Typical target: matte IPS. Relevant capabilities include pixel/physical dimensions, color space, orientation, raster formats and optional video/animation.

## Restricted-palette reflective

Typical target: e-paper. Relevant capabilities include exact palette, full/partial refresh, refresh duration, ghosting constraints and power behavior.

## Low-resolution emissive matrix

Typical target: HUB75. Relevant capabilities include matrix dimensions, scan configuration, brightness, refresh requirements and frame-buffer limits.

Renderers MUST derive output from capabilities wherever possible. Hardware model identifiers may describe quirks but should not become the primary API.
