# macOS Host

## Role

One macOS application is the FrameShift control plane for all display classes.

It maintains artwork and frames, discovers/pairs devices, inspects capabilities, renders assets, previews output, manages schedules/playlists, synchronizes changes and runs optional AI/image-processing workflows.

## Runtime direction

Elixir is the preferred orchestration/core language. A thin native macOS component may provide lifecycle/platform integration where Apple APIs require it.

The design should investigate a supervised Elixir core packaged behind a conventional macOS application rather than forcing all logic into Swift.

## Background operation

Background synchronization must use supported macOS lifecycle mechanisms. The project should investigate the appropriate ServiceManagement/launchd arrangement for the eventual packaging model.

The Mac is not required to remain awake for artwork to remain visible. Frames cache committed content. A sleeping/offline Mac merely pauses future synchronization.

## Abstraction

Conceptually the host performs `send_artwork(frame, artwork)`; it should not expose vendor-specific send paths.

Nothing in Frame Protocol should prevent future Linux/iOS/other sender implementations.
