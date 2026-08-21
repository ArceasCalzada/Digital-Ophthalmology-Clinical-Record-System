# Lessons Learned & Mistakes Log

This document records past errors, debugging findings, and resolutions to prevent repeating mistakes.

---

### 1. Vector Drawing & Outline Rendering with `perfect_freehand`
- **Mistake:** Connecting `getStroke()` outline points with direct `lineTo` lines can produce visible straight-edge facets ("rasterized" look) on curves. Conversely, blind `quadraticBezierTo` without midpoint averaging caused pinched loops.
- **Resolution:** Use Catmull-Rom spline subdivision on input points (`_subdividePoints`), followed by midpoint quadratic bezier curves along the `getStroke` outline:
  ```dart
  for (int i = 1; i < outlinePoints.length; i++) {
    final midX = (current.dx + next.dx) / 2;
    final midY = (current.dy + next.dy) / 2;
    path.quadraticBezierTo(current.dx, current.dy, midX, midY);
  }
  ```
  Ensure `Paint()..isAntiAlias = true` and `..filterQuality = FilterQuality.high`.

---

### 2. Stroke Thinning & Dynamic Velocity Sensitivity Calibration
- **Tuning:** Constant thickness (`thinning: 0.1`) feels stiff and robotic. Excessive thinning (`thinning: 0.5+`) pinches fast strokes into hairlines.
- **Resolution:** Calibrate `thinning: 0.22` with `simulatePressure: true`, `smoothing: 0.80`, and `streamline: 0.55`. This creates a responsive, natural fountain/rollerball pen dynamic where line width gently and subtly tapers based on drawing speed while maintaining full body and legibility.

---

### 3. Dependency Updates & Flutter Execution Lifecycle
- **Mistake:** Assuming Hot Reload would load a newly added package (`perfect_freehand`).
- **Resolution:** Adding dependencies in `pubspec.yaml` requires `flutter pub get` followed by a full application restart (or rebuilding the web/desktop target).

---

### 4. Stopping Background Flutter/Dart Processes
- **Mistake:** Assuming the app would use new code while old Dart processes were still running in the background. Hot Restart / Hot Reload is not enough if background flutter run tasks hang.
- **Resolution:** To properly stop all old Flutter web instances on Windows, kill running Dart processes: `taskkill /F /IM dart.exe /T; taskkill /F /IM dartvm.exe /T; taskkill /F /IM dartaotruntime.exe /T`. Then start a fresh process using `C:\flutter\bin\flutter.bat run -d chrome`.
