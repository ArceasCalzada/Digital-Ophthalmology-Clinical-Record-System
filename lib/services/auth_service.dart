import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'email_otp_service.dart';
import 'firebase_gate.dart';
import 'profile_store.dart';
import 'sms_otp_service.dart';
import 'team_service.dart';
import '../models/team.dart';

/// Roles stored in `users/{uid}.role`. Admins can also delete patient records.
enum UserRole { admin, physician, staff }

UserRole? parseUserRole(Object? raw) {
  if (raw == null || raw is! String) return null;
  final str = raw.trim().toLowerCase();
  switch (str) {
    case 'admin':
    case 'owner':
    case 'leader':
      return UserRole.admin;
    case 'physician':
    case 'editor':
    case 'doctor':
      return UserRole.physician;
    case 'staff':
    case 'assistant':
      return UserRole.staff;
    default:
      return null;
  }
}

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? suffix;
  final bool isEmailVerified;
  final Map<String, dynamic> customClaims;
  const AuthUser(
    this.uid,
    this.email, {
    this.displayName,
    this.firstName,
    this.lastName,
    this.middleName,
    this.suffix,
    this.isEmailVerified = true,
    this.customClaims = const {},
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
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<String> sendEmailOtp(String email);
  Future<bool> verifyEmailOtp(String email, String otp);
  Future<AuthUser?> reloadUser();
  Future<void> signOut();

  /// Re-authenticates the current user using [currentPassword] and applies [newPassword].
  Future<void> changePassword({required String currentPassword, required String newPassword});

  /// Verifies credentials for [email] and [password] (e.g. for unlocking locked sessions).
  Future<bool> verifyPassword(String email, String password);

  /// Checks if 2FA is enrolled and enabled for [uid].
  Future<bool> fetchTwoFactorEnabled(String uid);

  /// Reads enrolled 2FA phone number for [uid].
  Future<String?> fetchTwoFactorPhone(String uid);

  /// Starts 2FA enrollment for the current user with [phoneNumber].
  /// Returns a verification ID (or session handle) to be passed to [finalizeTwoFactorEnrollment].
  Future<String> startTwoFactorEnrollment(String phoneNumber);

  /// Finalizes 2FA enrollment using [verificationId], [smsCode], and [phoneNumber].
  /// Uses PhoneAuthProvider and multiFactor(user).enroll, updates user metadata and Firestore.
  Future<void> finalizeTwoFactorEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  });

  /// Unenrolls 2FA for the current user and clears Firestore 2FA flags.
  Future<void> unenrollTwoFactor();

  /// Reads `users/{uid}.role`. Null means the account is not authorised for DOCRS.
  Future<UserRole?> fetchRole(String uid);

  /// Assigns or updates the role for [uid] in the identity provider or user collection.
  Future<void> assignRole(String uid, UserRole role);

  /// Updates profile name components for [uid].
  Future<void> updateProfileNames({
    required String uid,
    required String displayName,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
  });
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
      try {
        final firestore = FirebaseFirestore.instance;
        final now = DateTime.now().toIso8601String();
        String? targetWorkspaceId = workspaceId;

        final cleanInvite = inviteCode?.trim().toUpperCase();
        if ((targetWorkspaceId == null || targetWorkspaceId.isEmpty) && cleanInvite != null && cleanInvite.isNotEmpty) {
          try {
            final tSnap = await firestore
                .collection('teams')
                .where('inviteCode', isEqualTo: cleanInvite)
                .limit(1)
                .get();
            if (tSnap.docs.isNotEmpty) {
              targetWorkspaceId = tSnap.docs.first.id;
            }
          } catch (e) {
            debugPrint('[AuthService.signUp] Resolving workspace by invite code error: $e');
          }
        }

        final userPayload = <String, dynamic>{
          'uid': user.uid,
          'email': email.trim(),
          'displayName': fullName.trim(),
          'fullName': fullName.trim(),
          if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
          if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
          if (suffix != null && suffix.trim().isNotEmpty) 'suffix': suffix.trim(),
          'status': 'pending',
          'isApproved': false,
          'requestedRole': requestedRole,
          'createdAt': now,
          'updatedAt': now,
          if (cleanInvite != null && cleanInvite.isNotEmpty) 'inviteCode': cleanInvite,
          if (targetWorkspaceId != null && targetWorkspaceId.isNotEmpty) ...{
            'requestedWorkspaceId': targetWorkspaceId,
            'workspaceId': targetWorkspaceId,
            'teamId': targetWorkspaceId,
          },
        };

        await firestore.collection('users').doc(user.uid).set(userPayload, SetOptions(merge: true));

        if (targetWorkspaceId != null && targetWorkspaceId.isNotEmpty) {
          final memberPayload = <String, dynamic>{
            'uid': user.uid,
            'email': email.trim(),
            'displayName': fullName.trim(),
            if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
            if (lastName != null && lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
            if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
            if (suffix != null && suffix.trim().isNotEmpty) 'suffix': suffix.trim(),
            'role': 'viewer',
            'requestedRole': requestedRole,
            'status': 'pending',
            'isApproved': false,
            'requestedWorkspaceId': targetWorkspaceId,
            'workspaceId': targetWorkspaceId,
            'teamId': targetWorkspaceId,
            'joinedAt': now,
            'requestedAt': now,
            'createdAt': now,
            'updatedAt': now,
            if (cleanInvite != null && cleanInvite.isNotEmpty) 'inviteCode': cleanInvite,
          };
          final batch = firestore.batch();
          final mRef = firestore.collection('teams').doc(targetWorkspaceId).collection('members').doc(user.uid);
          final jRef = firestore.collection('teams').doc(targetWorkspaceId).collection('joinRequests').doc(user.uid);
          batch.set(mRef, memberPayload, SetOptions(merge: true));
          batch.set(jRef, memberPayload, SetOptions(merge: true));
          await batch.commit();
        }
      } catch (e) {
        debugPrint('[AuthService.signUp] Notice persisting initial pending user document: $e');
      }
      return AuthUser(
        user.uid,
        user.email,
        displayName: fullName.trim(),
        firstName: firstName?.trim(),
        lastName: lastName?.trim(),
        middleName: middleName?.trim(),
        suffix: suffix?.trim(),
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
      case 'invalid-verification-code':
        return 'The verification code entered is incorrect. Please check the code sent to your phone and try again.';
      case 'session-expired':
        return 'The verification code has expired. Please request a new code.';
      case 'invalid-verification-id':
        return 'The verification session is invalid. Please request a new verification code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later or contact your administrator.';
      case 'invalid-phone-number':
        return 'The mobile phone number entered is invalid. Please enter a valid number including country code (e.g. +63).';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session found. Please sign in again.');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthFailure('Unable to identify current account.');
    }
    try {
      final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('Current password is incorrect. Please re-enter.');
      }
      throw AuthFailure(_messageFor(e.code));
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure('Re-authentication failed: $e');
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw const AuthFailure('New password is too weak. Please use at least 6 characters.');
      }
      throw AuthFailure(_messageFor(e.code));
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure('Failed to update password: $e');
    }
  }

  @override
  Future<bool> verifyPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final cred = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> fetchTwoFactorEnabled(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('security')
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        final val = doc.data()?['twoFactorEnabled'] as bool?;
        if (val != null) return val;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (userDoc.exists && userDoc.data() != null) {
        final val = userDoc.data()?['twoFactorEnabled'] as bool?;
        if (val != null) return val;
      }
    } catch (_) {}
    final u = _auth.currentUser;
    if (u != null && u.uid == uid) {
      try {
        final factors = await u.multiFactor.getEnrolledFactors();
        if (factors.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<String?> fetchTwoFactorPhone(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('security')
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        final phone = doc.data()?['twoFactorPhoneNumber'] as String?;
        if (phone != null && phone.isNotEmpty) return phone;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (userDoc.exists && userDoc.data() != null) {
        final phone = userDoc.data()?['twoFactorPhoneNumber'] as String?;
        if (phone != null && phone.isNotEmpty) return phone;
      }
    } catch (_) {}
    final u = _auth.currentUser;
    if (u != null && u.uid == uid) {
      try {
        final factors = await u.multiFactor.getEnrolledFactors();
        if (factors.isNotEmpty) {
          final factor = factors.first;
          if (factor is PhoneMultiFactorInfo) {
            return factor.phoneNumber;
          }
          return factor.displayName;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<String> startTwoFactorEnrollment(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active user session. Please sign in again.');
    }

    try {
      final session = await user.multiFactor.getSession();
      final completer = Completer<String>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        multiFactorSession: session,
        verificationCompleted: (PhoneAuthCredential credential) {
          if (!completer.isCompleted && credential.verificationId != null) {
            completer.complete(credential.verificationId!);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(AuthFailure(_messageFor(e.code)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw const AuthFailure('SMS verification request timed out. Please try again.'),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed' ||
          e.code == 'missing-client-identifier' ||
          e.code == 'app-not-authorized') {
        debugPrint('Firebase MFA Phone Auth notice (${e.code}): falling back to SMS OTP service for local/dev testing.');
        return await SmsOtpService.instance.generateAndSendSmsOtp(phoneNumber);
      }
      throw AuthFailure(_messageFor(e.code));
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure('Failed to initiate SMS verification: $e');
    }
  }

  @override
  Future<void> finalizeTwoFactorEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active user session. Please sign in again.');
    }

    if (SmsOtpService.instance.lastGeneratedCode != null &&
        (verificationId == SmsOtpService.instance.lastGeneratedCode ||
            verificationId.startsWith('sms-otp-') ||
            verificationId.isEmpty)) {
      final valid = await SmsOtpService.instance.verifySmsOtp(phoneNumber, smsCode);
      if (!valid) {
        throw const AuthFailure('The verification code entered is incorrect. Please check the code sent to your phone and try again.');
      }
    } else {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
        await user.multiFactor.enroll(assertion, displayName: phoneNumber);
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-verification-code') {
          throw const AuthFailure('The verification code entered is incorrect. Please check the code sent to your phone and try again.');
        } else if (e.code == 'session-expired') {
          throw const AuthFailure('The verification code has expired. Please request a new code.');
        }
        throw AuthFailure(_messageFor(e.code));
      } catch (e) {
        final valid = await SmsOtpService.instance.verifySmsOtp(phoneNumber, smsCode);
        if (!valid) {
          throw const AuthFailure('The verification code entered is incorrect. Please check the code sent to your phone and try again.');
        }
      }
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(user.uid);
      final secRef = userRef.collection('settings').doc('security');

      final timestamp = FieldValue.serverTimestamp();
      batch.set(userRef, {
        'twoFactorEnabled': true,
        'twoFactorPhoneNumber': phoneNumber,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));

      batch.set(secRef, {
        'twoFactorEnabled': true,
        'twoFactorPhoneNumber': phoneNumber,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));

      await batch.commit().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Notice persisting 2FA status to Firestore: $e');
    }
  }

  @override
  Future<void> unenrollTwoFactor() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      for (final factor in factors) {
        await user.multiFactor.unenroll(multiFactorInfo: factor);
      }
      await user.reload();
    } catch (e) {
      debugPrint('Notice unenrolling multiFactor from Firebase Auth: $e');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(user.uid);
      final secRef = userRef.collection('settings').doc('security');

      final timestamp = FieldValue.serverTimestamp();
      batch.set(userRef, {
        'twoFactorEnabled': false,
        'twoFactorPhoneNumber': null,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));

      batch.set(secRef, {
        'twoFactorEnabled': false,
        'twoFactorPhoneNumber': null,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));

      await batch.commit().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Notice persisting 2FA unenrollment to Firestore: $e');
    }
  }

  @override
  Future<UserRole?> fetchRole(String uid) async {
    final u = _auth.currentUser;
    if (u != null && u.uid == uid) {
      try {
        final tokenResult = await u.getIdTokenResult();
        final claims = tokenResult.claims ?? {};
        final roleClaim = claims['role'] ??
            claims['userRole'] ??
            claims['user_role'] ??
            claims['membershipRole'] ??
            claims['teamRole'];
        final parsed = parseUserRole(roleClaim);
        if (parsed != null) return parsed;
      } catch (_) {}
    }
    // Bounded so a dead connection shows the login screen instead of a blank app.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 15));
      return parseUserRole(doc.data()?['role']);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> assignRole(String uid, UserRole role) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).set({
        'role': role.name,
        'status': 'active',
        'isApproved': true,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseAuthBackend.assignRole] Notice: $e');
    }
  }

  @override
  Future<void> updateProfileNames({
    required String uid,
    required String displayName,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
  }) async {
    try {
      final u = _auth.currentUser;
      if (u != null && u.uid == uid) {
        await u.updateDisplayName(displayName);
      }
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'fullName': displayName,
        if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
        if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
        if (suffix != null && suffix.trim().isNotEmpty) 'suffix': suffix.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirebaseAuthBackend.updateProfileNames] Notice: $e');
    }
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

  Map<String, dynamic> _customClaims = {};
  Map<String, dynamic> get customClaims =>
      _user?.customClaims.isNotEmpty == true ? _user!.customClaims : _customClaims;

  void setCustomClaims(Map<String, dynamic> claims) {
    _customClaims = Map<String, dynamic>.from(claims);
    notifyListeners();
  }

  bool _otpVerifiedLocally = false;
  bool _is2faPending = false;
  AuthUser? _pending2faUser;
  String? _enrolled2faPhone;
  bool _hasSubmittedJoinRequest = false;
  String? _pendingWorkspaceName;
  String? _pendingInviteCode;

  bool get isAvailable => _backend != null;
  AuthUser? get user => _user;
  UserRole? get role => _role;
  String? get email => _user?.email;
  bool get isEmailVerified => _otpVerifiedLocally || (_user?.isEmailVerified ?? true);
  bool get isPendingEmailVerification => _user != null && !isEmailVerified;
  bool get isPendingRole => _user != null && isEmailVerified && _role == null;
  bool get hasSubmittedJoinRequest => _hasSubmittedJoinRequest;
  String? get pendingWorkspaceName => _pendingWorkspaceName;
  String? get pendingInviteCode => _pendingInviteCode;
  bool get needsOnboarding =>
      _user != null &&
      isEmailVerified &&
      !_is2faPending &&
      _role == null &&
      !_hasSubmittedJoinRequest;
  bool get is2faPending => _is2faPending;
  String get masked2faPhone => _enrolled2faPhone != null
      ? SmsOtpService.maskPhoneNumber(_enrolled2faPhone!)
      : '+63 ••• ••• 0192';
  bool get isSignedIn => _user != null && _role != null && isEmailVerified && !_is2faPending;
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
        if (_role == null) {
          final firestore = FirebaseGate.firestoreIfReady();
          if (firestore != null) {
            try {
              final doc = await firestore.collection('users').doc(user.uid).get();
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                final wsId = data['requestedWorkspaceId'] as String?;
                final code = data['inviteCode'] as String?;
                if (wsId != null && wsId.isNotEmpty) {
                  _hasSubmittedJoinRequest = true;
                  _pendingInviteCode = code;
                  try {
                    final tDoc = await firestore.collection('teams').doc(wsId).get();
                    if (tDoc.exists && tDoc.data() != null) {
                      _pendingWorkspaceName = tDoc.data()!['name'] as String?;
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
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

    // Check if account has 2FA enabled
    final is2faEnabled = await backend.fetchTwoFactorEnabled(signedIn.uid);
    if (is2faEnabled) {
      _is2faPending = true;
      _pending2faUser = signedIn;
      _enrolled2faPhone = await backend.fetchTwoFactorPhone(signedIn.uid);
      await SmsOtpService.instance.generateAndSendSmsOtp(_enrolled2faPhone ?? '09175550192');
      notifyListeners();
      return;
    }

    await _onUserChanged(signedIn);
  }

  /// Completes 2FA verification during sign-in using the 6-digit [otpCode].
  Future<void> complete2faSignIn(String otpCode) async {
    final backend = _backend;
    if (backend == null || _pending2faUser == null) {
      throw const AuthFailure('No sign-in session pending 2FA verification.');
    }
    final phone = _enrolled2faPhone ?? '09175550192';
    final isValid = await SmsOtpService.instance.verifySmsOtp(phone, otpCode);
    if (!isValid) {
      throw const AuthFailure('Invalid 6-digit verification code. Please check and try again.');
    }
    final user = _pending2faUser!;
    _is2faPending = false;
    _pending2faUser = null;
    await _onUserChanged(user);
  }

  /// Re-sends the 2FA SMS code.
  Future<void> resend2faCode() async {
    if (!_is2faPending) return;
    final phone = _enrolled2faPhone ?? '09175550192';
    await SmsOtpService.instance.generateAndSendSmsOtp(phone);
  }

  /// Cancels pending 2FA verification and returns to the sign-in screen.
  Future<void> cancel2fa() async {
    _is2faPending = false;
    _pending2faUser = null;
    _enrolled2faPhone = null;
    final backend = _backend;
    try {
      await backend?.signOut();
    } catch (_) {}
    notifyListeners();
  }

  /// Initiates 2FA enrollment by triggering Firebase Phone Auth verification.
  /// Returns a verification ID to be submitted with the 6-digit code.
  Future<String> startTwoFactorEnrollment(String phoneNumber) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    return await backend.startTwoFactorEnrollment(phoneNumber);
  }

  /// Finalizes 2FA enrollment using [verificationId] and [smsCode].
  /// Enrolls the phone factor in Firebase Auth and updates Firestore and user metadata.
  Future<void> finalizeTwoFactorEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    await backend.finalizeTwoFactorEnrollment(
      verificationId: verificationId,
      smsCode: smsCode,
      phoneNumber: phoneNumber,
    );
  }

  /// Disables 2FA by unenrolling phone factors from Firebase Auth and clearing Firestore flags.
  Future<void> unenrollTwoFactor() async {
    final backend = _backend;
    if (backend != null) {
      await backend.unenrollTwoFactor();
    }
  }

  /// Sends a 6-digit SMS OTP code for 2FA enrollment verification.
  Future<String> sendTwoFactorEnrollmentSms(String phoneNumber) async {
    return await startTwoFactorEnrollment(phoneNumber);
  }

  /// Verifies a 6-digit SMS OTP code for 2FA enrollment.
  Future<bool> verifyTwoFactorEnrollmentSms(String phoneNumber, String otpCode, {String verificationId = ''}) async {
    try {
      await finalizeTwoFactorEnrollment(
        verificationId: verificationId,
        smsCode: otpCode,
        phoneNumber: phoneNumber,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Changes the user's password in Firebase Authentication.
  /// Requires re-authenticating with [currentPassword] before updating to [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    if (currentPassword.isEmpty) {
      throw const AuthFailure('Please enter your current password.');
    }
    if (newPassword.isEmpty) {
      throw const AuthFailure('Please enter a new password.');
    }
    if (newPassword.length < 6) {
      throw const AuthFailure('New password must be at least 6 characters long.');
    }
    if (currentPassword == newPassword) {
      throw const AuthFailure('New password must be different from your current password.');
    }
    await backend.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Verifies [password] against the current signed-in user's credentials.
  Future<bool> verifyCurrentPassword(String password) async {
    final backend = _backend;
    if (backend == null) return true;
    final u = _user;
    if (u == null || u.email == null) return false;
    return await backend.verifyPassword(u.email!, password);
  }

  /// Registers a new account.
  Future<void> signUp(
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
    final backend = _backend;
    if (backend == null) {
      throw const AuthFailure('The cloud service is not available. Check your connection and restart the app.');
    }
    final trimmedEmail = email.trim();
    String effectiveFullName = fullName.trim();
    String? effFirst = firstName?.trim();
    String? effLast = lastName?.trim();
    String? effMiddle = middleName?.trim();
    String? effSuffix = suffix?.trim();

    if ((effFirst != null && effFirst.isNotEmpty) || (effLast != null && effLast.isNotEmpty)) {
      final parts = <String>[
        if (effFirst != null && effFirst.isNotEmpty) effFirst,
        if (effMiddle != null && effMiddle.isNotEmpty) effMiddle,
        if (effLast != null && effLast.isNotEmpty) effLast,
        if (effSuffix != null && effSuffix.isNotEmpty) effSuffix,
      ];
      if (parts.isNotEmpty) {
        effectiveFullName = parts.join(' ');
      }
    } else if (effectiveFullName.isNotEmpty) {
      final tokens = effectiveFullName.split(RegExp(r'\s+'));
      if (tokens.isNotEmpty) {
        effFirst ??= tokens.first;
        if (tokens.length > 1) {
          effLast ??= tokens.last;
          if (tokens.length > 2) {
            effMiddle ??= tokens.sublist(1, tokens.length - 1).join(' ');
          }
        }
      }
    }

    if (effectiveFullName.isEmpty && trimmedEmail.isNotEmpty) {
      effectiveFullName = trimmedEmail.split('@').first;
    }

    if (effectiveFullName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('Please complete all required fields.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password is too weak. Please use at least 6 characters.');
    }
    _hasSubmittedJoinRequest = false;
    _pendingWorkspaceName = null;
    _pendingInviteCode = null;
    final newUser = await backend.signUp(
      trimmedEmail,
      password,
      effectiveFullName,
      firstName: effFirst,
      lastName: effLast,
      middleName: effMiddle,
      suffix: effSuffix,
      requestedRole: requestedRole,
      inviteCode: inviteCode,
      workspaceId: workspaceId,
    );
    await _onUserChanged(newUser);
  }

  /// Completes onboarding for an independent doctor opening a new clinic practice.
  /// Provisions workspace ownership instantly and assigns physician role with 0 approval delays.
  Future<void> completeDoctorOnboarding({
    required String firstName,
    required String lastName,
    String? middleName,
    String? suffix,
    required String clinicName,
    required String specialization,
    String clinicAddress = '',
    String license = '',
    String ptrNo = '',
  }) async {
    final curUser = _user;
    if (curUser == null) {
      throw const AuthFailure('No active authenticated session.');
    }

    final nameParts = <String>[
      firstName.trim(),
      if (middleName != null && middleName.trim().isNotEmpty) middleName.trim(),
      lastName.trim(),
      if (suffix != null && suffix.trim().isNotEmpty) suffix.trim(),
    ];
    final fullName = nameParts.join(' ');
    final formattedDoctorName = 'Dr. $fullName';

    // 1. Update backend profile names
    await _backend?.updateProfileNames(
      uid: curUser.uid,
      displayName: formattedDoctorName,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      middleName: middleName?.trim(),
      suffix: suffix?.trim(),
    );

    // 2. Assign physician role in backend
    await _backend?.assignRole(curUser.uid, UserRole.physician);
    _role = UserRole.physician;

    // 3. Update local AuthUser
    _user = AuthUser(
      curUser.uid,
      curUser.email,
      displayName: formattedDoctorName,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      middleName: middleName?.trim(),
      suffix: suffix?.trim(),
      isEmailVerified: curUser.isEmailVerified,
    );

    // 4. Update ProfileStore
    ProfileStore.instance.doctorName.text = formattedDoctorName;
    ProfileStore.instance.firstName = firstName.trim();
    ProfileStore.instance.lastName = lastName.trim();
    ProfileStore.instance.middleName = middleName?.trim();
    ProfileStore.instance.suffix = suffix?.trim();
    ProfileStore.instance.clinicName.text = clinicName.trim();
    if (specialization.trim().isNotEmpty) {
      ProfileStore.instance.specialization.text = specialization.trim();
    }
    if (clinicAddress.trim().isNotEmpty) {
      ProfileStore.instance.clinicAddress.text = clinicAddress.trim();
    }
    if (license.trim().isNotEmpty) {
      ProfileStore.instance.license.text = license.trim();
    }
    if (ptrNo.trim().isNotEmpty) {
      ProfileStore.instance.ptrNo.text = ptrNo.trim();
    }
    await ProfileStore.instance.saveToPreferences();

    // 5. Create Team Workspace with User as Owner
    final team = await TeamService.instance.createTeam(
      clinicName.trim(),
      location: clinicAddress.trim(),
    );

    // 6. Persist to Firestore if available
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      try {
        await firestore.collection('users').doc(curUser.uid).set({
          'role': 'physician',
          'status': 'active',
          'isApproved': true,
          'displayName': formattedDoctorName,
          'fullName': formattedDoctorName,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
          if (suffix != null && suffix.trim().isNotEmpty) 'suffix': suffix.trim(),
          'clinicName': clinicName.trim(),
          'specialization': specialization.trim(),
          if (clinicAddress.trim().isNotEmpty) 'clinicAddress': clinicAddress.trim(),
          if (license.trim().isNotEmpty) 'license': license.trim(),
          if (ptrNo.trim().isNotEmpty) 'ptrNo': ptrNo.trim(),
          'workspaceId': team.id,
          'onboardingCompleted': true,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[AuthService.completeDoctorOnboarding] Notice saving user details: $e');
      }
    }

    notifyListeners();
  }

  /// Completes onboarding for staff / assistants joining an existing clinic.
  Future<Team> completeJoinClinicOnboarding({
    required String firstName,
    required String lastName,
    String? middleName,
    String? suffix,
    required String inviteCode,
  }) async {
    final curUser = _user;
    if (curUser == null) {
      throw const AuthFailure('No active authenticated session.');
    }

    final nameParts = <String>[
      firstName.trim(),
      if (middleName != null && middleName.trim().isNotEmpty) middleName.trim(),
      lastName.trim(),
      if (suffix != null && suffix.trim().isNotEmpty) suffix.trim(),
    ];
    final formattedName = nameParts.join(' ');

    // 1. Update backend profile names
    await _backend?.updateProfileNames(
      uid: curUser.uid,
      displayName: formattedName,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      middleName: middleName?.trim(),
      suffix: suffix?.trim(),
    );

    // 2. Update local AuthUser
    _user = AuthUser(
      curUser.uid,
      curUser.email,
      displayName: formattedName,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      middleName: middleName?.trim(),
      suffix: suffix?.trim(),
      isEmailVerified: curUser.isEmailVerified,
    );

    // 3. Update ProfileStore
    ProfileStore.instance.doctorName.text = formattedName;
    ProfileStore.instance.firstName = firstName.trim();
    ProfileStore.instance.lastName = lastName.trim();
    ProfileStore.instance.middleName = middleName?.trim();
    ProfileStore.instance.suffix = suffix?.trim();
    await ProfileStore.instance.saveToPreferences();

    // 4. Join team via TeamService
    final cleanCode = inviteCode.trim().toUpperCase();
    final team = await TeamService.instance.joinWithCode(
      cleanCode,
      requestedRole: 'assistant',
    );

    _hasSubmittedJoinRequest = true;
    _pendingWorkspaceName = team.name;
    _pendingInviteCode = cleanCode;

    // 5. Update Firestore user doc if ready
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      try {
        await firestore.collection('users').doc(curUser.uid).set({
          'displayName': formattedName,
          'fullName': formattedName,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
          if (suffix != null && suffix.trim().isNotEmpty) 'suffix': suffix.trim(),
          'status': 'pending',
          'isApproved': false,
          'requestedRole': 'assistant',
          'requestedWorkspaceId': team.id,
          'inviteCode': cleanCode,
          'onboardingCompleted': true,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[AuthService.completeJoinClinicOnboarding] Notice saving user details: $e');
      }
    }

    notifyListeners();
    return team;
  }

  /// Resets a pending join request so the user can re-enter onboarding or change invite code.
  void resetJoinRequest() {
    _hasSubmittedJoinRequest = false;
    _pendingWorkspaceName = null;
    _pendingInviteCode = null;
    notifyListeners();
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
    _is2faPending = false;
    _pending2faUser = null;
    _enrolled2faPhone = null;
    _hasSubmittedJoinRequest = false;
    _pendingWorkspaceName = null;
    _pendingInviteCode = null;
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
    _is2faPending = false;
    _pending2faUser = null;
    _enrolled2faPhone = null;
    _hasSubmittedJoinRequest = false;
    _pendingWorkspaceName = null;
    _pendingInviteCode = null;
    _resolving = false;
    _inFlight = null;
    _inFlightUid = null;
  }
}
