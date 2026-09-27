import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class StorageOptimizationService {
  static const int maxDocumentSizeBytes = 1048576; // 1 MB Firestore limit
  static const int maxInlineBlobBytes = 51200; // 50 KB max inline string limit

  /// Validates that a database payload does not exceed recommended size limits
  /// and does not contain raw base64 images or heavy binary strings.
  static Map<String, dynamic> auditAndOptimizePayload(Map<String, dynamic> payload) {
    final optimized = Map<String, dynamic>.from(payload);

    payload.forEach((key, value) {
      if (value is String) {
        // Detect raw base64 data URIs or heavy inline binary strings
        if (value.startsWith('data:image/') || (value.length > maxInlineBlobBytes && isBase64(value))) {
          debugPrint('Storage Warning: Heavy inline data found in field "$key". Use Firebase Storage bucket URL instead.');
          throw FormatException(
            'Field "$key" contains inline binary data (${(value.length / 1024).toStringAsFixed(1)} KB). Heavy files must be uploaded to Cloud Storage bucket with reference URLs saved to database.',
          );
        }
      }
    });

    return optimized;
  }

  /// Checks if a string is valid base64 encoded binary data
  static bool isBase64(String str) {
    if (str.length % 4 != 0) return false;
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    return base64Regex.hasMatch(str);
  }

  /// Compresses a large string payload using GZip compression for storage efficiency
  static String compressPayload(String input) {
    final bytes = utf8.encode(input);
    final compressed = gzip.encode(bytes);
    return base64Encode(compressed);
  }

  /// Decompresses a GZip compressed storage payload
  static String decompressPayload(String compressedBase64) {
    final compressedBytes = base64Decode(compressedBase64);
    final decompressedBytes = gzip.decode(compressedBytes);
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
