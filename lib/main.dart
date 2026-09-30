import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_limits.dart';
import 'firebase_options.dart';
import 'models/calendar_event.dart';
import 'models/clinical_notification.dart';
import 'models/patient.dart';
import 'services/auth_service.dart';
import 'services/clinic_store.dart';
import 'services/dev_auth_backend.dart';
import 'services/draft_manager_service.dart';
import 'services/offline_sync_service.dart';
import 'services/profile_store.dart';
import 'theme/app_theme.dart';
import 'views/login_view.dart';
import 'views/main_layout.dart';
import 'widgets/inactivity_guard.dart';

/// reCAPTCHA v3 site key for App Check on web. Pass at build time:
/// `flutter build web --dart-define=DOCRS_RECAPTCHA_SITE_KEY=<key>`
const String _recaptchaSiteKey = String.fromEnvironment('DOCRS_RECAPTCHA_SITE_KEY');

/// UI-only mode: no Firebase, no real data, any login works. See [DevAuthBackend].
/// Run with `--dart-define=DOCRS_UI_DEV=true`.
const bool _uiDevFlag = bool.fromEnvironment('DOCRS_UI_DEV');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DevAuthBackend.isEnabled(flag: _uiDevFlag, isWeb: kIsWeb, webHost: Uri.base.host)) {
    debugPrint('DOCRS UI dev mode: Firebase is NOT connected; data is in memory only.');
    await AuthService.instance.attach(DevAuthBackend());
  } else {
    await _initFirebase();
  }

  await PatientRepository.init();
  runApp(const OphthalmologyApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Without Firebase nobody can sign in, so the app stays on the login screen.
    debugPrint('Firebase init failed: $e');
    return;
  }

  // App Check proves requests come from this app, not a script using the public
  // API key. It is enforced per service in the Firebase console.
  try {
    if (kIsWeb && _recaptchaSiteKey.isEmpty) {
      debugPrint('App Check not activated: build with --dart-define=DOCRS_RECAPTCHA_SITE_KEY=<key>.');
    } else {
      // A stalled attestation request must never keep the app from starting: if
      // this times out the app still opens and Firebase (once App Check is
      // enforced) simply refuses the un-attested requests.
      await FirebaseAppCheck.instance
          .activate(
            providerWeb: kIsWeb ? ReCaptchaV3Provider(_recaptchaSiteKey) : null,
            providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
          )
          .timeout(const Duration(seconds: 8));
    }
  } catch (e) {
    debugPrint('App Check activation skipped: $e');
  }

  try {
    FirebaseFirestore.instance.settings = Settings(
      // Web keeps no offline cache, so no patient data is left in the browser.
      // Mobile and desktop keep a bounded cache in the app's private storage.
      persistenceEnabled: !kIsWeb,
      cacheSizeBytes: AppLimits.firestoreCacheBytes,
    );
  } catch (e) {
    debugPrint('Firestore settings skipped: $e');
  }

  await AuthService.instance.init();
}

class OphthalmologyApp extends StatefulWidget {
  const OphthalmologyApp({super.key});

  @override
  State<OphthalmologyApp> createState() => _OphthalmologyAppState();
}

class _OphthalmologyAppState extends State<OphthalmologyApp> {
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = AuthService.instance.isSignedIn;
    if (_wasSignedIn) _onSignedIn();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final signedIn = AuthService.instance.isSignedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    if (signedIn) {
      _onSignedIn();
    } else {
      _onSignedOut();
    }
  }

  void _onSignedIn() {
    final user = AuthService.instance.user;
    if (user != null) {
      ClinicStore.instance.load(user.uid);
      ProfileStore.instance.syncWithUser(user);
    }
    PatientRepository.connect();
    CalendarEventRepository().connect();
    ClinicalNotificationRepository().connect();
    final sync = OfflineSyncService();
    sync.startAutoSyncTimer();
    sync.syncNow(); // flush anything queued while signed out
  }

  void _onSignedOut() {
    ClinicStore.instance.unload();
    PatientRepository.disconnect();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
    OfflineSyncService().stopAutoSyncTimer();
    DraftManagerService().clearAllDrafts();
    ProfileStore.instance.reset();
  }

  Future<void> _handleLogout() => AuthService.instance.signOut();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeController.instance, AuthService.instance]),
      builder: (context, child) {
        final auth = AuthService.instance;
        return MaterialApp(
          title: 'DOCRS — Digital Ophthalmology Clinical Record System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: auth.isResolving
              ? const Scaffold(
                  backgroundColor: AppTheme.lightBg,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                )
              : (auth.isSignedIn
                  ? InactivityGuard(
                      timeout: AuthService.idleTimeout,
                      onTimeout: _handleLogout,
                      child: MainLayout(
                        onLogout: _handleLogout,
                      ),
                    )
                  : LoginView(
                      onLoginSuccess: () {},
                    )),
        );
      },
    );
  }
}
