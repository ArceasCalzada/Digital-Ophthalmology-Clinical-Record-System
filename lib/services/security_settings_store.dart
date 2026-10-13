import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'firebase_gate.dart';
import 'sms_otp_service.dart';

/// Store and manager for user security settings, session auto-lock, and 2FA.
///
/// Holds preferences locally in [SharedPreferences] and synchronizes with
/// Firestore under `users/{uid}/settings/security`.
class SecuritySettingsStore extends ChangeNotifier {
  static final SecuritySettingsStore instance = SecuritySettingsStore._();
  SecuritySettingsStore._() {
    _init();
  }

  static const String _prefsKeyPrefix = 'security_settings_';

  bool _autoLockEnabled = true;
  String _autoLockDuration = '15 minutes';
  bool _twoFactorEnabled = false;
  String? _twoFactorPhoneNumber;
  bool _isLocked = false;

  bool get autoLockEnabled => _autoLockEnabled;
  String get autoLockDuration => _autoLockDuration;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get twoFactorPhoneNumber => _twoFactorPhoneNumber;
  bool get isLocked => _isLocked;

  String get maskedPhoneNumber {
    if (_twoFactorPhoneNumber == null || _twoFactorPhoneNumber!.isEmpty) {
      return '+63 ••• ••• 0192';
    }
    return SmsOtpService.maskPhoneNumber(_twoFactorPhoneNumber!);
  }

  /// Exact [Duration] mapped from [_autoLockDuration] when auto-lock is enabled.
  Duration? get timeoutDuration {
    if (!_autoLockEnabled || _autoLockDuration == 'Never') return null;
    switch (_autoLockDuration) {
      case '5 minutes':
        return const Duration(minutes: 5);
      case '10 minutes':
        return const Duration(minutes: 10);
      case '15 minutes':
        return const Duration(minutes: 15);
      case '30 minutes':
        return const Duration(minutes: 30);
      case '1 hour':
        return const Duration(hours: 1);
      default:
        return const Duration(minutes: 15);
    }
  }

  void _init() {
    loadLocal();
  }

  Future<void> loadLocal([String? uid]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = uid != null ? '$_prefsKeyPrefix$uid' : 'security_settings_default';
      final raw = prefs.getString(key) ?? prefs.getString('security_settings_default');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _applyMap(data);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _applyMap(Map<String, dynamic> data) {
    if (data.containsKey('autoLockEnabled')) {
      _autoLockEnabled = data['autoLockEnabled'] as bool? ?? true;
    }
    if (data.containsKey('autoLockDuration')) {
      _autoLockDuration = data['autoLockDuration'] as String? ?? '15 minutes';
    }
    if (data.containsKey('twoFactorEnabled')) {
      _twoFactorEnabled = data['twoFactorEnabled'] as bool? ?? false;
    }
    if (data.containsKey('twoFactorPhoneNumber')) {
      _twoFactorPhoneNumber = data['twoFactorPhoneNumber'] as String?;
    }
  }

  Map<String, dynamic> toMap() => {
        'autoLockEnabled': _autoLockEnabled,
        'autoLockDuration': _autoLockDuration,
        'twoFactorEnabled': _twoFactorEnabled,
        'twoFactorPhoneNumber': _twoFactorPhoneNumber,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  Future<void> saveLocal([String? uid]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(toMap());
      if (uid != null) {
        await prefs.setString('$_prefsKeyPrefix$uid', raw);
      }
      await prefs.setString('security_settings_default', raw);
    } catch (_) {}
  }

  /// Loads security preferences from Firestore for [uid] and falls back to local cache.
  Future<void> loadFromFirestore(String uid) async {
    await loadLocal(uid);
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    try {
      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('security')
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        _applyMap(doc.data()!);
        await saveLocal(uid);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SecuritySettingsStore loadFromFirestore notice: $e');
    }
  }

  /// Persists current security preferences to Firestore for [uid].
  Future<void> saveToFirestore(String uid) async {
    await saveLocal(uid);
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    try {
      final data = FirebaseGate.encode(toMap());
      await firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('security')
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('SecuritySettingsStore saveToFirestore notice: $e');
    }
  }

  /// Updates Auto-Lock preference and saves to both local cache and Firestore.
  Future<void> updateAutoLock({
    required bool enabled,
    required String duration,
    String? uid,
  }) async {
    _autoLockEnabled = enabled;
    _autoLockDuration = duration;
    notifyListeners();
    await saveLocal(uid);
    if (uid != null && uid.isNotEmpty) {
      await saveToFirestore(uid);
    }
  }

  /// Updates Two-Factor Authentication state and saves to both local cache and Firestore.
  Future<void> updateTwoFactor({
    required bool enabled,
    String? phoneNumber,
    String? uid,
  }) async {
    _twoFactorEnabled = enabled;
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      _twoFactorPhoneNumber = phoneNumber.trim();
    } else if (!enabled) {
      _twoFactorPhoneNumber = null;
    }
    notifyListeners();
    await saveLocal(uid);
    if (uid != null && uid.isNotEmpty) {
      await saveToFirestore(uid);
    }
  }

  /// Triggers a workstation session lock screen.
  void lockScreen() {
    if (!_autoLockEnabled || _isLocked) return;
    _isLocked = true;
    notifyListeners();
  }

  /// Attempts to unlock the workstation by verifying [password].
  Future<bool> unlockSession(String password) async {
    final verified = await AuthService.instance.verifyCurrentPassword(password);
    if (verified) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Alias for lockScreen.
  void lock() => lockScreen();

  /// Alias for unlockSession.
  Future<bool> unlockWithPassword(String password) => unlockSession(password);

  /// Deserializes settings from a map and updates state.
  void fromMap(Map<String, dynamic> data) {
    _applyMap(data);
    notifyListeners();
  }

  /// Force unlock (e.g. for testing or sign-out).
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  /// Resets state on sign-out.
  void reset() {
    _isLocked = false;
    _autoLockEnabled = true;
    _autoLockDuration = '15 minutes';
    _twoFactorEnabled = false;
    _twoFactorPhoneNumber = null;
    notifyListeners();
  }
}
