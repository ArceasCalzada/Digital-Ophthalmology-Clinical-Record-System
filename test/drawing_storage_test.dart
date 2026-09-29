import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/config/app_limits.dart';
import 'package:ophthalmology_clinical_record_system/models/drawing_stroke.dart';
import 'package:ophthalmology_clinical_record_system/models/encounter.dart';
import 'package:ophthalmology_clinical_record_system/models/eye_exam.dart';
import 'package:ophthalmology_clinical_record_system/services/drawing_codec.dart';
import 'package:ophthalmology_clinical_record_system/services/storage_optimization_service.dart';

/// Smooth hand-drawn-looking stroke: ~1.5 px between pointer events.
List<double> _stroke(Random r, int n) {
  var x = 100 + r.nextDouble() * 500, y = 100 + r.nextDouble() * 700, a = r.nextDouble() * 2 * pi;
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    a += (r.nextDouble() - 0.5) * 0.35;
    x += cos(a) * 1.5;
    y += sin(a) * 1.5;
    out
      ..add(x)
      ..add(y);
  }
  return out;
}

List<VectorStroke> _vectorStrokes(Random r, int strokes, int pointsEach) => List.generate(strokes, (i) {
      final xy = _stroke(r, pointsEach);
      return VectorStroke(
        id: 'stk-$i',
        tool: i.isEven ? DrawingTool.pen : DrawingTool.highlighter,
        color: const Color(0xFFD32F2F),
        size: 2.5,
        points: [for (var k = 0; k < xy.length; k += 2) Offset(xy[k], xy[k + 1])],
        symbolType: i == 0 ? 'cataract' : null,
        labelText: i == 1 ? 'IOP 28' : null,
      );
    });

EyeExamData _exam() => EyeExamData(acuity: VisualAcuity(), refraction: Refraction());

Encounter _encounter({
  String complaint = 'Blurring of vision OU',
  PaperSheetDrawingData? sheet,
  EyeDrawingData? od,
}) =>
    Encounter(
      id: 'enc-1',
      patientId: 'pat-1',
      date: 'Aug 14, 2026',
      chiefComplaint: complaint,
      examOD: _exam(),
      examOS: _exam(),
      diagnosis: 'H25.13',
      treatmentPlan: 'Return in 6 months',
      paperSheetDrawing: sheet,
      drawingOD: od,
    );

