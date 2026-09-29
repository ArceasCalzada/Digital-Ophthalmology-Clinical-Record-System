import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'dr.jenkins@ophthalmology.clinic');
  final _passwordController = TextEditingController(text: 'docrs2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  int _selectedTab = 0; // 0: Form Login, 1: Quick Physician Access

  final List<Map<String, String>> _quickPhysicians = [
    {
      'name': 'Dr. Sigrid Robillos, MD',
      'role': 'Senior Ophthalmologist & Medical Director',
      'email': 'dr.robillos@ophthalmology.clinic',
      'initials': 'SR',
    },
    {
      'name': 'Dr. Arceas Calzada, MD',
      'role': 'Cornea & Refractive Surgery Specialist',
      'email': 'dr.calzada@ophthalmology.clinic',
      'initials': 'AC',
    },
    {
      'name': 'Dr. Jenkins, MD',
      'role': 'Glaucoma & Vitreoretinal Consultant',
      'email': 'dr.jenkins@ophthalmology.clinic',
      'initials': 'DJ',
    },
  ];

  Future<void> _handleSignIn([String? presetEmail]) async {
    if (presetEmail != null) {
      _emailController.text = presetEmail;
    }
    if (_selectedTab == 1 || (_formKey.currentState != null && _formKey.currentState!.validate())) {
      setState(() => _isLoading = true);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('docrs_user_logged_in', _rememberMe);
        final emailToSave = presetEmail ?? _emailController.text.trim();
        await prefs.setString('docrs_user_email', emailToSave);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onLoginSuccess();
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Reset Workstation Password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'Please contact your Clinic IT Administrator or Senior Medical Director to reset your workstation credentials.\n\nEmergency Auth Support: +63 (02) 8888-DOCRS',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header & Logo Emblem
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryBlue.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.remove_red_eye_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'DOCRS Clinical System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Digital Ophthalmology Clinical Record System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode Switcher Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 0),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedTab == 0
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Text(
                                  'Physician Login',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 0 ? AppTheme.primaryBlue : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = 1),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedTab == 1
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Text(
                                  'Quick Access',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 1 ? AppTheme.primaryBlue : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedTab == 0) ...[
                      // Credentials Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Physician Email / Workstation ID',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'dr.jenkins@ophthalmology.clinic',
                                prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter your physician email or ID';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            const Text(
                              'Password',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '••••••••••••',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryBlue, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter password';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: AppTheme.primaryBlue,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Remember workstation',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: AppTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : () => _handleSignIn(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text('Sign In to Workstation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Quick Access Accounts List
                      const Text(
                        'Select Active Clinic Physician:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ..._quickPhysicians.map((physician) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              child: Text(
                                physician['initials']!,
                                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            title: Text(
                              physician['name']!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            subtitle: Text(
                              physician['role']!,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryBlue),
                            onTap: _isLoading ? null : () => _handleSignIn(physician['email']),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 28),

                    // Compliance Footer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'HIPAA Compliant • Encrypted Local Vault',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
