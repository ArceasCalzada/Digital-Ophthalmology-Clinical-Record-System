import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/required_text_form_field.dart';

/// Post-Registration Onboarding Wizard (Option 3).
///
/// Multi-step setup wizard that handles structured legal name entry, role path
/// selection, and either instant clinic workspace creation (for Doctors/Owners
/// with zero approval delays) or invite-code submission into a pending queue
/// (for Staff/Assistants).
class OnboardingWizardView extends StatefulWidget {
  final VoidCallback? onCompleted;
  final VoidCallback? onLogout;

  const OnboardingWizardView({
    super.key,
    this.onCompleted,
    this.onLogout,
  });

  @override
  State<OnboardingWizardView> createState() => _OnboardingWizardViewState();
}

class _OnboardingWizardViewState extends State<OnboardingWizardView> {
  int _currentStep = 0; // 0: Names, 1: Path Choice, 2: Setup/Config
  String? _selectedPath; // 'new_practice' or 'join_clinic'

  // Step 1: Structured Names
  final _step1FormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();

  // Step 3A: Open New Clinic Practice
  final _step3AFormKey = GlobalKey<FormState>();
  final _clinicNameController = TextEditingController();
  final _specialtyController = TextEditingController(text: 'General Ophthalmology');
  final _clinicAddressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _ptrController = TextEditingController();

  // Step 3B: Join Existing Clinic
  final _step3BFormKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  String? _verifiedClinicName;
  String? _inviteCodeError;

