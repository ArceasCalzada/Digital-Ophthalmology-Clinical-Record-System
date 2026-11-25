import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'firebase_gate.dart';

/// Manages and persists clinical examination and patient navigation preferences.
///
/// Stores preferences locally in [SharedPreferences] and synchronizes with
/// Firestore under `users/{uid}/settings/examination`.
class ExaminationPreferencesStore extends ChangeNotifier {
  static final ExaminationPreferencesStore instance = ExaminationPreferencesStore._();

  ExaminationPreferencesStore._() {
    _init();
  }

  static const String _prefsKeyPrefix = 'examination_preferences_';

  // Constants for preference values
  static const String layoutStandard2Column = 'Standard 2-Column';
  static const String layoutExpandedSingleCanvas = 'Expanded Single Canvas';
  static const String layoutClinicalTabbed = 'Clinical Tabbed';

  static const String templateFundus = 'Fundus / Retina Map';
  static const String templateAnterior = 'Anterior Segment / Cornea';
  static const String templateExternal = 'External Eye & Lids';

  static const String viewEhrProfile = 'Patient EHR Profile';
  static const String viewNewExam = 'New Eye Exam Workstation';
  static const String viewEncountersTimeline = 'Past Encounters Timeline';
  static const String viewPrescriptions = 'Prescriptions';

  String _defaultExamLayout = layoutStandard2Column;
  String _defaultDrawingTemplate = templateFundus;
  String _defaultPatientView = viewEhrProfile;

  String get defaultExamLayout => _defaultExamLayout;
  String get defaultDrawingTemplate => _defaultDrawingTemplate;
  String get defaultPatientView => _defaultPatientView;

  /// Helper converting the human-readable template to diagram type identifier.
  String get templateDiagramType {
    switch (_defaultDrawingTemplate) {
      case templateAnterior:
        return 'anterior';
      case templateExternal:
        return 'plain';
      case templateFundus:
      default:
        return 'fundus';
    }
  }

  void _init() {
    loadLocal();
  }

  Map<String, dynamic> toMap() => {
        'defaultExamLayout': _defaultExamLayout,
        'defaultDrawingTemplate': _defaultDrawingTemplate,
        'defaultPatientView': _defaultPatientView,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  void _applyMap(Map<String, dynamic> data) {
    if (data.containsKey('defaultExamLayout') && data['defaultExamLayout'] is String) {
      _defaultExamLayout = data['defaultExamLayout'] as String;
    }
    if (data.containsKey('defaultDrawingTemplate') && data['defaultDrawingTemplate'] is String) {
      _defaultDrawingTemplate = data['defaultDrawingTemplate'] as String;
    }
    if (data.containsKey('defaultPatientView') && data['defaultPatientView'] is String) {
      _defaultPatientView = data['defaultPatientView'] as String;
    }
  }

  /// Loads preferences from [SharedPreferences] for the given [uid] or current user.
  Future<void> loadLocal([String? uid]) async {
    try {
      final effectiveUid = uid ?? AuthService.instance.user?.uid;
      final prefs = await SharedPreferences.getInstance();
      final key = (effectiveUid != null && effectiveUid.isNotEmpty)
          ? '$_prefsKeyPrefix$effectiveUid'
          : 'examination_preferences_default';
      final raw = prefs.getString(key) ?? prefs.getString('examination_preferences_default');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _applyMap(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ExaminationPreferencesStore loadLocal notice: $e');
    }
  }

  /// Persists current preferences to [SharedPreferences].
  Future<void> saveLocal([String? uid]) async {
    try {
      final effectiveUid = uid ?? AuthService.instance.user?.uid;
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(toMap());
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        await prefs.setString('$_prefsKeyPrefix$effectiveUid', raw);
      }
      await prefs.setString('examination_preferences_default', raw);
    } catch (e) {
      debugPrint('ExaminationPreferencesStore saveLocal notice: $e');
    }
  }

  /// Loads preferences from Firestore under `users/{uid}/settings/examination`.
  Future<void> loadFromFirestore([String? uid]) async {
    final effectiveUid = uid ?? AuthService.instance.user?.uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      await loadLocal();
      return;
    }
    await loadLocal(effectiveUid);
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    try {
      final doc = await firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('settings')
          .doc('examination')
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        _applyMap(doc.data()!);
        await saveLocal(effectiveUid);
        notifyListeners();
      } else {
        // Document does not exist yet; sync current local preferences
        await saveToFirestore(effectiveUid);
      }
    } catch (e) {
      debugPrint('ExaminationPreferencesStore loadFromFirestore notice: $e');
    }
  }

  /// Synchronizes current preferences to Firestore under `users/{uid}/settings/examination`.
  Future<void> saveToFirestore([String? uid]) async {
    final effectiveUid = uid ?? AuthService.instance.user?.uid;
    await saveLocal(effectiveUid);
    if (effectiveUid == null || effectiveUid.isEmpty) return;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    try {
      final data = FirebaseGate.encode(toMap());
      await firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('settings')
          .doc('examination')
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('ExaminationPreferencesStore saveToFirestore notice: $e');
    }
  }

  /// Updates examination preferences and saves to both local storage and Firestore.
  Future<void> updatePreferences({
    String? examLayout,
    String? drawingTemplate,
    String? patientView,
    String? uid,
  }) async {
    var changed = false;
    if (examLayout != null && examLayout != _defaultExamLayout) {
      _defaultExamLayout = examLayout;
      changed = true;
    }
    if (drawingTemplate != null && drawingTemplate != _defaultDrawingTemplate) {
      _defaultDrawingTemplate = drawingTemplate;
      changed = true;
    }
    if (patientView != null && patientView != _defaultPatientView) {
      _defaultPatientView = patientView;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }

    final effectiveUid = uid ?? AuthService.instance.user?.uid;
    await saveLocal(effectiveUid);
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      await saveToFirestore(effectiveUid);
    }
  }

  /// Updates preferences from an external map (e.g. testing).
  void fromMap(Map<String, dynamic> data) {
    _applyMap(data);
    notifyListeners();
  }

  /// Resets preferences to initial clinical defaults.
  void reset() {
    _defaultExamLayout = layoutStandard2Column;
    _defaultDrawingTemplate = templateFundus;
    _defaultPatientView = viewEhrProfile;
    notifyListeners();
  }
}

