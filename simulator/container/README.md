# Container frame receiver

Run `scripts/check container` from the repository root with a Docker-compatible
daemon. The check builds a digest-pinned Elixir/OTP image, starts the actual
host mutual-TLS outbox, and runs one-shot Paper, Photo, and Pixel receiver
containers against it. The test owns and removes its temporary frame data and
test certificates. Docker is not needed for the ordinary core unit gate.

The receiver uses exact candidate geometry with RGB24 **proxy** artifacts:

| Class | Manufacturer fixture | Proxy raster | Quoted/model timing |
| --- | --- | --- | --- |
| Paper | Waveshare 13.3-inch E6 HAT+ | 1600×1200 | Vendor full refresh 19,000 ms; test clock defaults to zero delay |
| Photo | BOE MV270QHM-N40 preliminary P1 | 2560×1440 | Nominal 60 Hz scan, represented as a 17 ms frame period |
| Pixel | Six Waveshare P3 64×64 modules | 192×128 | Continuous 1/32-scan bitplanes; 17 ms is a software swap scenario, not a measured refresh |

Each contact pins the host SPKI, fetches the manifest and exact artifact,
verifies digest and size, writes an inactive asset, and acknowledges the
display result. The fault selector supports missed contact, altered transfer,
storage full, display failure, process exit after download, and stale ack.
Paper also refuses a modeled refresh outside 0–40 °C. Temporary state is
retained between containers to exercise restart and retry.

The [simulator specification](../../docs/architecture/container-frame-simulator.md)
records source documents, evidence limits, and physical validation still
required. This image is test infrastructure; it is not frame firmware.
