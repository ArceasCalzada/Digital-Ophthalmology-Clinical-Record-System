# Drawing System Architecture

## Overview
The Digital Clinical Record system supports vector drawing across two main surfaces:
1. **Paper Sheet Consultation Record** (`PaperSheetCanvas`): Full-page physical paper chart replica with handwriting annotations.
2. **Anatomical Eye Diagram Canvas** (`EyeDrawingCanvas`): Ophthalmic diagramming with anterior, fundus, and plain templates.

## Inking Engine
Strokes are represented as `VectorStroke` models holding raw pointer touch coordinates (`List<Offset>`). Rendering is handled via `perfect_freehand` combined with spline subdivision:
- **Stroke Options:**
  - `thinning: 0.22` (balanced speed-responsive tapering; 0.0 for highlighter)
  - `smoothing: 0.80` (silky contour anti-jitter)
  - `streamline: 0.55` (responsive stroke tracking)
  - `simulatePressure: true`
- **Rendering Pipeline:**
  - Raw pointer touch coordinates are enriched with Catmull-Rom spline subdivision (`_subdividePoints`, `maxDistance: 5.0`)
  - Subdivided coordinates are mapped to `PointVector`
  - `getStroke()` generates outline polygon points
  - Outline converted to `Path` using midpoint quadratic bezier curves (`path.quadraticBezierTo(current, midpoint)`) for C1 continuous tangents with zero polygonal facet edges
  - Rendered with `PaintingStyle.fill`, `isAntiAlias: true`, and `FilterQuality.high`
