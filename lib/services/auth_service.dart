import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'email_otp_service.dart';
import 'profile_store.dart';

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
  final String? displayName;
  final bool isEmailVerified;
  const AuthUser(
    this.uid,
    this.email, {
    this.displayName,
    this.isEmailVerified = true,
  });
}

/// Thrown by [AuthService] operations with a message that is safe to show the user.
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
  Future<AuthUser> signUp(String email, String password, String fullName);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<String> sendEmailOtp(String email);
  Future<bool> verifyEmailOtp(String email, String otp);
  Future<AuthUser?> reloadUser();
  Future<void> signOut();

  /// Reads `users/{uid}.role`. Null means the account is not authorised for DOCRS.
  Future<UserRole?> fetchRole(String uid);
}

class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          u.uid,
          u.email,
          displayName: u.displayName,
          isEmailVerified: u.emailVerified,
        );

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
      return _map(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<AuthUser> signUp(String email, String password, String fullName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) throw const AuthFailure('Registration failed. Please try again.');
      if (fullName.trim().isNotEmpty) {
        await user.updateDisplayName(fullName.trim());
      }
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase email verification link trigger failed: ${e.code} ${e.message}');
      } catch (e) {
        debugPrint('Firebase email verification link trigger failed: $e');
      }
      return AuthUser(
        user.uid,
        user.email,
        displayName: fullName.trim(),
        isEmailVerified: user.emailVerified,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthFailure('No active session found. Please sign in again.');
      }
      await u.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e.code));
    } catch (e) {
      throw AuthFailure('Failed to send verification email: $e');
    }
  }

  @override
  Future<String> sendEmailOtp(String email) async {
    return await EmailOtpService.instance.generateAndSendOtp(email);
  }

  @override
  Future<bool> verifyEmailOtp(String email, String otp) async {
    return await EmailOtpService.instance.verifyOtp(email, otp);
  }

  @override
  Future<AuthUser?> reloadUser() async {
    try {
      final u = _auth.currentUser;
      if (u != null) {
        await u.reload();
        return _map(_auth.currentUser);
      }
      return null;
    } catch (e) {
      return _map(_auth.currentUser);
    }
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your clinic administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Cannot reach the server. Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
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
/// A user only counts as signed in ([isSignedIn]) once their account has verified its
/// email AND has a role in `users/{uid}`. Firestore rules apply the same check.
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

  bool _otpVerifiedLocally = false;

  bool get isAvailable => _backend != null;
  AuthUser? get user => _user;
  UserRole? get role => _role;
  String? get email => _user?.email;
  bool get isEmailVerified => _otpVerifiedLocally || (_user?.isEmailVerified ?? true);
  bool get isPendingEmailVerification => _user != null && !isEmailVerified;
  bool get isPendingRole => _user != null && isEmailVerified && _role == null;
  bool get isSignedIn => _user != null && _role != null && isEmailVerified;
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
    _user = user;
    if (_user?.uid == user.uid && _role != null) {
      notifyListeners();
      return Future.value();
    }
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
      _user = user;
      ProfileStore.instance.syncWithUser(user);
      if (user.isEmailVerified) {
        _role = await _backend!.fetchRole(user.uid);
      } else {
        _role = null;
      }
    } catch (e) {
      debugPrint('AuthService could not read role: $e');
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
  }

  /// Registers a new account.
  Future<void> signUp(String email, String password, String fullName) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    final trimmedEmail = email.trim();
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('Please complete all required fields.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password is too weak. Please use at least 6 characters.');
    }
    final newUser = await backend.signUp(trimmedEmail, password, trimmedName);
    await _onUserChanged(newUser);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Please enter your email address.');
    }
    await backend.sendPasswordResetEmail(trimmed);
  }

  /// Generates and sends a 6-digit OTP code to [email].
  Future<String?> sendEmailOtp(String email) async {
    final backend = _backend;
    if (backend == null) return null;
    return await backend.sendEmailOtp(email);
  }

  /// Verifies the 6-digit [otp] code for [email].
  Future<void> verifyEmailOtp(String email, String otp) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available.');
    }
    final isValid = await backend.verifyEmailOtp(email, otp);
    if (!isValid) {
      throw const AuthFailure('Invalid 6-digit verification code. Please check and try again.');
    }
    _otpVerifiedLocally = true;
    if (_user != null) {
      _user = AuthUser(
        _user!.uid,
        _user!.email,
        displayName: _user!.displayName,
        isEmailVerified: true,
      );
      await _resolve(_user!);
    }
    notifyListeners();
  }

  /// Re-sends email verification message to current user.
  Future<void> sendEmailVerification() async {
    final backend = _backend;
    if (backend == null) return;
    await backend.sendEmailVerification();
  }

  /// Reloads user authentication state to check for verified status or updated role.
  Future<void> reloadUserAndCheckRole() async {
    final backend = _backend;
    if (backend == null) return;
    _resolving = true;
    notifyListeners();
    try {
      final reloaded = await backend.reloadUser();
      if (reloaded != null) {
        _user = reloaded;
        if (reloaded.isEmailVerified) {
          _role = await backend.fetchRole(reloaded.uid);
        }
      }
    } finally {
      _resolving = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final backend = _backend;
    _user = null;
    _role = null;
    _otpVerifiedLocally = false;
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
    _otpVerifiedLocally = false;
    _resolving = false;
    _inFlight = null;
    _inFlightUid = null;
  }
}
