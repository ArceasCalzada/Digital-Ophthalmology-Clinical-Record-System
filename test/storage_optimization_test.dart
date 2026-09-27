import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/storage_optimization_service.dart';

void main() {
  group('Database Storage Optimization & Future Data Policy Tests', () {
    test('Payload audit permits normal clinical data payloads', () {
      final validPayload = {
        'id': 'pat-101',
        'fullName': 'Maria Santos',
        'age': 45,
        'iopOD': 14.5,
        'iopOS': 15.0,
        'lastVisit': '2026-09-27T10:00:00.000Z',
      };

      final result = StorageOptimizationService.auditAndOptimizePayload(validPayload);
      expect(result['fullName'], equals('Maria Santos'));
      expect(result['iopOD'], equals(14.5));
    });

    test('Payload audit rejects heavy inline base64 image strings', () {
      // Base64 string exceeding 50KB limit
      final heavyBase64Image = 'data:image/png;base64,${'A' * 60000}';

      final invalidPayload = {
        'id': 'pat-102',
        'fundusImage': heavyBase64Image,
      };

      expect(
        () => StorageOptimizationService.auditAndOptimizePayload(invalidPayload),
        throwsA(isA<FormatException>()),
      );
    });

    test('Payload compression and decompression works accurately', () {
      const originalText = 'Detailed clinical assessment: Patient presents with nuclear sclerotic cataract Grade 2+ in Right Eye (OD). Recommending Phacoemulsification with intraocular lens implantation.';
      
      final compressed = StorageOptimizationService.compressPayload(originalText);
      expect(compressed, isNotEmpty);
      expect(compressed, isNot(equals(originalText)));

      final decompressed = StorageOptimizationService.decompressPayload(compressed);
      expect(decompressed, equals(originalText));
    });

    test('Archiving strategy correctly identifies stale encounters older than 3 years', () {
      final encounters = [
        {'id': 'enc-recent', 'date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String()},
        {'id': 'enc-1yr', 'date': DateTime.now().subtract(const Duration(days: 365)).toIso8601String()},
        {'id': 'enc-4yr', 'date': DateTime.now().subtract(const Duration(days: 365 * 4)).toIso8601String()},
        {'id': 'enc-5yr', 'date': DateTime.now().subtract(const Duration(days: 365 * 5)).toIso8601String()},
      ];

      final archived = StorageOptimizationService.filterEncountersForArchiving(encounters, archiveAgeYears: 3);
      expect(archived.length, equals(2));
      expect(archived.any((e) => e['id'] == 'enc-4yr'), isTrue);
      expect(archived.any((e) => e['id'] == 'enc-5yr'), isTrue);
      expect(archived.any((e) => e['id'] == 'enc-recent'), isFalse);
    });

    test('Vector vs Raster savings calculation demonstrates >99% storage reduction', () {
      final savings = StorageOptimizationService.calculateVectorVsRasterSavings(
        totalStrokes: 10,
        totalPoints: 200,
      );

      expect(savings['vectorSizeBytes'], equals(10000));
      expect(savings['rasterSizeBytes'], equals(1572864));
      expect(double.parse(savings['savingsPercent'] as String), greaterThan(99.0));
    });
  });
}
