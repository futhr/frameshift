# Frameshift raster worker

`frameshift-raster` is the isolated deterministic raster process. It accepts
bounded, length-framed binary jobs on standard input and emits one framed
terminal response per complete job on standard output. It receives canonical
RGBA8 pixels, explicit composition parameters, and either an experimental
RGB24 profile or a caller-supplied indexed palette. It receives no credentials,
URLs, provider configuration, or frame identity.

The current research-preview renderer uses integer arithmetic for crop,
nearest/bilinear resize, alpha composition, palette selection, ordered dither,
and Floyd–Steinberg error diffusion. RGB operations are byte-space transforms;
they do not claim measured colorimetric accuracy. Hardware palette codes,
packing, transfer functions, and sharpening remain gated on an exact qualified
display profile.

## Wire request v0.1

Each request starts with a four-byte big-endian body length. The 52-byte body
header is followed by `paletteCount × 3` RGB bytes and exact
`sourceWidth × sourceHeight × 4` RGBA8 bytes.

| Offset | Type | Field |
| ---: | --- | --- |
| 0 | 4 bytes | `FSR1` |
| 4 | `u8` | protocol major (`0`) |
| 5 | `u8` | protocol minor (`1`) |
| 6 | `u8` | command (`1`, render) |
| 7 | `u8` | output (`1` RGB24, `2` indexed8) |
| 8 | `u8` | resize (`1` nearest, `2` bilinear) |
| 9 | `u8` | dither (`0` none, `1` ordered 2×2, `2` Floyd–Steinberg) |
| 10 | `u16` | reserved, zero |
| 12 | `u32` | source width |
| 16 | `u32` | source height |
| 20 | `u32` | crop x |
| 24 | `u32` | crop y |
| 28 | `u32` | crop width |
| 32 | `u32` | crop height |
| 36 | `u32` | target width |
| 40 | `u32` | target height |
| 44 | 4 bytes | background RGB followed by a reserved zero byte |
| 48 | `u16` | palette entry count |
| 50 | `u16` | reserved, zero |

Lengths are capped at 64 MiB, dimensions at 32,768, and decoded source/target
rasters at 16,777,216 pixels. All integers are big-endian.

## Wire response v0.1

The response also starts with a four-byte big-endian body length. Its 20-byte
body header contains `FSO1`, protocol `0.1`, a stable status byte, output format,
width, height, and payload length, followed by the payload only on success.

| Status | Meaning |
| ---: | --- |
| 0 | success |
| 1 | malformed frame |
| 2 | unsupported protocol version |
| 3 | length, dimension, or pixel bound exceeded |
| 4 | invalid crop |
| 5 | invalid output, filter, dither, or palette profile |
| 6 | allocation failed |

Run the complete worker build and tests with:

```sh
mise exec -- zig build test
mise exec -- zig build -Doptimize=ReleaseSafe
```
