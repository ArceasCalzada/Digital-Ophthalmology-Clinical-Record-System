import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Access point for Firestore that is safe to call when Firebase is not set up
/// (unit tests, or a build without a Firebase project). Returns null instead of
/// throwing, and the app falls back to in-memory, local-only behaviour.
class FirebaseGate {
  FirebaseGate._();

  static FirebaseFirestore? firestoreIfReady() {
    try {
      if (Firebase.apps.isEmpty) return null;
      if (Firebase.app().options.apiKey.contains('Placeholder')) return null;
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Converts Firestore-specific values into plain Dart values: [Blob] becomes
  /// [Uint8List] and [Timestamp] becomes an ISO-8601 string.
  static Map<String, dynamic> decode(Map<String, dynamic> data) {
    dynamic convert(dynamic v) {
      if (v is Blob) return Uint8List.fromList(v.bytes);
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is Map) return {for (final e in v.entries) e.key.toString(): convert(e.value)};
      if (v is List) return [for (final e in v) convert(e)];
      return v;
    }

    return convert(data) as Map<String, dynamic>;
  }

  /// Converts plain values into Firestore types: [Uint8List] becomes [Blob].
  static Map<String, dynamic> encode(Map<String, dynamic> data) {
    dynamic convert(dynamic v) {
      if (v is Uint8List) return Blob(v);
      if (v is Map) return {for (final e in v.entries) e.key.toString(): convert(e.value)};
      if (v is List) return [for (final e in v) convert(e)];
      return v;
    }

    return convert(data) as Map<String, dynamic>;
  }
}