  bool _isLoading = false;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _populateInitialNamesFromAuth();
  }

  void _populateInitialNamesFromAuth() {
    final user = AuthService.instance.user;
    if (user != null) {
      if (user.firstName != null && user.firstName!.isNotEmpty) {
        _firstNameController.text = user.firstName!;
      }
      if (user.middleName != null && user.middleName!.isNotEmpty) {
        _middleNameController.text = user.middleName!;
      }
      if (user.lastName != null && user.lastName!.isNotEmpty) {
        _lastNameController.text = user.lastName!;
      }
      if (user.suffix != null && user.suffix!.isNotEmpty) {
        _suffixController.text = user.suffix!;
      }
      if (_firstNameController.text.isEmpty &&
          user.displayName != null &&
          user.displayName!.isNotEmpty &&
          user.displayName != user.email?.split('@').first) {
        final tokens = user.displayName!.split(RegExp(r'\s+'));
        if (tokens.isNotEmpty) {
          _firstNameController.text = tokens.first;
          if (tokens.length > 1) {
            _lastNameController.text = tokens.last;
            if (tokens.length > 2) {
              _middleNameController.text = tokens.sublist(1, tokens.length - 1).join(' ');
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _clinicNameController.dispose();
    _specialtyController.dispose();
    _clinicAddressController.dispose();
    _licenseController.dispose();
    _ptrController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  String _computedFullName({bool withDoctorPrefix = false}) {
    final first = _firstNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final last = _lastNameController.text.trim();
    final sfx = _suffixController.text.trim();

    final parts = <String>[
      if (first.isNotEmpty) first,
      if (middle.isNotEmpty) middle,
      if (last.isNotEmpty) last,
      if (sfx.isNotEmpty) sfx,
    ];
    final base = parts.isEmpty ? 'Your Name' : parts.join(' ');
    return withDoctorPrefix ? 'Dr. $base' : base;
  }

  void _handleStep1Continue() {
    if (_step1FormKey.currentState == null || !_step1FormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _generalError = null;
      _currentStep = 1;
    });
  }

  void _handleStep2Continue() {
    if (_selectedPath == null) {
      setState(() => _generalError = 'Please select an option to proceed.');
      return;
    }
    setState(() {
      _generalError = null;
      _currentStep = 2;
    });
  }

  Future<void> _handleCreatePracticeSubmit() async {
    if (_step3AFormKey.currentState == null || !_step3AFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await AuthService.instance.completeDoctorOnboarding(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        suffix: _suffixController.text.trim(),
        clinicName: _clinicNameController.text.trim(),
        specialization: _specialtyController.text.trim(),
        clinicAddress: _clinicAddressController.text.trim(),
        license: _licenseController.text.trim(),
        ptrNo: _ptrController.text.trim(),
      );
      if (mounted) {
        widget.onCompleted?.call();
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _generalError = e.message);
    } catch (e) {
      if (mounted) setState(() => _generalError = 'Failed to configure practice workspace: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinClinicSubmit() async {
    if (_step3BFormKey.currentState == null || !_step3BFormKey.currentState!.validate()) {
      return;
    }

    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _inviteCodeError = 'Please enter a clinic invite code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _inviteCodeError = null;
      _generalError = null;
    });

    try {
      await AuthService.instance.completeJoinClinicOnboarding(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        suffix: _suffixController.text.trim(),
        inviteCode: code,
      );
      if (mounted) {
        setState(() {});
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _inviteCodeError = e.message);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _inviteCodeError = e.message);
    } catch (e) {
      if (mounted) setState(() => _inviteCodeError = 'Unable to validate invite code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    // If join request has already been submitted, render the clean Pending Approval card
    if (auth.hasSubmittedJoinRequest || (auth.isPendingRole && !auth.needsOnboarding)) {
      return _buildPendingApprovalScreen(auth);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              key: const Key('onboarding-wizard-view'),
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppTheme.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(auth),
                      const SizedBox(height: 20),
                      _buildProgressIndicator(),
                      const SizedBox(height: 24),
                      if (_generalError != null) ...[
                        _buildErrorBanner(_generalError!),
                        const SizedBox(height: 16),
                      ],
                      if (_currentStep == 0)
                        _buildStep1Identity()
                      else if (_currentStep == 1)
                        _buildStep2PathSelection()
                      else
                        _buildStep3Configuration(),
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

  Widget _buildHeader(AuthService auth) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.remove_red_eye_rounded,
                    size: 20,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'DOCRS Workstation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  auth.signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFDC2626)),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome to Your Clinical Setup',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Configure your professional identity and workspace to begin (${auth.email ?? "clinical user"}).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Legal Identity', 'Practice Path', 'Setup'];
    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final stepIndex = index ~/ 2;
              final isPassed = _currentStep > stepIndex;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isPassed ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                ),
              );
            }
            final stepIndex = index ~/ 2;
            final isCurrent = _currentStep == stepIndex;
            final isPassed = _currentStep > stepIndex;

            return Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isPassed || isCurrent ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPassed || isCurrent ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isPassed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (i) {
            final isCurrent = _currentStep == i;
            return Text(
              steps[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? AppTheme.primaryBlue : AppTheme.textSecondary,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 1: Structured Legal Identity
  // =========================================================================
  Widget _buildStep1Identity() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 20, color: AppTheme.primaryBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Enter your legal name as it should appear on medical licenses, official prescriptions, and clinic directories.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Row 1: First Name (Required) & Middle Name (Optional)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First Name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    RequiredTextFormField(
                      key: const Key('wizard-first-name-field'),
                      controller: _firstNameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Jane',
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter your first name';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Middle Name (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('wizard-middle-name-field'),
                      controller: _middleNameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Marie',
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Last Name (Required) & Suffix (Optional)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    RequiredTextFormField(
                      key: const Key('wizard-last-name-field'),
                      controller: _lastNameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Doe',
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter your last name';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suffix (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('wizard-suffix-field'),
                      controller: _suffixController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Jr., Sr., III',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Name Preview Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preview: ${_computedFullName(withDoctorPrefix: false)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Continue Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('wizard-step1-continue-button'),
              onPressed: _handleStep1Continue,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Continue to Practice Setup',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: Role & Practice Path Selection
  // =========================================================================
  Widget _buildStep2PathSelection() {
    final isNewPractice = _selectedPath == 'new_practice';
    final isJoinClinic = _selectedPath == 'join_clinic';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Your Practice Path',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose how you will be utilizing DOCRS in your clinical workflow:',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Path A: Open New Clinic Practice
        InkWell(
          key: const Key('wizard-path-new-practice'),
          onTap: () => setState(() => _selectedPath = 'new_practice'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isNewPractice ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNewPractice ? AppTheme.primaryBlue : AppTheme.borderColor,
                width: isNewPractice ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isNewPractice ? 0.05 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isNewPractice ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    color: isNewPractice ? Colors.white : AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Open a New Clinic Practice',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Doctors / Owners',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Instant private workspace setup with zero approval delays. Includes electronic Rx pads, exam encounters, and practice ownership permissions.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFEAB308)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Bypasses approval queue — instant access to workstation',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF854D0E)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isNewPractice ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isNewPractice ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Path B: Join an Existing Clinic
        InkWell(
          key: const Key('wizard-path-join-clinic'),
          onTap: () => setState(() => _selectedPath = 'join_clinic'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isJoinClinic ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isJoinClinic ? AppTheme.primaryBlue : AppTheme.borderColor,
                width: isJoinClinic ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isJoinClinic ? 0.05 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isJoinClinic ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    color: isJoinClinic ? Colors.white : AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Join an Existing Clinic',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Staff / Assistants',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requires a 6-character clinic invite code provided by your attending doctor or practice administrator.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: AppTheme.primaryBlue),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Safely routes your account to your team\'s approval queue',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isJoinClinic ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isJoinClinic ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            OutlinedButton(
              key: const Key('wizard-step2-back-button'),
              onPressed: () => setState(() => _currentStep = 0),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('wizard-step2-continue-button'),
                  onPressed: _selectedPath != null ? _handleStep2Continue : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 3: Setup & Configuration (3A: Practice Setup or 3B: Invite Code)
  // =========================================================================
  Widget _buildStep3Configuration() {
    if (_selectedPath == 'new_practice') {
      return _buildStep3APracticeSetup();
    }
    return _buildStep3BJoinClinic();
  }

  Widget _buildStep3APracticeSetup() {
    return Form(
      key: _step3AFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.domain_add_rounded, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Configure ${_computedFullName(withDoctorPrefix: true)}\'s Practice',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Provide your practice information to auto-provision your clinic workspace.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Clinic Name
          Text(
            'Clinic / Practice Name',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          RequiredTextFormField(
            key: const Key('wizard-clinic-name-field'),
            controller: _clinicNameController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'e.g. Metro Eye Center & Refractive Surgery',
              prefixIcon: Icon(Icons.domain_rounded, color: AppTheme.primaryBlue, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter your clinic or practice name';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Specialty
          Text(
            'Medical Specialty / Subspecialty',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          RequiredTextFormField(
            key: const Key('wizard-specialty-field'),
            controller: _specialtyController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'e.g. Cornea & Refractive / General Ophthalmology',
              prefixIcon: Icon(Icons.medical_services_outlined, color: AppTheme.primaryBlue, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter your medical specialty';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Clinic Location / Branch Address (Optional)
          Text(
            'Clinic Branch / Address (Optional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('wizard-clinic-address-field'),
            controller: _clinicAddressController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'e.g. Suite 402, Medical Arts Tower, Quezon City',
              prefixIcon: Icon(Icons.place_outlined, color: AppTheme.primaryBlue, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Professional Credentials Row: PRC License & PTR Number
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRC License No. (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('wizard-license-field'),
                      controller: _licenseController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'e.g. 091823',
                        prefixIcon: Icon(Icons.card_membership_outlined, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PTR Number (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('wizard-ptr-field'),
                      controller: _ptrController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'e.g. 7821940',
                        prefixIcon: Icon(Icons.receipt_long_outlined, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              OutlinedButton(
                key: const Key('wizard-step3-back-button'),
                onPressed: _isLoading ? null : () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('wizard-create-practice-submit-button'),
                    onPressed: _isLoading ? null : _handleCreatePracticeSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Provisioning Practice...' : 'Complete Setup & Launch Practice',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3BJoinClinic() {
    return Form(
      key: _step3BFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.group_add_rounded, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Join Your Clinic Team',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the 6-character clinic invite code provided by your attending physician or clinic admin.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          Text(
            'Clinic Invite Code',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('wizard-invite-code-field'),
            controller: _inviteCodeController,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) {
              setState(() {
                _inviteCodeError = null;
                _verifiedClinicName = null;
              });
            },
            decoration: InputDecoration(
              hintText: 'e.g. DOC-1000 or ABC123',
              prefixIcon: Icon(Icons.key_rounded, color: AppTheme.primaryBlue, size: 20),
              suffixIcon: _verifiedClinicName != null
                  ? const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20)
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter clinic invite code';
              if (val.trim().length < 4) return 'Invite code is too short';
              return null;
            },
          ),
          if (_inviteCodeError != null) ...[
            const SizedBox(height: 8),
            Text(
              _inviteCodeError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ],
          if (_verifiedClinicName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.domain_verification_rounded, size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target Clinic: $_verifiedClinicName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Submitting your request will add ${_computedFullName()} to the clinic\'s pending member queue. The clinic owner will review and activate your access.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              OutlinedButton(
                key: const Key('wizard-step3-back-button'),
                onPressed: _isLoading ? null : () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('wizard-join-clinic-submit-button'),
                    onPressed: _isLoading ? null : _handleJoinClinicSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Submitting Request...' : 'Submit Join Request',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PENDING APPROVAL STATE SCREEN
  // =========================================================================
  Widget _buildPendingApprovalScreen(AuthService auth) {
    final clinicName = auth.pendingWorkspaceName ?? 'Target Clinical Workspace';
    final code = auth.pendingInviteCode ?? 'DOC-INVITE';
    final user = auth.user;
    final displayName = user?.displayName ?? _computedFullName();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              key: const Key('wizard-pending-approval-view'),
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppTheme.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            size: 32,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Join Request Submitted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Awaiting clinic owner approval. Your account has been added to the team queue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Request Details Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Clinic Practice', clinicName, Icons.domain_rounded),
                            const Divider(height: 16),
                            _buildDetailRow('Invite Code', code, Icons.key_rounded),
                            const Divider(height: 16),
                            _buildDetailRow('Applicant Name', displayName, Icons.person_rounded),
                            const Divider(height: 16),
                            _buildDetailRow('Assigned Status', 'Pending Approval', Icons.schedule_rounded,
                                badgeColor: const Color(0xFFFEF3C7), textColor: const Color(0xFF92400E)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Check Status Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('wizard-check-status-button'),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  await auth.reloadUserAndCheckRole();
                                  if (mounted) setState(() => _isLoading = false);
                                },
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            _isLoading ? 'Checking Status...' : 'Check Approval Status',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Change Code / Re-enter
                      OutlinedButton.icon(
                        key: const Key('wizard-change-code-button'),
                        onPressed: () {
                          auth.resetJoinRequest();
                          setState(() {
                            _currentStep = 2;
                            _selectedPath = 'join_clinic';
                          });
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Enter a Different Invite Code'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Sign Out
                      TextButton(
                        key: const Key('wizard-sign-out-button'),
                        onPressed: () {
                          if (widget.onLogout != null) {
                            widget.onLogout!();
                          } else {
                            auth.signOut();
                          }
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildDetailRow(String label, String value, IconData icon,
      {Color? badgeColor, Color? textColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        const Spacer(),
        if (badgeColor != null)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor ?? AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
