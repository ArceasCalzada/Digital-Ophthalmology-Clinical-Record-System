import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Roles stored in `users/{uid}.role`. Admins can also delete patient records.
enum UserRole { admin, physician, staff }

UserRole? parseUserRole(Object? raw) {
  switch (raw) {
    case 'admin':
      return UserRole.admin;
    case 'physician':
      return UserRole.physician;
    case 'staff':
      return UserRole.staff;
    default:
      return null;
  }
}

class AuthUser {
  final String uid;
  final String? email;
  const AuthUser(this.uid, this.email);
}

/// Thrown by [AuthService.signIn] with a message that is safe to show the user.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// The identity provider. Production uses [FirebaseAuthBackend]; tests inject a fake.
abstract class AuthBackend {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Future<AuthUser> signIn(String email, String password, {required bool remember});
  Future<void> signOut();

  /// Reads `users/{uid}.role`. Null means the account is not authorised for DOCRS.
  Future<UserRole?> fetchRole(String uid);
}

class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  AuthUser? _map(User? u) => u == null ? null : AuthUser(u.uid, u.email);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  Future<AuthUser> signIn(String email, String password, {required bool remember}) async {
    try {
      if (kIsWeb) {
        // "Remember" keeps the session across browser restarts; otherwise it ends
        // when the tab closes (better for shared clinic PCs).
        await _auth.setPersistence(remember ? Persistence.LOCAL : Persistence.SESSION);
      }
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) throw const AuthFailure('Sign-in failed. Please try again.');
      return AuthUser(user.uid, user.email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        // One message for all of these so the form does not reveal which accounts exist.
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your clinic administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Cannot reach the server. Check your internet connection.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<UserRole?> fetchRole(String uid) async {
    // Bounded so a dead connection shows the login screen instead of a blank app.
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 15));
    return parseUserRole(doc.data()?['role']);
  }
}

/// Signed-in state for the whole app.
///
/// A user only counts as signed in ([isSignedIn]) once their account has a role
/// in `users/{uid}`. Firestore rules apply the same check, so an authenticated
/// but unlisted account can neither open the app nor read any data.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  /// How long the app may sit untouched before signing the user out.
  static const Duration idleTimeout = Duration(minutes: 30);

  AuthBackend? _backend;
  StreamSubscription<AuthUser?>? _sub;
  AuthUser? _user;
  UserRole? _role;
  bool _resolving = false;

  bool get isAvailable => _backend != null;
  AuthUser? get user => _user;
  UserRole? get role => _role;
  String? get email => _user?.email;
  bool get isSignedIn => _user != null && _role != null;
  bool get isResolving => _resolving;
  bool get canWriteClinical => _role == UserRole.admin || _role == UserRole.physician;
  bool get canDelete => _role == UserRole.admin;

  /// Connects to Firebase Auth. Call once after `Firebase.initializeApp`.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) return;
      await attach(FirebaseAuthBackend());
    } catch (e) {
      debugPrint('AuthService init failed: $e');
    }
  }

  /// Uses [backend] as the identity provider (also the seam for tests).
  Future<void> attach(AuthBackend backend) async {
    await _sub?.cancel();
    _backend = backend;
    _user = null;
    _role = null;
    _sub = backend.userChanges.listen(_onUserChanged);
    await _onUserChanged(backend.currentUser);
  }

  Future<void>? _inFlight;
  String? _inFlightUid;

  Future<void> _onUserChanged(AuthUser? user) {
    if (user == null) {
      _user = null;
      _role = null;
      notifyListeners();
      return Future.value();
    }
    // signIn() and the auth stream both report the same user (often at the same
    // moment): resolve the role once and let both callers share the result.
    if (_user?.uid == user.uid && _role != null) return Future.value();
    if (_inFlight != null && _inFlightUid == user.uid) return _inFlight!;
    _inFlightUid = user.uid;
    return _inFlight = _resolve(user).whenComplete(() {
      _inFlight = null;
      _inFlightUid = null;
    });
  }

  Future<void> _resolve(AuthUser user) async {
    _resolving = true;
    notifyListeners();
    try {
      final role = await _backend!.fetchRole(user.uid);
      if (role == null) {
        // Real account but not on the clinic's list: refuse and sign back out.
        _user = null;
        _role = null;
        await _backend!.signOut();
      } else {
        _user = user;
        _role = role;
      }
    } catch (e) {
      debugPrint('AuthService could not read role: $e');
      _user = null;
      _role = null;
    } finally {
      _resolving = false;
      notifyListeners();
    }
  }

  /// Signs in with email and password. Throws [AuthFailure] with a user-safe message.
  Future<void> signIn(String email, String password, {bool remember = false}) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    final trimmed = email.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your email and password.');
    }
    final signedIn = await backend.signIn(trimmed, password, remember: remember);
    await _onUserChanged(signedIn);
    if (!isSignedIn) {
      throw const AuthFailure('This account is not authorised for DOCRS. Contact your clinic administrator.');
    }
  }

  Future<void> signOut() async {
    final backend = _backend;
    _user = null;
    _role = null;
    notifyListeners();
    try {
      await backend?.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    await _sub?.cancel();
    _sub = null;
    _backend = null;
    _user = null;
    _role = null;
    _resolving = false;
    _inFlight = null;
    _inFlightUid = null;
  }
}
