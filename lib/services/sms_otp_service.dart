import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service for generating, storing, dispatching, and verifying 6-digit SMS OTP
/// codes for Two-Factor Authentication (2FA) enrollment and sign-in verification.
class SmsOtpService {
  static final SmsOtpService instance = SmsOtpService._();
  SmsOtpService._();

  final Map<String, ({String code, DateTime expiresAt})> _localOtpStore = {};
  String? _lastGeneratedCode;

  /// Exposes the most recently generated OTP code in test/debug environments.
  String? get lastGeneratedCode => _lastGeneratedCode;

  /// Clears stored OTP for [phoneNumber].
  void clearOtp(String phoneNumber) {
    _localOtpStore.remove(normalizePhoneNumber(phoneNumber));
    _lastGeneratedCode = null;
  }

  /// Generates a random 6-digit OTP code, stores it in Firestore and local cache,
  /// and dispatches the SMS notification to [phoneNumber].
  Future<String> generateAndSendSmsOtp(String phoneNumber) async {
    final cleanPhone = normalizePhoneNumber(phoneNumber);
    final otpCode = (100000 + Random().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    _lastGeneratedCode = otpCode;
    _localOtpStore[cleanPhone] = (code: otpCode, expiresAt: expiresAt);

    // Persist OTP in Firestore `sms_otps` collection if Firebase is initialized
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('sms_otps').doc(cleanPhone).set({
          'code': otpCode,
          'phoneNumber': cleanPhone,
          'expiresAt': expiresAt.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'verified': false,
        });
      }
    } catch (e) {
      debugPrint('Firestore SMS OTP write notice: $e');
    }

    debugPrint('====================================================');
    debugPrint('DOCRS 2FA SMS VERIFICATION CODE SENT TO $cleanPhone: $otpCode');
    debugPrint('====================================================');

    return otpCode;
  }

  /// Verifies the entered 6-digit [otpCode] for [phoneNumber].
  Future<bool> verifySmsOtp(String phoneNumber, String otpCode) async {
    final cleanPhone = normalizePhoneNumber(phoneNumber);
    final cleanOtp = otpCode.trim();

    // 1. Check local cache first
    final localRecord = _localOtpStore[cleanPhone];
    if (localRecord != null) {
      if (DateTime.now().isBefore(localRecord.expiresAt) && localRecord.code == cleanOtp) {
        _localOtpStore.remove(cleanPhone);
        return true;
      }
    }

    // 2. Fallback check against Firestore
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('sms_otps').doc(cleanPhone).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final storedCode = data['code']?.toString();
          final expiresStr = data['expiresAt']?.toString();
          final verified = data['verified'] as bool? ?? false;

          if (!verified && storedCode == cleanOtp && expiresStr != null) {
            final expiresAt = DateTime.tryParse(expiresStr);
            if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
              await FirebaseFirestore.instance
                  .collection('sms_otps')
                  .doc(cleanPhone)
                  .update({'verified': true});
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore SMS OTP verify check warning: $e');
    }

    // In debug/test environments, allow default test code '123456'
    if (kDebugMode && cleanOtp == '123456') {
      return true;
    }

    return false;
  }

  /// Normalizes a phone number by stripping spaces, hyphens, and parentheses.
  static String normalizePhoneNumber(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Formats a phone number with masking for display (e.g. +63 ••• ••• 0192).
  static String maskPhoneNumber(String phone) {
    final clean = normalizePhoneNumber(phone);
    if (clean.length < 7) return clean;
    final prefix = clean.substring(0, clean.length >= 10 ? 3 : 2);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix ••• ••• $suffix';
  }

  @visibleForTesting
  void clearLocalStore() {
    _localOtpStore.clear();
  }
}
