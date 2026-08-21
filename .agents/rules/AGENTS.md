# Digital Clinical Record System — Agent Instructions & Knowledge Base

This file serves as persistent memory and instructions for AI agents working in this codebase.

## 📚 Knowledge Base & LLM Wiki
Refer to the project documentation under `.agents/docs/` for architecture, patterns, and lessons learned:
- `.agents/docs/lessons_learned.md`: Critical mistakes made, solutions, and anti-patterns.
- `.agents/docs/drawing_system.md`: Vector inking engine, stroke algorithms, and canvas standards.
- `.agents/docs/architecture.md`: Project components, data models, views, and workflow.

## ⚠️ Core Project Rules
1. **Drawing Engine (`perfect_freehand` + Spline Smoothing)**:
   - Subdivide input touch coordinates with Catmull-Rom interpolation (`_subdividePoints`) to prevent input quantization jitter.
   - Convert `getStroke` outline points using midpoint quadratic bezier curves (`path.quadraticBezierTo(current, midpoint)`) with `PaintingStyle.fill` and `isAntiAlias: true`.
   - Set `thinning: 0.22` and `simulatePressure: true` for dynamic speed-responsive pen tapering (0.0 for highlighter).
2. **Environment & Execution**:
   - Flutter SDK path: `C:\flutter\bin\flutter.bat`.
   - Web target (`chrome` / `edge`) should be prioritized when testing in non-MSVC environments.
   - When new dependencies are added to `pubspec.yaml`, run `flutter pub get` and perform a full restart.
