# Pixel Frame — HUB75 Reference

**Status: research / candidate prototype**

## Purpose

Turn low pixel density into an intentional medium. Photographs become graphical, abstract or generative interpretations rather than poor high-resolution approximations.

## Candidate geometry

P3-class HUB75 RGB modules, approximately 192 x 192 mm and 64 x 64 pixels each, arranged 3 x 2: approximately 576 x 384 mm and 192 x 128 logical pixels. This is A2-like in presence, not ISO A2.

## Controller

An ESP32-S3-class HUB75 controller is attractive for Wi-Fi, local storage and matrix driving in a small package. Waveshare and similar boards are candidates; electrical compatibility, scan modes, memory and stable refresh require physical validation.

## Power warning

The controller may be tiny; the PSU is not necessarily tiny. RGB matrices can draw substantial current. Indoor brightness limits, real artwork consumption, PSU depth, thermals and wiring must be measured.

## Rendering

The Mac owns crop, downsampling, palette treatment, dithering, optional AI reinterpretation and optional animation. The frame primarily receives, stores and displays prepared assets.

Visible pixels are intentional.
