import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/services/auth_service.dart';
import 'package:ophthalmology_clinical_record_system/services/dev_auth_backend.dart';

void main() {
  test('UI dev mode is off without the flag and off the web outside localhost', () {
    expect(DevAuthBackend.isEnabled(flag: false, isWeb: true, webHost: 'localhost'), isFalse);
    expect(DevAuthBackend.isEnabled(flag: true, isWeb: true, webHost: 'docrs-clinical-system.web.app'), isFalse);
    expect(DevAuthBackend.isEnabled(flag: true, isWeb: true, webHost: 'localhost'), isTrue);
    expect(DevAuthBackend.isEnabled(flag: true, isWeb: false, webHost: '', isRelease: true), isFalse);
    expect(DevAuthBackend.isEnabled(flag: true, isWeb: false, webHost: '', isRelease: false), isTrue);
  });

  test('starts signed in as admin and any login signs back in after sign-out', () async {
    final auth = AuthService.instance;
    await auth.resetForTesting();
    await auth.attach(DevAuthBackend());
    expect(auth.isSignedIn, isTrue);
    expect(auth.role, UserRole.admin);

    await auth.signOut();
    expect(auth.isSignedIn, isFalse);

    await auth.signIn('anything@example.com', 'whatever');
    expect(auth.isSignedIn, isTrue);
    await auth.resetForTesting();
  });
}
