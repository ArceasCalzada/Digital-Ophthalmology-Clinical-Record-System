import 'package:flutter/material.dart';
import 'eye_exam.dart';

enum DrawingTool { pen, eraser, symbol, text }

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
