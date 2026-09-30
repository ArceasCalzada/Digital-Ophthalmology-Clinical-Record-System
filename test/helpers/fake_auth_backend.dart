import 'dart:async';

import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';

/// In-memory identity provider for tests. Accounts map email -> (password, role).
/// A null role models an account that exists in Firebase Auth but is not listed
/// in the clinic's `users` collection.
class FakeAuthBackend implements AuthBackend {
  final Map<String, ({String password, UserRole? role})> accounts;
  final StreamController<AuthUser?> _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int roleReads = 0;
  int signOutCalls = 0;

  FakeAuthBackend(this.accounts);

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  bool shouldRequireEmailVerification = false;
  int resetEmailCalls = 0;
  int verificationEmailCalls = 0;

  @override
  Future<AuthUser> signIn(String email, String password, {required bool remember}) async {
    final account = accounts[email];
    if (account == null || account.password != password) {
      throw const AuthFailure('Incorrect email or password.');
    }
    _current = AuthUser(
      'uid-$email',
      email,
      isEmailVerified: !shouldRequireEmailVerification,
    );
    _changes.add(_current);
    return _current!;
  }

  @override
  Future<AuthUser> signUp(String email, String password, String fullName) async {
    if (accounts.containsKey(email)) {
      throw const AuthFailure('An account with this email address already exists.');
    }
    accounts[email] = (password: password, role: null);
    _current = AuthUser(
      'uid-$email',
      email,
      displayName: fullName,
      isEmailVerified: !shouldRequireEmailVerification,
    );
    _changes.add(_current);
    return _current!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmailCalls++;
    if (!accounts.containsKey(email)) {
      throw const AuthFailure('No account found with this email address.');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailCalls++;
  }

  @override
  Future<AuthUser?> reloadUser() async => _current;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _changes.add(null);
  }

  @override
  Future<UserRole?> fetchRole(String uid) async {
    roleReads++;
    final email = uid.replaceFirst('uid-', '');
    return accounts[email]?.role;
  }
}
