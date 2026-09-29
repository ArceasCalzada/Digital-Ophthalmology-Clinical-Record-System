import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/app_limits.dart';
import '../services/drawing_codec.dart';
import 'eye_exam.dart';

enum DrawingTool { pen, highlighter, eraser, symbol, text }

List<PackedStroke> _toPacked(List<VectorStroke> strokes) => [
      for (final s in strokes)
        PackedStroke(
          tool: s.tool.index,
          color: s.color.toARGB32(),
          size: s.size,
          symbolType: s.symbolType,
          labelText: s.labelText,
          xy: [
            for (final p in s.points) ...[p.dx, p.dy],
          ],
        ),
    ];

List<VectorStroke> _fromPacked(List<PackedStroke> packed, String idPrefix) => [
      for (var i = 0; i < packed.length; i++)
        VectorStroke(
          id: '$idPrefix-$i',
          tool: packed[i].tool >= 0 && packed[i].tool < DrawingTool.values.length
              ? DrawingTool.values[packed[i].tool]
              : DrawingTool.pen,
          color: Color(packed[i].color),
          size: packed[i].size,
          symbolType: packed[i].symbolType,
          labelText: packed[i].labelText,
          points: [
            for (var k = 0; k + 1 < packed[i].xy.length; k += 2) Offset(packed[i].xy[k], packed[i].xy[k + 1]),
          ],
        ),
    ];

class VectorStroke {
  final String id;
  final DrawingTool tool;
  final Color color;
  final double size;
  final List<Offset> points;
  final String? symbolType; // e.g. 'cataract', 'retinal_tear', 'flame_hem', 'drusen', 'glaucoma_notch', 'pterygium'
  final String? labelText;

  VectorStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.size,
    required this.points,
    this.symbolType,
    this.labelText,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool': tool.name,
      'color': color.toARGB32(),
      'size': size,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'symbolType': symbolType,
      'labelText': labelText,
    };
  }

  factory VectorStroke.fromJson(Map<String, dynamic> json) {
    return VectorStroke(
      id: json['id'] as String,
      tool: DrawingTool.values.firstWhere(
        (e) => e.name == json['tool'],
        orElse: () => DrawingTool.pen,
      ),
      color: Color(json['color'] as int),
      size: (json['size'] as num).toDouble(),
      points: (json['points'] as List<dynamic>)
          .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      symbolType: json['symbolType'] as String?,
      labelText: json['labelText'] as String?,
    );
  }
}

class PaperSheetDrawingData {
  final String id;
  final String encounterId;
  final String patientId;
  final List<VectorStroke> strokes;
  final String updatedAt;

  PaperSheetDrawingData({
    required this.id,
    required this.encounterId,
    required this.patientId,
    required this.strokes,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encounterId': encounterId,
      'patientId': patientId,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'updatedAt': updatedAt,
    };
  }

  /// Compact binary form stored in Firestore (see [DrawingCodec]).
  Uint8List toPacked() => DrawingCodec.pack(
        PackedDrawing(meta: [updatedAt], strokes: _toPacked(strokes)),
        maxBytes: AppLimits.maxPaperSheetDrawingBytes,
      );

  factory PaperSheetDrawingData.fromPacked(
    Uint8List data, {
    required String encounterId,
    required String patientId,
  }) {
    final d = DrawingCodec.unpack(data);
    return PaperSheetDrawingData(
      id: 'drw-$encounterId',
      encounterId: encounterId,
      patientId: patientId,
      strokes: _fromPacked(d.strokes, 'stk'),
      updatedAt: d.meta.isNotEmpty ? d.meta[0] : DateTime.now().toIso8601String(),
    );
  }

  factory PaperSheetDrawingData.fromJson(Map<String, dynamic> json) {
    return PaperSheetDrawingData(
      id: json['id'] as String,
      encounterId: json['encounterId'] as String,
      patientId: json['patientId'] as String,
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => VectorStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class EyeDrawingData {
  final String id;
  final String encounterId;
  final String patientId;
  final EyeType eye;
  final String diagramType; // 'fundus' or 'anterior'
  final List<VectorStroke> strokes;
  final double cdRatio; // Cup-to-Disc ratio 0.1 - 0.9
  final String updatedAt;

  EyeDrawingData({
    required this.id,
    required this.encounterId,
    required this.patientId,
    required this.eye,
    this.diagramType = 'fundus',
    required this.strokes,
    this.cdRatio = 0.5,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encounterId': encounterId,
      'patientId': patientId,
      'eye': eye.name,
      'diagramType': diagramType,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'cdRatio': cdRatio,
      'updatedAt': updatedAt,
    };
  }

  /// Compact binary form stored in Firestore (see [DrawingCodec]).
  Uint8List toPacked() => DrawingCodec.pack(
        PackedDrawing(
          aux: (cdRatio * 100).round(),
          meta: [diagramType, updatedAt],
          strokes: _toPacked(strokes),
        ),
        maxBytes: AppLimits.maxEyeDrawingBytes,
      );

  factory EyeDrawingData.fromPacked(
    Uint8List data, {
    required String encounterId,
    required String patientId,
    required EyeType eye,
  }) {
    final d = DrawingCodec.unpack(data);
    return EyeDrawingData(
      id: 'drw-$encounterId-${eye.name}',
      encounterId: encounterId,
      patientId: patientId,
      eye: eye,
      diagramType: d.meta.isNotEmpty ? d.meta[0] : 'fundus',
      strokes: _fromPacked(d.strokes, 'stk'),
      cdRatio: d.aux / 100.0,
      updatedAt: d.meta.length > 1 ? d.meta[1] : DateTime.now().toIso8601String(),
    );
  }

  factory EyeDrawingData.fromJson(Map<String, dynamic> json) {
    return EyeDrawingData(
      id: json['id'] as String,
      encounterId: json['encounterId'] as String,
      patientId: json['patientId'] as String,
      eye: EyeType.values.firstWhere(
        (e) => e.name == json['eye'],
        orElse: () => EyeType.OD,
      ),
      diagramType: json['diagramType'] as String? ?? 'fundus',
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => VectorStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      cdRatio: (json['cdRatio'] as num?)?.toDouble() ?? 0.5,
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
