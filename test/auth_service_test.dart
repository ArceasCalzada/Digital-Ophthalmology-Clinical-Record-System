import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';

import 'helpers/fake_auth_backend.dart';

void main() {
  late FakeAuthBackend backend;

  setUp(() async {
    await AuthService.instance.resetForTesting();
    backend = FakeAuthBackend({
      'admin@clinic.test': (password: 'correct-horse', role: UserRole.admin),
      'doc@clinic.test': (password: 'battery-staple', role: UserRole.physician),
      'front@clinic.test': (password: 'desk-pass-1', role: UserRole.staff),
      'stranger@clinic.test': (password: 'no-role-pass', role: null),
    });
    await AuthService.instance.attach(backend);
  });

  tearDown(() async {
    await AuthService.instance.resetForTesting();
  });

  test('starts signed out', () {
    expect(AuthService.instance.isSignedIn, isFalse);
    expect(AuthService.instance.role, isNull);
  });

  test('signs in with a correct password and exposes the role', () async {
    await AuthService.instance.signIn('doc@clinic.test', 'battery-staple');
    expect(AuthService.instance.isSignedIn, isTrue);
    expect(AuthService.instance.role, UserRole.physician);
    expect(AuthService.instance.email, 'doc@clinic.test');
    expect(AuthService.instance.canWriteClinical, isTrue);
    expect(AuthService.instance.canDelete, isFalse);
  });

  test('only admins can delete; staff cannot write clinical data', () async {
    await AuthService.instance.signIn('admin@clinic.test', 'correct-horse');
    expect(AuthService.instance.canDelete, isTrue);
    await AuthService.instance.signOut();

    await AuthService.instance.signIn('front@clinic.test', 'desk-pass-1');
    expect(AuthService.instance.canWriteClinical, isFalse);
    expect(AuthService.instance.canDelete, isFalse);
  });

  test('rejects a wrong password without signing in', () async {
    await expectLater(
      AuthService.instance.signIn('doc@clinic.test', 'wrong'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'Incorrect email or password.')),
    );
    expect(AuthService.instance.isSignedIn, isFalse);
  });

  test('unknown email gives the same message as a wrong password (no account enumeration)', () async {
    await expectLater(
      AuthService.instance.signIn('nobody@clinic.test', 'whatever'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'Incorrect email or password.')),
    );
  });

  test('handles authenticated user with no role by placing them in isPendingRole state', () async {
    await AuthService.instance.signIn('stranger@clinic.test', 'no-role-pass');
    expect(AuthService.instance.isSignedIn, isFalse);
    expect(AuthService.instance.isPendingRole, isTrue);
    expect(AuthService.instance.user?.email, 'stranger@clinic.test');
  });

  test('registers a new user and triggers verification and pending role state', () async {
    await AuthService.instance.signUp('newdoc@clinic.test', 'securepass123', 'Dr. New Doctor');
    expect(AuthService.instance.user?.email, 'newdoc@clinic.test');
    expect(AuthService.instance.user?.displayName, 'Dr. New Doctor');
    expect(AuthService.instance.isSignedIn, isFalse);
    expect(AuthService.instance.isPendingRole, isTrue);
  });

  test('rejects weak passwords during registration', () async {
    await expectLater(
      AuthService.instance.signUp('newdoc@clinic.test', '123', 'Dr. Short Pass'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', contains('at least 6 characters'))),
    );
  });

  test('rejects duplicate email during registration', () async {
    await expectLater(
      AuthService.instance.signUp('doc@clinic.test', 'battery-staple', 'Dr. Existing'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', contains('already exists'))),
    );
  });

  test('requests password reset email for existing user', () async {
    await AuthService.instance.sendPasswordResetEmail('doc@clinic.test');
    expect(backend.resetEmailCalls, 1);
  });

  test('handles email verification pending state when email is not verified', () async {
    backend.shouldRequireEmailVerification = true;
    await AuthService.instance.signIn('doc@clinic.test', 'battery-staple');
    expect(AuthService.instance.isEmailVerified, isFalse);
    expect(AuthService.instance.isPendingEmailVerification, isTrue);
    expect(AuthService.instance.isSignedIn, isFalse);
  });

  test('blank email or password is rejected before contacting the server', () async {
    await expectLater(AuthService.instance.signIn('  ', 'x'), throwsA(isA<AuthFailure>()));
    await expectLater(AuthService.instance.signIn('doc@clinic.test', ''), throwsA(isA<AuthFailure>()));
    expect(backend.roleReads, 0);
  });

  test('sign out clears the session', () async {
    await AuthService.instance.signIn('doc@clinic.test', 'battery-staple');
    await AuthService.instance.signOut();
    expect(AuthService.instance.isSignedIn, isFalse);
    expect(AuthService.instance.user, isNull);
  });

  test('sign-in is refused when no backend is available', () async {
    await AuthService.instance.resetForTesting();
    await expectLater(
      AuthService.instance.signIn('doc@clinic.test', 'battery-staple'),
      throwsA(isA<AuthFailure>()),
    );
    expect(AuthService.instance.isAvailable, isFalse);
  });

  test('parseUserRole only accepts known roles', () {
    expect(parseUserRole('admin'), UserRole.admin);
    expect(parseUserRole('physician'), UserRole.physician);
    expect(parseUserRole('staff'), UserRole.staff);
    expect(parseUserRole('root'), isNull);
    expect(parseUserRole(null), isNull);
    expect(parseUserRole(1), isNull);
  });
}
