import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Geometry-only stroke used by [DrawingCodec]. Kept free of Flutter types so the
/// codec is plain Dart (fast to test, safe on web).
class PackedStroke {
  final int tool; // index into DrawingTool.values
  final int color; // ARGB32
  final double size;
  final String? symbolType;
  final String? labelText;

  /// Flat list of coordinates: [x0, y0, x1, y1, ...].
  final List<double> xy;

  const PackedStroke({
    required this.tool,
    required this.color,
    required this.size,
    required this.xy,
    this.symbolType,
    this.labelText,
  });
}

class PackedDrawing {
  /// Small integer the caller can use (e.g. cup/disc ratio × 100).
  final int aux;

  /// Small strings the caller can use (e.g. diagram type, updatedAt).
  final List<String> meta;
  final List<PackedStroke> strokes;

  const PackedDrawing({this.aux = 0, this.meta = const [], required this.strokes});
}

class DrawingTooLargeException implements Exception {
  final int bytes;
  final int maxBytes;
  DrawingTooLargeException(this.bytes, this.maxBytes);

  @override
  String toString() =>
      'Drawing is too large to store ($bytes bytes, limit $maxBytes bytes). Remove some strokes and try again.';
}

/// Compact binary codec for vector drawings.
///
/// A stroke drawn by hand is recorded as one point per pointer event, which costs
/// about 20 bytes per point once stored as Firestore maps. This codec first thins
/// each stroke with Ramer–Douglas–Peucker (visually lossless at sub-pixel
/// tolerance), quantizes to 0.25 px, and writes zig-zag varint deltas. A typical
/// consultation sheet shrinks from ~100 KB to a few KB.
class DrawingCodec {
  DrawingCodec._();

  static const int formatVersion = 1;
  static const int _quantum = 4; // 1 / 4 px resolution
  static const int _maxStrokes = 5000;
  static const int _maxPointsPerStroke = 200000;
  static const int _maxMeta = 16;

  /// Simplification tolerances (px) tried in order until the result fits.
  static const List<double> toleranceLadder = [0.5, 1.0, 2.0, 4.0, 8.0];

  /// Packs [drawing] into at most [maxBytes], increasing simplification if needed.
  static Uint8List pack(PackedDrawing drawing, {required int maxBytes}) {
    late Uint8List last;
    for (final tolerance in toleranceLadder) {
      last = _encode(drawing, tolerance);
      if (last.length <= maxBytes) return last;
    }
    throw DrawingTooLargeException(last.length, maxBytes);
  }

  static PackedDrawing unpack(Uint8List data) {
    final r = _Reader(data);
    final version = r.byte();
    if (version != formatVersion) {
      throw FormatException('Unsupported drawing format version $version');
    }
    final aux = r.varint();
    final metaCount = r.varint();
    if (metaCount > _maxMeta) throw const FormatException('Corrupt drawing header');
    final meta = List<String>.generate(metaCount, (_) => r.string());

    final strokeCount = r.varint();
    if (strokeCount > _maxStrokes) throw const FormatException('Too many strokes');
    final strokes = <PackedStroke>[];
    for (var i = 0; i < strokeCount; i++) {
      final tool = r.byte();
      final color = r.uint32();
      final size = r.varint() / 10.0;
      final flags = r.byte();
      final symbol = (flags & 1) != 0 ? r.string() : null;
      final label = (flags & 2) != 0 ? r.string() : null;
      final n = r.varint();
      if (n > _maxPointsPerStroke) throw const FormatException('Too many points');
      final xy = List<double>.filled(n * 2, 0);
      var px = 0, py = 0;
      for (var p = 0; p < n; p++) {
        px += r.zigzag();
        py += r.zigzag();
        xy[p * 2] = px / _quantum;
        xy[p * 2 + 1] = py / _quantum;
      }
      strokes.add(PackedStroke(
        tool: tool,
        color: color,
        size: size,
        xy: xy,
        symbolType: symbol,
        labelText: label,
      ));
    }
    return PackedDrawing(aux: aux, meta: meta, strokes: strokes);
  }

