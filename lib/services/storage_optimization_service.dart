import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class StorageOptimizationService {
  static const int maxDocumentSizeBytes = 1048576; // 1 MB Firestore limit
  static const int maxInlineBlobBytes = 51200; // 50 KB max inline string limit

  /// Validates that a database payload does not exceed recommended size limits
  /// and does not contain raw base64 images or heavy binary strings.
  ///
  /// Nested maps and lists are checked too. When [maxDocBytes] is given, the
  /// Firestore stored size of the document (using [estimateDocumentBytes]) must
  /// fit within it. Throws [FormatException] on violation.
  static Map<String, dynamic> auditAndOptimizePayload(
    Map<String, dynamic> payload, {
    int? maxDocBytes,
    String docPath = 'collection/doc',
  }) {
    final optimized = Map<String, dynamic>.from(payload);

    void check(String path, dynamic value) {
      if (value is String) {
        // Detect raw base64 data URIs or heavy inline binary strings
        if (value.startsWith('data:image/') || (value.length > maxInlineBlobBytes && isBase64(value))) {
          debugPrint('Storage Warning: Heavy inline data found in field "$path". Use Firebase Storage bucket URL instead.');
          throw FormatException(
            'Field "$path" contains inline binary data (${(value.length / 1024).toStringAsFixed(1)} KB). Heavy files must be uploaded to Cloud Storage bucket with reference URLs saved to database.',
          );
        }
      } else if (value is Map) {
        value.forEach((k, v) => check('$path.$k', v));
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          check('$path[$i]', value[i]);
        }
      }
    }

    payload.forEach(check);

    if (maxDocBytes != null) {
      final size = estimateDocumentBytes(docPath, payload);
      if (size > maxDocBytes) {
        throw FormatException(
          'Document "$docPath" is ${(size / 1024).toStringAsFixed(1)} KB, over the ${(maxDocBytes / 1024).toStringAsFixed(0)} KB limit.',
        );
      }
    }

    return optimized;
  }

  /// Estimates the Firestore stored size of a document, following the documented
  /// formula: name (path segments + 16) + fields + 32 bytes of overhead. Strings
  /// count UTF-8 length + 1, numbers 8, booleans/nulls 1, bytes their length.
  static int estimateDocumentBytes(String docPath, Map<String, dynamic> data) {
    var nameBytes = 16;
    for (final segment in docPath.split('/')) {
      nameBytes += _stringBytes(segment);
    }
    return nameBytes + _valueBytes(data) + 32;
  }

  static int _stringBytes(String s) => utf8.encode(s).length + 1;

  static int _valueBytes(dynamic v) {
    if (v == null || v is bool) return 1;
    if (v is num) return 8;
    if (v is String) return _stringBytes(v);
    if (v is Uint8List) return v.length;
    if (v is DateTime) return 8;
    if (v is List) return v.fold<int>(0, (sum, e) => sum + _valueBytes(e));
    if (v is Map) {
      return v.entries.fold<int>(0, (sum, e) => sum + _stringBytes(e.key.toString()) + _valueBytes(e.value));
    }
    throw FormatException('Unsupported value type ${v.runtimeType} in Firestore payload.');
  }

  /// Checks if a string is valid base64 encoded binary data
  static bool isBase64(String str) {
    if (str.length % 4 != 0) return false;
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    return base64Regex.hasMatch(str);
  }

  /// Compresses a large string payload using GZip compression for storage efficiency
  /// (uses `package:archive`, so it also works on web).
  static String compressPayload(String input) {
    final bytes = utf8.encode(input);
    final compressed = GZipEncoder().encodeBytes(bytes);
    return base64Encode(compressed);
  }

  /// Decompresses a GZip compressed storage payload
  static String decompressPayload(String compressedBase64) {
    final compressedBytes = base64Decode(compressedBase64);
    final decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
    return utf8.decode(decompressedBytes);
  }

  /// Filters historical encounters for archiving strategy (e.g. encounters older than 3 years)
  static List<Map<String, dynamic>> filterEncountersForArchiving(
    List<Map<String, dynamic>> encounters, {
    int archiveAgeYears = 3,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: archiveAgeYears * 365));
    return encounters.where((e) {
      final dateStr = e['date'] ?? e['timestamp'] ?? '';
      final dt = DateTime.tryParse(dateStr.toString());
      if (dt == null) return false;
      return dt.isBefore(cutoff);
    }).toList();
  }

  /// Estimates memory size savings of vector strokes vs raster PNG images
  static Map<String, dynamic> calculateVectorVsRasterSavings({
    required int totalStrokes,
    required int totalPoints,
  }) {
    // Average vector stroke serialization footprint ~50 bytes per point
    final vectorSizeBytes = totalPoints * 50;
    // Average high-res raster PNG chart ~1.5 MB (1,572,864 bytes)
    const averageRasterSizeBytes = 1572864;

    final savingsBytes = averageRasterSizeBytes - vectorSizeBytes;
    final savingsPercent = (savingsBytes / averageRasterSizeBytes) * 100;

    return {
      'vectorSizeBytes': vectorSizeBytes,
      'rasterSizeBytes': averageRasterSizeBytes,
      'savingsBytes': savingsBytes > 0 ? savingsBytes : 0,
      'savingsPercent': savingsPercent.clamp(0.0, 99.9).toStringAsFixed(1),
    };
  }
}
