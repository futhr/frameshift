# Content Pipeline

One source may deliberately produce different artwork for each physical medium.

```text
source -> crop/composition -> optional AI/transformation
                         |
          +--------------+--------------+
          |              |              |
        photo           paper          pixel
          |              |              |
     scale/profile   palette/dither  stylize/downsample
```

## Photo

Preserve photographic detail while accounting for resolution, viewing distance, matte surface and frame geometry.

## Paper

Render against the actual advertised pigment/palette capabilities. Quantization and dithering happen on the Mac.

## Pixel

Low resolution is an artistic constraint, not a defect. Candidate processing includes composition-aware crop, edge/shape emphasis, palette reduction, dithering, controlled pixelation and optional AI reinterpretation.

The source artwork is retained so improved renderers can regenerate targets later.

AI is optional and replaceable; the core pipeline must work deterministically without an external model/service.
