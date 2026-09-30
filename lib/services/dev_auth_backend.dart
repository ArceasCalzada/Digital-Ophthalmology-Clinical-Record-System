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
  Future<AuthUser> signUp(String email, String password, String fullName) async {
    _current = AuthUser('dev-user', email, displayName: fullName, isEmailVerified: true);
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
  Future<UserRole?> fetchRole(String uid) async => UserRole.admin;
}
