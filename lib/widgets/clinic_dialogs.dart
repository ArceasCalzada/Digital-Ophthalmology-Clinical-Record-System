import 'package:flutter/material.dart';

import '../config/plan_limits.dart';
import '../services/clinic_store.dart';
import '../services/invite_code.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import 'field_label.dart';
import 'paywall_dialog.dart';
import 'required_text_form_field.dart';

/// Makes sure there is a clinic to save into before something is created (a patient,
/// an appointment, an exam). An account starts without one, so the first time it
/// creates anything it is asked to name its clinic. Returns false if it declined.
Future<bool> ensureClinic(BuildContext context) async {
  if (TeamService.instance.activeTeam != null || ClinicStore.instance.active != null) return true;
  return showCreateClinicDialog(context, firstTime: true);
}

/// Asks for a name and creates a clinic led by this account. When the plan's clinic
/// limit is reached it shows the upgrade screen instead. Returns true if one was made.
Future<bool> showCreateClinicDialog(BuildContext context, {bool firstTime = false}) async {
  if (!ClinicStore.instance.canCreateClinic) {
    await showPaywallDialog(context, reason: PlanLimit.clinics);
    return false;
  }
  final created = await showDialog<bool>(
    context: context,
    builder: (context) => _CreateClinicDialog(firstTime: firstTime),
  );
  return created ?? false;
}

class _CreateClinicDialog extends StatefulWidget {
  /// Shown when the account has no clinic yet and is about to save something.
  final bool firstTime;
  const _CreateClinicDialog({required this.firstTime});

  @override
  State<_CreateClinicDialog> createState() => _CreateClinicDialogState();
}

class _CreateClinicDialogState extends State<_CreateClinicDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ClinicStore.instance.createClinic(_name.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.firstTime ? 'Create your clinic first' : 'Create a clinic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Clinic or hospital name', required: true),
              SizedBox(height: 6),
              RequiredTextFormField(
                controller: _name,
                decoration: InputDecoration(hintText: 'e.g. Metro Eye Center'),
                invalidMessage: ClinicStore.nameProblem,
              ),
              SizedBox(height: 8),
              Text(
                widget.firstTime
                    ? 'Patients, exams and appointments are saved in a clinic. Give yours a name to continue.'
                    : 'Each clinic keeps its own patients, calendar and members.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(onPressed: _create, child: Text('Create clinic')),
      ],
    );
  }
}

/// Asks for an invite code (typed, or a pasted link) and joins that clinic.
Future<void> showJoinClinicDialog(BuildContext context, {String? initialCode}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _JoinClinicDialog(initialCode: initialCode),
  );
}

class _JoinClinicDialog extends StatefulWidget {
  final String? initialCode;
  const _JoinClinicDialog({this.initialCode});

  @override
  State<_JoinClinicDialog> createState() => _JoinClinicDialogState();
}

class _JoinClinicDialogState extends State<_JoinClinicDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initialCode);

  /// Shown under the field when the code is fine but joining is not possible.
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _notice = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ClinicStore.instance.joinWithCode(InviteCode.parse(_code.text)!);
      if (mounted) Navigator.pop(context);
    } on CloudUnavailableException catch (e) {
      if (mounted) setState(() => _notice = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Join a clinic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Invite code or link', required: true),
              SizedBox(height: 6),
              RequiredTextFormField(
                controller: _code,
                decoration: InputDecoration(hintText: 'DOCRS-XXXXX-XXXXX'),
                invalidMessage: (v) => InviteCode.parse(v) == null ? 'That is not a valid invite code' : null,
              ),
              SizedBox(height: 8),
              Text(
                'Open the link the clinic leader sent you, or type the code from their invite.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (_notice != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Text(_notice!, style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(onPressed: _busy ? null : _join, child: Text('Join clinic')),
      ],
    );
  }
}
