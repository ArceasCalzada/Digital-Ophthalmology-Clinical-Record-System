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

  @override
  Future<AuthUser> signIn(String email, String password, {required bool remember}) async {
    final account = accounts[email];
    if (account == null || account.password != password) {
      throw const AuthFailure('Incorrect email or password.');
    }
    _current = AuthUser('uid-$email', email);
    _changes.add(_current);
    return _current!;
  }

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
