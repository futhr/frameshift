# System Architecture

## Goal

FrameShift provides one content/control system for radically different physical display technologies.

```text
source artwork
     |
macOS library / scheduler
     |
transformations / optional AI
     |
target renderer
     |
Frame Protocol
     |
frame agent -> display adapter -> panel
```

The host owns expensive computation. The frame owns persistence, capability reporting, safe display updates, and enough scheduling to remain autonomous.

## FrameShift Host

The macOS application handles artwork, discovery/pairing, schedules, target rendering, optional AI transformations, scaling, palette mapping, dithering, synchronization and status.

Elixir is the preferred core runtime where practical. Native macOS integration may use a small Swift shell/helper.

## Frame Agent

Candidate runtimes include AtomVM on ESP32-class hardware, Nerves when a Linux-class board is genuinely justified, or native firmware/driver layers where display timing requires them. The architecture does not require one embedded runtime for every display.

## Display Adapter

Initial adapter classes are eDP/LVDS matte IPS, reflective e-paper, and HUB75 RGB matrix.

## Offline behavior

Loss of the Mac/network must not blank a frame. A frame SHOULD retain its last successfully committed asset. Frames capable of local playlists MAY retain multiple assets and schedules.

## Non-goals

FrameShift is not initially a cloud photo service, commercial signage system, social network, vendor-specific application, continuous desktop streaming system, or a requirement for one universal electronics board.
