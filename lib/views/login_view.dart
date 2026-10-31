import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../widgets/required_text_form_field.dart';
import 'onboarding_wizard_view.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _signUpInviteCodeController = TextEditingController();

  bool _isSignUpMode = false;
  String _signUpRoleIntent = 'physician';
  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSuccessTransitioning = false;
  bool _rememberMe = false;
  String? _errorMessage;

  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _twoFactorOtpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _twoFactorOtpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying2fa = false;
  String? _twoFactorError;

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _confirmPasswordController.dispose();
    _signUpInviteCodeController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    for (final c in _twoFactorOtpControllers) {
      c.dispose();
    }
    for (final f in _twoFactorOtpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _isDark =>
      ThemeController.instance.isDarkMode ||
      (mounted && Theme.of(context).brightness == Brightness.dark);

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = _isDark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final focusBorderColor = isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue;
    final fillColor = isDark
        ? const Color(0xFF0F172A)
        : (_isLoading ? const Color(0xFFF8FAFC) : Colors.white);
    final iconColor = _isLoading
        ? (isDark ? const Color(0xFF64748B) : AppTheme.textSecondary)
        : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue);

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: iconColor, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusBorderColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _handleSignIn() async {
    if (_signInFormKey.currentState == null || !_signInFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signIn(
        _signInEmailController.text,
        _signInPasswordController.text,
        remember: _rememberMe,
      );
      _signInPasswordController.clear();
      if (mounted && AuthService.instance.isSignedIn) {
        setState(() => _isSuccessTransitioning = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          widget.onLoginSuccess();
        }
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _isSuccessTransitioning = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSuccessTransitioning = false;
          _errorMessage = 'Sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (_signUpFormKey.currentState == null || !_signUpFormKey.currentState!.validate()) return;

    if (_signUpPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    if (_signUpRoleIntent == 'assistant' && _signUpInviteCodeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a clinic invite code to join an existing practice.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _signUpEmailController.text.trim();
      final password = _signUpPasswordController.text;
      final inviteCode = _signUpInviteCodeController.text.trim();

      await AuthService.instance.signUp(
        email,
        password,
        '',
        requestedRole: _signUpRoleIntent,
        inviteCode: _signUpRoleIntent == 'assistant' ? inviteCode : null,
      );
      _signUpPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        if (AuthService.instance.isSignedIn) {
          setState(() => _isSuccessTransitioning = true);
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            widget.onLoginSuccess();
          }
        } else if (AuthService.instance.isPendingApproval ||
            AuthService.instance.hasSubmittedJoinRequest ||
            AuthService.instance.needsOnboarding) {
          setState(() {});
        }
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _signInEmailController.text.trim());
    final dialogFormKey = GlobalKey<FormState>();
    bool isResetting = false;
    String? dialogError;
    String? dialogSuccess;
    final isDark = _isDark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reset Workstation Password',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your registered email address and we will send you a link to reset your password.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RequiredTextFormField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'name@clinic.example',
                      prefixIcon: Icons.email_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter your email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                  if (dialogSuccess != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogSuccess!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        if (!dialogFormKey.currentState!.validate()) return;
                        setDialogState(() {
                          isResetting = true;
                          dialogError = null;
                          dialogSuccess = null;
                        });
                        try {
                          await AuthService.instance.sendPasswordResetEmail(resetEmailController.text);
                          setDialogState(() {
                            dialogSuccess = 'Password reset email sent. Please check your inbox.';
                          });
                        } on AuthFailure catch (e) {
                          setDialogState(() => dialogError = e.message);
                        } catch (_) {
                          setDialogState(() => dialogError = 'Failed to send reset email.');
                        } finally {
                          setDialogState(() => isResetting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isResetting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    if (auth.needsOnboarding || auth.hasSubmittedJoinRequest) {
      return OnboardingWizardView(
        onCompleted: widget.onLoginSuccess,
        onLogout: () => auth.signOut(),
      );
    }

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = _isDark;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    elevation: isDark ? 8 : 4,
                    shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                          Text(
                            'DOCRS Clinical System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Digital Ophthalmology Clinical Record System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // State Handler views
                          if (_isSuccessTransitioning)
                            _buildSuccessTransitionView()
                          else if (auth.is2faPending)
                            _buildTwoFactorPendingView(auth)
                          else if (auth.isPendingEmailVerification)
                            _buildEmailVerificationPendingView(auth)
                          else if (auth.isPendingRole && auth.isPendingApproval)
                            _buildPendingRoleView(auth)
                          else if (auth.isPendingRole && !auth.isPendingApproval)
                            _buildAutoProvisionPhysicianView(auth)
                          else ...[
                            // Mode Switcher Tabs
                            Container(
                              height: 40,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                _isSignUpMode = false;
                                                _errorMessage = null;
                                              });
                                            },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: !_isSignUpMode
                                              ? (isDark ? const Color(0xFF334155) : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: !_isSignUpMode
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: !_isSignUpMode ? FontWeight.bold : FontWeight.w500,
                                            color: !_isSignUpMode
                                                ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                _isSignUpMode = true;
                                                _errorMessage = null;
                                              });
                                            },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _isSignUpMode
                                              ? (isDark ? const Color(0xFF334155) : Colors.white)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: _isSignUpMode
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _isSignUpMode ? FontWeight.bold : FontWeight.w500,
                                            color: _isSignUpMode
                                                ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            if (!_isSignUpMode) _buildSignInForm() else _buildSignUpForm(),
                          ],

                          const SizedBox(height: 24),

                          // Compliance Footer Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Authorised clinic staff only',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
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
      },
    );
  }

  Widget _buildSignInForm() {
    final isDark = _isDark;
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email Address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RequiredTextFormField(
            controller: _signInEmailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFF8FAFC)
                  : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              hintText: 'name@clinic.example',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter your email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RequiredTextFormField(
            controller: _signInPasswordController,
            enabled: !_isLoading,
            obscureText: _obscureSignInPassword,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFF8FAFC)
                  : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              hintText: '••••••••••••',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _obscureSignInPassword = !_obscureSignInPassword);
                      },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Enter your password';
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
                        side: BorderSide(
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: _isLoading ? null : (val) => setState(() => _rememberMe = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Keep me signed in',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: _isLoading
                        ? (isDark ? const Color(0xFF64748B) : AppTheme.textSecondary)
                        : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorContainer(_errorMessage!),
          ],
          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.75),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      key: Key('sign-in-loading-spinner'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
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
    );
  }

  Widget _buildSuccessTransitionView() {
    final isDark = _isDark;
    return Container(
      key: const Key('login-transition-view'),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Authenticating Session...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opening your clinical workstation dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    final isDark = _isDark;
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account Intent Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('signup-intent-physician'),
                    onTap: _isLoading
                        ? null
                        : () => setState(() {
                              _signUpRoleIntent = 'physician';
                              _errorMessage = null;
                            }),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _signUpRoleIntent == 'physician'
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _signUpRoleIntent == 'physician' && isDark
                            ? Border.all(color: const Color(0xFF475569))
                            : null,
                        boxShadow: _signUpRoleIntent == 'physician'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_services_rounded,
                            size: 16,
                            color: _signUpRoleIntent == 'physician'
                                ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Doctor / Practice',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _signUpRoleIntent == 'physician' ? FontWeight.bold : FontWeight.w500,
                                color: _signUpRoleIntent == 'physician'
                                    ? (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    key: const Key('signup-intent-assistant'),
                    onTap: _isLoading
                        ? null
                        : () => setState(() {
                              _signUpRoleIntent = 'assistant';
                              _errorMessage = null;
                            }),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _signUpRoleIntent == 'assistant'
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _signUpRoleIntent == 'assistant' && isDark
                            ? Border.all(color: const Color(0xFF475569))
                            : null,
                        boxShadow: _signUpRoleIntent == 'assistant'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 16,
                            color: _signUpRoleIntent == 'assistant'
                                ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Staff / Assistant',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _signUpRoleIntent == 'assistant' ? FontWeight.bold : FontWeight.w500,
                                color: _signUpRoleIntent == 'assistant'
                                    ? (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Context callout badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _signUpRoleIntent == 'physician'
                  ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFF0FDF4))
                  : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _signUpRoleIntent == 'physician'
                    ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.6) : const Color(0xFFBBF7D0))
                    : (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _signUpRoleIntent == 'physician' ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: _signUpRoleIntent == 'physician'
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                      : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _signUpRoleIntent == 'physician'
                        ? 'Independent practice: instant workspace provisioning with full Owner & Physician access.'
                        : 'Staff registration requires a clinic invite code from your practice administrator.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _signUpRoleIntent == 'physician'
                          ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))
                          : (isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF)),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_signUpRoleIntent == 'assistant') ...[
            Text(
              'Clinic Invite Code',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            RequiredTextFormField(
              key: const Key('signup-invite-code-field'),
              controller: _signUpInviteCodeController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFF8FAFC)
                    : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
              decoration: _buildInputDecoration(
                hintText: 'e.g. DOC-982',
                prefixIcon: Icons.vpn_key_outlined,
              ),
              validator: (val) {
                if (_signUpRoleIntent == 'assistant' && (val == null || val.trim().isEmpty)) {
                  return 'Enter your clinic invite code';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Clinic Email',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RequiredTextFormField(
            key: const Key('signup-email-field'),
            controller: _signUpEmailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFF8FAFC)
                  : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              hintText: 'name@clinic.example',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          Text(
            'Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RequiredTextFormField(
            key: const Key('signup-password-field'),
            controller: _signUpPasswordController,
            enabled: !_isLoading,
            obscureText: _obscureSignUpPassword,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFF8FAFC)
                  : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              hintText: 'At least 6 characters',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _obscureSignUpPassword = !_obscureSignUpPassword);
                      },
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          Text(
            'Confirm Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RequiredTextFormField(
            key: const Key('signup-confirm-password-field'),
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFF8FAFC)
                  : (_isLoading ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Repeat password',
              prefixIcon: Icons.lock_clock_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
              ),
            ),
            validator: (val) {
              if (val != _signUpPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorContainer(_errorMessage!),
          ],
          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('register-submit-button'),
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.75),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _signUpRoleIntent == 'physician'
                              ? Icons.local_hospital_rounded
                              : Icons.send_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _signUpRoleIntent == 'physician'
                                ? 'Create Physician Practice'
                                : 'Request Clinic Access',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String? _verificationStatusMessage;
  bool _verificationIsError = false;
  bool _isSendingVerification = false;

  Widget _buildEmailVerificationPendingView(AuthService auth) {
    final isDark = _isDark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.5) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_rounded,
                size: 40,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Verify Your Gmail Address',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A verification link has been sent to ${auth.email ?? "your Gmail address"}. Please open your Gmail inbox (or Spam folder), click the link to verify, then return here and tap the button below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (_verificationStatusMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _verificationIsError
                    ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
                    : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _verificationIsError
                      ? (isDark ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFFFCA5A5))
                      : (isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFA7F3D0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _verificationIsError ? Icons.error_outline : Icons.check_circle_outline,
                    size: 18,
                    color: _verificationIsError
                        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                        : (isDark ? const Color(0xFF34D399) : const Color(0xFF047857)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _verificationStatusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _verificationIsError
                            ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                            : (isDark ? const Color(0xFF34D399) : const Color(0xFF047857)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                        _verificationStatusMessage = null;
                      });
                      await auth.reloadUserAndCheckRole();
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          if (!auth.isEmailVerified) {
                            _verificationStatusMessage = 'Gmail link not clicked yet. Please check your inbox or click Resend.';
                            _verificationIsError = true;
                          }
                        });
                      }
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.mark_email_read_rounded, size: 18),
              label: const Text('I Have Clicked the Verification Link', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isSendingVerification
                  ? null
                  : () async {
                      setState(() {
                        _isSendingVerification = true;
                        _verificationStatusMessage = null;
                      });
                      try {
                        await auth.sendEmailVerification();
                        if (mounted) {
                          setState(() {
                            _verificationStatusMessage = 'Verification email re-sent to ${auth.email}! Please check your Gmail inbox and Spam folder.';
                            _verificationIsError = false;
                          });
                        }
                      } on AuthFailure catch (e) {
                        if (mounted) {
                          setState(() {
                            _verificationStatusMessage = e.message;
                            _verificationIsError = true;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _verificationStatusMessage = 'Failed to send verification email. Check internet connection.';
                            _verificationIsError = true;
                          });
                        }
                      } finally {
                        if (mounted) setState(() => _isSendingVerification = false);
                      }
                    },
              icon: _isSendingVerification
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Resend Verification Email to Gmail'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                side: BorderSide(color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _verificationStatusMessage = null);
                auth.signOut();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRoleView(AuthService auth) {
    final isDark = _isDark;
    final workspaceName = auth.pendingWorkspaceName ?? 'the clinic team';
    final inviteCode = auth.pendingInviteCode;

    return Container(
      key: const Key('pending-approval-holding-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              Icons.admin_panel_settings_outlined,
              size: 48,
              color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for Administrator Approval',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account (${auth.email}) has requested to join $workspaceName${inviteCode != null ? " with invite code $inviteCode" : ""}. A clinic administrator must approve your join request before you can access clinical records.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (inviteCode != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.6) : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Invite Code: $inviteCode',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const Key('check-status-button'),
            onPressed: () async {
              setState(() => _isLoading = true);
              await auth.reloadUserAndCheckRole();
              if (mounted) setState(() => _isLoading = false);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('change-invite-code-button'),
            onPressed: () => _showJoinClinicModalForPending(context, auth),
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('Enter Different Invite Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
              side: BorderSide(color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => auth.signOut(),
            child: Text(
              'Sign Out',
              style: TextStyle(color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoProvisionPhysicianView(AuthService auth) {
    final isDark = _isDark;
    return Container(
      key: const Key('physician-activation-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              Icons.medical_services_rounded,
              size: 48,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Doctor Practice Activation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your physician account (${auth.email}) is verified. Click below to automatically provision your private clinic workspace with full Owner & Physician privileges.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const Key('auto-provision-workspace-button'),
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                if (auth.user != null) {
                  await auth.autoProvisionPhysicianWorkspace(auth.user!);
                  if (mounted && auth.isSignedIn) {
                    setState(() => _isSuccessTransitioning = true);
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (mounted) widget.onLoginSuccess();
                  }
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Activate Practice Workspace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => auth.signOut(),
            child: Text(
              'Sign Out',
              style: TextStyle(color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinClinicModalForPending(BuildContext context, AuthService auth) {
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;
    final isDark = _isDark;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.group_add_rounded, color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Join Clinic Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-character invite code provided by your clinic owner to submit your join request for approval.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              if (errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  fontSize: 14,
                ),
                decoration: _buildInputDecoration(
                  hintText: 'e.g. ABC123',
                  prefixIcon: Icons.vpn_key_outlined,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) {
                        setDialogState(() => errorText = 'Please enter an invite code');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        await TeamService.instance.joinWithCode(code, requestedRole: 'assistant');
                        if (!mounted) return;
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Join request submitted! Waiting for clinic administrator approval.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                        await auth.reloadUserAndCheckRole();
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          final rawMsg = e.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', '');
                          if (rawMsg.contains('permission-denied')) {
                            errorText = 'Permission error submitting join request. Please verify credentials.';
                          } else {
                            errorText = rawMsg;
                          }
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    final isDark = _isDark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorPendingView(AuthService auth) {
    final isDark = _isDark;
    return Container(
      key: const Key('two_factor_verification_view'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.shield_outlined, size: 30, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Two-Factor Authentication',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit verification code sent via SMS to ${auth.masked2faPhone} to verify your identity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // 6 OTP Digit Inputs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextField(
                  key: Key('two_factor_login_otp_$index'),
                  controller: _twoFactorOtpControllers[index],
                  focusNode: _twoFactorOtpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _twoFactorOtpFocusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _twoFactorOtpFocusNodes[index - 1].requestFocus();
                    }
                    if (_twoFactorOtpControllers.every((c) => c.text.isNotEmpty)) {
                      _handleVerify2fa();
                    }
                  },
                ),
              );
            }),
          ),

          if (_twoFactorError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _twoFactorError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Verify Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('two_factor_verify_button'),
              onPressed: _isVerifying2fa ? null : _handleVerify2fa,
              icon: _isVerifying2fa
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(_isVerifying2fa ? 'Verifying...' : 'Verify & Continue', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Resend Code Button
          OutlinedButton.icon(
            key: const Key('two_factor_resend_button'),
            onPressed: () async {
              setState(() => _twoFactorError = null);
              await auth.resend2faCode();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A new 6-digit verification code has been dispatched via SMS.')),
                );
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Resend SMS Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
              side: BorderSide(color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),

          // Cancel & Return to Login
          Center(
            child: TextButton(
              key: const Key('two_factor_cancel_button'),
              onPressed: () {
                for (final c in _twoFactorOtpControllers) {
                  c.clear();
                }
                setState(() => _twoFactorError = null);
                auth.cancel2fa();
              },
              child: Text(
                'Cancel & Return to Sign In',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerify2fa() async {
    final code = _twoFactorOtpControllers.map((c) => c.text.trim()).join();
    if (code.length < 6) {
      setState(() => _twoFactorError = 'Please enter all 6 digits of the verification code.');
      return;
    }

    setState(() {
      _isVerifying2fa = true;
      _twoFactorError = null;
    });

    try {
      await AuthService.instance.complete2faSignIn(code);
      for (final c in _twoFactorOtpControllers) {
        c.clear();
      }
      if (mounted && AuthService.instance.isSignedIn) {
        widget.onLoginSuccess();
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _twoFactorError = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _twoFactorError = 'Verification failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying2fa = false);
      }
    }
  }
}
