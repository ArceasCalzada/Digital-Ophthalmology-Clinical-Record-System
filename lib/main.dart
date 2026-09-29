import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'models/patient.dart';
import 'theme/app_theme.dart';
import 'views/login_view.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }

  await PatientRepository.init();
  runApp(const OphthalmologyApp());
}

class OphthalmologyApp extends StatefulWidget {
  const OphthalmologyApp({super.key});

  @override
  State<OphthalmologyApp> createState() => _OphthalmologyAppState();
}

class _OphthalmologyAppState extends State<OphthalmologyApp> {
  bool _isLoggedIn = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkLoginSession();
  }

  Future<void> _checkLoginSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool('docrs_user_logged_in') ?? false;
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn;
          _isCheckingSession = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('docrs_user_logged_in', false);
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoggedIn = false);
    }
  }

  Future<void> _handleLoginSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('docrs_user_logged_in', true);
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoggedIn = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'DOCRS — Digital Ophthalmology Clinical Record System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: _isCheckingSession
              ? const Scaffold(
                  backgroundColor: AppTheme.lightBg,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                )
              : (_isLoggedIn
                  ? MainLayout(
                      onLogout: _handleLogout,
                    )
                  : LoginView(
                      onLoginSuccess: _handleLoginSuccess,
                    )),
        );
      },
    );
  }
}
