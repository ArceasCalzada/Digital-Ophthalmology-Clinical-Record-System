import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'views/login_view.dart';
import 'views/main_layout.dart';

void main() {
  runApp(const OphthalmologyApp());
}

class OphthalmologyApp extends StatefulWidget {
  const OphthalmologyApp({super.key});

  @override
  State<OphthalmologyApp> createState() => _OphthalmologyAppState();
}

class _OphthalmologyAppState extends State<OphthalmologyApp> {
  bool _isLoggedIn = true; // Set to true by default for direct workstation entry

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
          home: _isLoggedIn
              ? MainLayout(
                  onLogout: () => setState(() => _isLoggedIn = false),
                )
              : LoginView(
                  onLoginSuccess: () => setState(() => _isLoggedIn = true),
                ),
        );
      },
    );
  }
}
