import 'dart:async';

import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/sms_otp_service.dart';

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
    if (accounts.containsKey(email)) {
      throw const AuthFailure('An account with this email address already exists.');
    }
    accounts[email] = (password: password, role: null);
    _current = AuthUser(
      'uid-$email',
      email,
      displayName: fullName,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      suffix: suffix,
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
  Future<String> sendEmailOtp(String email) async {
    verificationEmailCalls++;
    return '123456';
  }

  @override
  Future<bool> verifyEmailOtp(String email, String otp) async {
    return otp.trim() == '123456';
  }

  @override
  Future<AuthUser?> reloadUser() async => _current;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _changes.add(null);
  }

  final Map<String, bool> twoFactorAccounts = {};
  final Map<String, String> twoFactorPhoneNumbers = {};
  String? lastVerificationId;
  int changePasswordCalls = 0;

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    changePasswordCalls++;
    final current = _current;
    if (current == null || current.email == null) {
      throw const AuthFailure('No active session found.');
    }
    final email = current.email!;
    final account = accounts[email];
    if (account == null || account.password != currentPassword) {
      throw const AuthFailure('Current password is incorrect. Please re-enter.');
    }
    accounts[email] = (password: newPassword, role: account.role);
  }

  @override
  Future<bool> verifyPassword(String email, String password) async {
    final account = accounts[email];
    return account != null && account.password == password;
  }

  @override
  Future<bool> fetchTwoFactorEnabled(String uid) async {
    final email = uid.replaceFirst('uid-', '');
    return twoFactorAccounts[email] ?? false;
  }

  @override
  Future<String?> fetchTwoFactorPhone(String uid) async {
    final email = uid.replaceFirst('uid-', '');
    return twoFactorPhoneNumbers[email] ?? '+639175550192';
  }

  @override
  Future<String> startTwoFactorEnrollment(String phoneNumber) async {
    final code = await SmsOtpService.instance.generateAndSendSmsOtp(phoneNumber);
    lastVerificationId = 'verif-$code';
    return lastVerificationId!;
  }

  @override
  Future<void> finalizeTwoFactorEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final current = _current;
    if (current == null || current.email == null) {
      throw const AuthFailure('No active session found.');
    }
    final expectedCode = lastVerificationId?.replaceFirst('verif-', '') ??
        SmsOtpService.instance.lastGeneratedCode;
    if (smsCode != expectedCode) {
      throw const AuthFailure('The verification code entered is incorrect. Please check the code sent to your phone and try again.');
    }
    final email = current.email!;
    twoFactorAccounts[email] = true;
    twoFactorPhoneNumbers[email] = phoneNumber;
    SmsOtpService.instance.clearOtp(phoneNumber);
  }

  @override
  Future<void> unenrollTwoFactor() async {
    final current = _current;
    if (current == null || current.email == null) return;
    final email = current.email!;
    twoFactorAccounts[email] = false;
    twoFactorPhoneNumbers.remove(email);
  }

  @override
  Future<UserRole?> fetchRole(String uid) async {
    roleReads++;
    final email = uid.replaceFirst('uid-', '');
    return accounts[email]?.role;
  }
}
