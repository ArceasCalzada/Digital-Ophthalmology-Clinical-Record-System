import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plan_limits.dart';
import '../models/clinic.dart';

/// Thrown by [ClinicStore.joinWithCode] while joining a shared clinic is not
/// available (it needs the cloud service, which is not switched on yet).
class CloudUnavailableException implements Exception {
  const CloudUnavailableException();

  @override
  String toString() => 'Joining a shared clinic needs the cloud service, which is not switched on yet.';
}

/// The clinics the signed-in account leads or belongs to, and the one being worked in.
///
/// An account starts with no clinic; the first is created when it first saves
/// something (see `ensureClinic`). Only clinic names and roles are stored on the device (per account, in ordinary
/// key/value storage). Patient records are never kept there.
///
/// NOTE: switching the active clinic changes the name and role shown in the app;
/// separating each clinic's patient records is the next step (encrypted per-clinic
/// storage), so today every clinic still shows the same patient list.
class ClinicStore extends ChangeNotifier {
  static final ClinicStore instance = ClinicStore._();
  ClinicStore._();

  static const maxNameLength = 60;

  String? _uid;
  bool _loading = false;
  List<Clinic> _clinics = [];
  String? _activeId;

  bool get loading => _loading;
  List<Clinic> get clinics => List.unmodifiable(_clinics);

  Clinic? get active {
    for (final c in _clinics) {
      if (c.id == _activeId) return c;
    }
    return _clinics.isEmpty ? null : _clinics.first;
  }

  /// Clinics this account created (the ones that count toward the plan limit).
  int get createdCount => _clinics.where((c) => c.role == ClinicRole.leader).length;

  bool get canCreateClinic => createdCount < PlanLimits.current.maxClinics;

  String _key(String uid) => 'clinics.v1.$uid';

  /// Reads this account's clinics. Call after sign-in.
  Future<void> load(String uid) async {
    _uid = uid;
    _loading = true;
    notifyListeners();
    var clinics = <Clinic>[];
    String? activeId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid));
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map) {
          clinics = [
            for (final item in (data['clinics'] as List? ?? const [])) ?Clinic.fromJson(item),
          ];
          activeId = data['active'] as String?;
        }
      }
    } catch (e) {
      debugPrint('ClinicStore load skipped: $e');
    }
    if (_uid != uid) return; // signed out or switched account while reading
    _clinics = clinics;
    _activeId = activeId;
    _loading = false;
    notifyListeners();
  }

  /// Forgets everything held in memory (sign-out). Saved names stay on the device.
  void unload() {
    _uid = null;
    _loading = false;
    _clinics = [];
    _activeId = null;
    notifyListeners();
  }

  /// The problem with [name] as a clinic name, or null when it is fine.
  static String? nameProblem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a name';
    if (trimmed.length > maxNameLength) return 'Use $maxNameLength characters or fewer';
    return null;
  }

  /// Creates a clinic led by this account and makes it the active one.
  /// Throws [PlanLimitException] when the plan's clinic limit is reached and
  /// [FormatException] for a bad name.
  Future<Clinic> createClinic(String name) async {
    final problem = nameProblem(name);
    if (problem != null) throw FormatException(problem);
    if (!canCreateClinic) throw PlanLimitException(PlanLimit.clinics, PlanLimits.current.maxClinics);
    final clinic = Clinic(id: _newId(), name: name.trim(), role: ClinicRole.leader);
    _clinics = [..._clinics, clinic];
    _activeId = clinic.id;
    notifyListeners();
    await _persist();
    return clinic;
  }

  Future<void> switchTo(String clinicId) async {
    if (_activeId == clinicId || !_clinics.any((c) => c.id == clinicId)) return;
    _activeId = clinicId;
    notifyListeners();
    await _persist();
  }

  /// Joins a clinic someone shared. Not available until the cloud service is on.
  Future<void> joinWithCode(String code) async => throw const CloudUnavailableException();

  Future<void> _persist() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(uid),
        jsonEncode({'clinics': [for (final c in _clinics) c.toJson()], 'active': _activeId}),
      );
    } catch (e) {
      debugPrint('ClinicStore save skipped: $e');
    }
  }

  static String _newId() {
    final rng = Random.secure();
    final suffix = List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
    return 'c-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  @visibleForTesting
  void resetForTesting() {
    unload();
  }
}