  static Uint8List _encode(PackedDrawing d, double tolerance) {
    final w = _Writer();
    w.byte(formatVersion);
    w.varint(d.aux);
    w.varint(d.meta.length);
    for (final m in d.meta) {
      w.string(m);
    }
    w.varint(d.strokes.length);
    for (final s in d.strokes) {
      w.byte(s.tool);
      w.uint32(s.color);
      w.varint((s.size * 10).round().clamp(0, 1 << 20));
      var flags = 0;
      if (s.symbolType != null) flags |= 1;
      if (s.labelText != null) flags |= 2;
      w.byte(flags);
      if (s.symbolType != null) w.string(s.symbolType!);
      if (s.labelText != null) w.string(s.labelText!);

      final thinned = simplify(s.xy, tolerance);
      final n = thinned.length ~/ 2;
      w.varint(n);
      var px = 0, py = 0;
      for (var p = 0; p < n; p++) {
        final qx = (thinned[p * 2] * _quantum).round();
        final qy = (thinned[p * 2 + 1] * _quantum).round();
        w.zigzag(qx - px);
        w.zigzag(qy - py);
        px = qx;
        py = qy;
      }
    }
    return w.toBytes();
  }

  /// Ramer–Douglas–Peucker on a flat [x0,y0,x1,y1,...] list (iterative).
  static List<double> simplify(List<double> xy, double tolerance) {
    final n = xy.length ~/ 2;
    if (n < 3) return xy;
    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;
    final stack = <int>[0, n - 1];
    while (stack.isNotEmpty) {
      final end = stack.removeLast();
      final start = stack.removeLast();
      if (end <= start + 1) continue;
      final ax = xy[start * 2], ay = xy[start * 2 + 1];
      final bx = xy[end * 2], by = xy[end * 2 + 1];
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var maxDist = -1.0;
      var index = -1;
      for (var i = start + 1; i < end; i++) {
        final px = xy[i * 2], py = xy[i * 2 + 1];
        double dist;
        if (len2 == 0) {
          final ex = px - ax, ey = py - ay;
          dist = math.sqrt(ex * ex + ey * ey);
        } else {
          dist = ((dy * px - dx * py + bx * ay - by * ax).abs()) / math.sqrt(len2);
        }
        if (dist > maxDist) {
          maxDist = dist;
          index = i;
        }
      }
      if (maxDist > tolerance && index != -1) {
        keep[index] = true;
        stack..add(start)..add(index)..add(index)..add(end);
      }
    }
    final out = <double>[];
    for (var i = 0; i < n; i++) {
      if (keep[i]) {
        out..add(xy[i * 2])..add(xy[i * 2 + 1]);
      }
    }
    return out;
  }
}

class _Writer {
  final BytesBuilder _b = BytesBuilder(copy: false);

  void byte(int v) => _b.addByte(v & 0xFF);

  void uint32(int v) {
    _b.addByte((v >> 24) & 0xFF);
    _b.addByte((v >> 16) & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
  }

  void varint(int v) {
    var value = v < 0 ? 0 : v;
    while (value >= 0x80) {
      _b.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    _b.addByte(value);
  }

  void zigzag(int v) => varint(v >= 0 ? v * 2 : (-v) * 2 - 1);

  void string(String s) {
    final bytes = utf8.encode(s);
    varint(bytes.length);
    _b.add(bytes);
  }

  Uint8List toBytes() => _b.toBytes();
}

class _Reader {
  final Uint8List _d;
  int _i = 0;
  _Reader(this._d);

  int byte() {
    if (_i >= _d.length) throw const FormatException('Unexpected end of drawing data');
    return _d[_i++];
  }

  // Multiplication (not shifts) so the result is correct on web, where << is 32-bit signed.
  int uint32() => byte() * 16777216 + byte() * 65536 + byte() * 256 + byte();

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final b = byte();
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return result;
      shift += 7;
      if (shift > 28) throw const FormatException('Corrupt varint');
    }
  }

  int zigzag() {
    final v = varint();
    return (v & 1) == 0 ? v >> 1 : -((v + 1) >> 1);
  }

  String string() {
    final n = varint();
    if (n > 4096 || _i + n > _d.length) throw const FormatException('Corrupt string');
    final s = utf8.decode(_d.sublist(_i, _i + n));
    _i += n;
    return s;
  }
}
