import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Identity provider for working on the UI without a Firebase project or data.
///
/// The app starts signed in as an admin, and any email/password signs back in
/// after a sign-out. It never contacts Firebase: [main] skips Firebase setup in
/// this mode, so patients live in memory only and vanish on reload.
class DevAuthBackend implements AuthBackend {
  static const _user = AuthUser('dev-user', 'dev@docrs.local');

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current = _user;

  /// True only when built with `--dart-define=DOCRS_UI_DEV=true`, and then only
  /// on localhost (web) or in a debug build (other platforms). A build with the
  /// flag that is deployed by mistake therefore still shows the normal login.
  static bool isEnabled({required bool flag, required bool isWeb, required String webHost, bool isRelease = kReleaseMode}) {
    if (!flag) return false;
    if (isWeb) return webHost == 'localhost' || webHost == '127.0.0.1';
    return !isRelease;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn(String email, String password, {required bool remember}) async {
    _current = AuthUser('dev-user', email.isEmpty ? _user.email : email, isEmailVerified: true);
    _changes.add(_current);
    return _current!;
  }

  @override
  Future<AuthUser> signUp(
    String email,
    String password,
    String fullName, {
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    String requestedRole = 'assistant',
    String? inviteCode,
    String? workspaceId,
  }) async {
    _current = AuthUser(
      'dev-user',
      email,
      displayName: fullName,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      suffix: suffix,
      isEmailVerified: true,
    );
    _changes.add(_current);
    return _current!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<String> sendEmailOtp(String email) async => '123456';

  @override
  Future<bool> verifyEmailOtp(String email, String otp) async => otp.trim() == '123456';

  @override
  Future<AuthUser?> reloadUser() async => _current;

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}

  @override
  Future<bool> verifyPassword(String email, String password) async => true;

  bool _twoFactorEnabled = false;
  String? _twoFactorPhone;

  @override
  Future<bool> fetchTwoFactorEnabled(String uid) async => _twoFactorEnabled;

  @override
  Future<String?> fetchTwoFactorPhone(String uid) async => _twoFactorPhone ?? '+639175550192';

  @override
  Future<String> startTwoFactorEnrollment(String phoneNumber) async {
    _twoFactorPhone = phoneNumber;
    return 'dev-verification-id';
  }

  @override
  Future<void> finalizeTwoFactorEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    _twoFactorEnabled = true;
    _twoFactorPhone = phoneNumber;
  }

  @override
  Future<void> unenrollTwoFactor() async {
    _twoFactorEnabled = false;
    _twoFactorPhone = null;
  }

  @override
  Future<UserRole?> fetchRole(String uid) async => UserRole.admin;

  @override
  Future<void> assignRole(String uid, UserRole role) async {}

  @override
  Future<void> updateProfileNames({
    required String uid,
    required String displayName,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
  }) async {
    final current = _current;
    if (current != null) {
      _current = AuthUser(
        current.uid,
        current.email,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        middleName: middleName,
        suffix: suffix,
        isEmailVerified: true,
      );
      _changes.add(_current);
    }
  }
}
