import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

List<Offset> smoothAndSubdividePoints(List<Offset> points, {double maxDistance = 6.0}) {
  if (points.length < 3) return points;

  final result = <Offset>[points.first];
  for (int i = 0; i < points.length - 1; i++) {
    final p0 = i > 0 ? points[i - 1] : points[i];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = (i + 2 < points.length) ? points[i + 2] : p2;

    final dist = (p2 - p1).distance;
    if (dist > maxDistance) {
      final segments = (dist / maxDistance).ceil().clamp(2, 6);
      for (int s = 1; s < segments; s++) {
        final t = s / segments;
        // Catmull-Rom spline interpolation
        final t2 = t * t;
        final t3 = t2 * t;

        final x = 0.5 * (
          (2 * p1.dx) +
          (-p0.dx + p2.dx) * t +
          (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
          (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3
        );
        final y = 0.5 * (
          (2 * p1.dy) +
          (-p0.dy + p2.dy) * t +
          (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
          (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3
        );
        result.add(Offset(x, y));
      }
    }
    result.add(p2);
  }
  return result;
}

Path getSmoothStrokePath(List<Offset> rawPoints, double size, {bool isHighlighter = false, double thinning = 0.22}) {
  if (rawPoints.isEmpty) return Path();
  if (rawPoints.length == 1) {
    final path = Path();
    path.addOval(Rect.fromCircle(center: rawPoints.first, radius: size / 2));
    return path;
  }

  // Pre-process points with Catmull-Rom smoothing to remove input quantization jitter on web
  final points = smoothAndSubdividePoints(rawPoints);

  final strokeOptions = StrokeOptions(
    size: isHighlighter ? size * 2.0 : size,
    thinning: isHighlighter ? 0.0 : thinning,
    smoothing: 0.80,
    streamline: 0.55,
    simulatePressure: true,
    isComplete: true,
  );

  final outlinePoints = getStroke(
    points.map((p) => PointVector(p.dx, p.dy)).toList(),
    options: strokeOptions,
  );

  final path = Path();
  if (outlinePoints.isEmpty) return path;

  if (outlinePoints.length < 3) {
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }
    path.close();
    return path;
  }

  // Smooth quadratic bezier curves through midpoint tangent vertices
  final first = outlinePoints[0];
  final second = outlinePoints[1];
  path.moveTo((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);

  for (int i = 1; i < outlinePoints.length; i++) {
    final current = outlinePoints[i];
    final next = outlinePoints[(i + 1) % outlinePoints.length];
    final midX = (current.dx + next.dx) / 2;
    final midY = (current.dy + next.dy) / 2;
    path.quadraticBezierTo(current.dx, current.dy, midX, midY);
  }

  path.close();
  return path;
}

void main() {
  test('Subdivided and smoothed stroke path verification', () {
    final rawPoints = <Offset>[
      const Offset(10, 10),
      const Offset(50, 10), // 40px gap
      const Offset(90, 60), // 64px gap
    ];
    final smoothed = smoothAndSubdividePoints(rawPoints);
    expect(smoothed.length, greaterThan(rawPoints.length));

    final path = getSmoothStrokePath(rawPoints, 3.0);
    expect(path.getBounds().isEmpty, isFalse);
  });
}