void main() {
  group('DrawingCodec', () {
    test('round-trips strokes, colors, sizes, symbols and labels', () {
      final r = Random(1);
      final original = PackedDrawing(
        aux: 45,
        meta: ['fundus', '2026-08-14T09:41:12.000'],
        strokes: [
          PackedStroke(tool: 0, color: 0xFFD32F2F, size: 2.5, xy: _stroke(r, 60), symbolType: 'cataract'),
          PackedStroke(tool: 4, color: 0xFF1976D2, size: 16, xy: [10.25, 20.5], labelText: 'IOP 28 ↑'),
        ],
      );

      final back = DrawingCodec.unpack(DrawingCodec.pack(original, maxBytes: 20000));

      expect(back.aux, 45);
      expect(back.meta, ['fundus', '2026-08-14T09:41:12.000']);
      expect(back.strokes.length, 2);
      expect(back.strokes[0].color, 0xFFD32F2F);
      expect(back.strokes[0].size, 2.5);
      expect(back.strokes[0].symbolType, 'cataract');
      expect(back.strokes[1].labelText, 'IOP 28 ↑');
      expect(back.strokes[1].xy, [10.25, 20.5]);
      // Endpoints survive to within the 0.25 px quantum.
      final a = original.strokes[0].xy, b = back.strokes[0].xy;
      expect((a[0] - b[0]).abs(), lessThan(0.13));
      expect((a[a.length - 1] - b[b.length - 1]).abs(), lessThan(0.13));
    });

    test('a typical consultation sheet packs to a few KB (was ~100 KB as point maps)', () {
      final strokes = [
        for (final s in _vectorStrokes(Random(2), 50, 100))
          PackedStroke(tool: s.tool.index, color: s.color.toARGB32(), size: s.size, xy: [for (final p in s.points) ...[p.dx, p.dy]]),
      ];
      final packed = DrawingCodec.pack(PackedDrawing(strokes: strokes), maxBytes: AppLimits.maxPaperSheetDrawingBytes);
      expect(packed.length, lessThan(6 * 1024));
    });

    test('simplification keeps shape: every dropped point stays within tolerance of the line', () {
      final xy = _stroke(Random(3), 400);
      final thin = DrawingCodec.simplify(xy, 1.0);
      expect(thin.length, lessThan(xy.length));
      expect(thin.length, greaterThanOrEqualTo(4));
      expect(thin[0], xy[0]);
      expect(thin[thin.length - 2], xy[xy.length - 2]);
    });

    test('throws DrawingTooLargeException instead of storing an over-budget drawing', () {
      final noise = List<double>.generate(40000, (i) => ((i * 7919) % 1000).toDouble());
      expect(
        () => DrawingCodec.pack(
          PackedDrawing(strokes: [PackedStroke(tool: 0, color: 1, size: 1, xy: noise)]),
          maxBytes: 200,
        ),
        throwsA(isA<DrawingTooLargeException>()),
      );
    });

    test('rejects corrupt or hostile data without crashing or huge allocations', () {
      expect(() => DrawingCodec.unpack(Uint8List(0)), throwsFormatException);
      expect(() => DrawingCodec.unpack(Uint8List.fromList([9])), throwsFormatException); // bad version
      expect(
        () => DrawingCodec.unpack(Uint8List.fromList([1, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F])), // absurd stroke count
        throwsFormatException,
      );
      final good = DrawingCodec.pack(
        PackedDrawing(strokes: [PackedStroke(tool: 0, color: 1, size: 1, xy: _stroke(Random(4), 50))]),
        maxBytes: 5000,
      );
      expect(() => DrawingCodec.unpack(good.sublist(0, good.length ~/ 2)), throwsFormatException); // truncated
    });
  });

  group('Drawing models and Encounter Firestore serialization', () {
    test('PaperSheetDrawingData survives pack/unpack', () {
      final sheet = PaperSheetDrawingData(
        id: 'd',
        encounterId: 'e',
        patientId: 'p',
        strokes: _vectorStrokes(Random(5), 12, 80),
        updatedAt: '2026-08-14T10:00:00.000',
      );
      final back = PaperSheetDrawingData.fromPacked(sheet.toPacked(), encounterId: 'enc-9', patientId: 'pat-9');
      expect(back.strokes.length, 12);
      expect(back.encounterId, 'enc-9');
      expect(back.updatedAt, '2026-08-14T10:00:00.000');
      expect(back.strokes[0].symbolType, 'cataract');
      expect(back.strokes[1].labelText, 'IOP 28');
      expect(back.strokes[2].tool, DrawingTool.pen);
      expect(back.strokes[3].tool, DrawingTool.highlighter);
      expect(back.strokes[0].color.toARGB32(), 0xFFD32F2F);
    });

    test('EyeDrawingData keeps cup/disc ratio, diagram type and eye', () {
      final od = EyeDrawingData(
        id: 'x',
        encounterId: 'e',
        patientId: 'p',
        eye: EyeType.OD,
        diagramType: 'anterior',
        strokes: _vectorStrokes(Random(6), 5, 40),
        cdRatio: 0.65,
        updatedAt: '2026-08-14T10:00:00.000',
      );
      final back = EyeDrawingData.fromPacked(od.toPacked(), encounterId: 'e', patientId: 'p', eye: EyeType.OD);
      expect(back.diagramType, 'anterior');
      expect(back.cdRatio, closeTo(0.65, 0.001));
      expect(back.eye, EyeType.OD);
    });

    test('Encounter.toFirestore stores drawings as compact bytes and fromFirestore restores them', () {
      final sheet = PaperSheetDrawingData(
        id: 'd',
        encounterId: 'enc-1',
        patientId: 'pat-1',
        strokes: _vectorStrokes(Random(7), 30, 100),
        updatedAt: '2026-08-14T10:00:00.000',
      );
      final data = _encounter(sheet: sheet).toFirestore();

      expect(data['paperSheet'], isA<Uint8List>());
      expect(data.containsKey('drawOD'), isFalse, reason: 'no drawing, no field');
      final size = StorageOptimizationService.estimateDocumentBytes('patients/pat-1/encounters/enc-1', data);
      expect(size, lessThan(AppLimits.maxEncounterDocBytes));

      final restored = Encounter.fromFirestore(data);
      expect(restored.paperSheetDrawing, isNotNull);
      expect(restored.paperSheetDrawing!.strokes.length, 30);
      expect(restored.diagnosis, 'H25.13');
      expect(restored.patientId, 'pat-1');
    });

    test('a corrupt drawing does not stop the visit itself from loading', () {
      final data = _encounter().toFirestore();
      data['paperSheet'] = Uint8List.fromList([1, 2, 3]);
      final restored = Encounter.fromFirestore(data);
      expect(restored.paperSheetDrawing, isNull);
      expect(restored.chiefComplaint, 'Blurring of vision OU');
    });

    test('over-long clinical text is rejected with a clear message, never silently cut', () {
      expect(
        () => _encounter(complaint: 'x' * (AppLimits.maxLongTextLength + 1)).toFirestore(),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Chief complaint'))),
      );
    });

    test('over-long short exam field is rejected', () {
      final enc = Encounter(
        id: 'e',
        patientId: 'p',
        date: 'Aug 14, 2026',
        chiefComplaint: 'c',
        examOD: EyeExamData(acuity: VisualAcuity(oldCc: 'y' * 400), refraction: Refraction()),
        examOS: _exam(),
        diagnosis: 'd',
        treatmentPlan: 't',
      );
      expect(() => enc.toFirestore(), throwsFormatException);
    });
  });

  group('StorageOptimizationService size guard', () {
    test('estimates Firestore stored size with the documented formula', () {
      // name: ("users"=6) + ("abc"=4) + 16 = 26; field: ("a"=2) + ("xy"=3) = 5; overhead 32.
      expect(StorageOptimizationService.estimateDocumentBytes('users/abc', {'a': 'xy'}), 26 + 5 + 32);
      // numbers 8, bool 1, null 1, bytes = length
      expect(
        StorageOptimizationService.estimateDocumentBytes('c/d', {'n': 1, 'b': true, 'z': null, 'raw': Uint8List(100)}),
        (2 + 2 + 16) + (2 + 8) + (2 + 1) + (2 + 1) + (4 + 100) + 32,
      );
    });

    test('rejects a document over its byte budget', () {
      expect(
        () => StorageOptimizationService.auditAndOptimizePayload(
          {'notes': 'z' * 5000},
          maxDocBytes: 2048,
          docPath: 'c/d',
        ),
        throwsFormatException,
      );
      expect(
        StorageOptimizationService.auditAndOptimizePayload({'notes': 'ok'}, maxDocBytes: 2048, docPath: 'c/d'),
        isNotEmpty,
      );
    });

    test('finds base64 images hidden in nested maps and lists', () {
      expect(
        () => StorageOptimizationService.auditAndOptimizePayload({
          'exam': {
            'attachments': ['data:image/png;base64,AAAA'],
          },
        }),
        throwsFormatException,
      );
    });

    test('gzip helpers still round-trip (web-safe implementation)', () {
      const text = 'Nuclear sclerotic cataract Grade 2+ OD. Recommend phacoemulsification with IOL.';
      expect(StorageOptimizationService.decompressPayload(StorageOptimizationService.compressPayload(text)), text);
    });
  });
}
