import 'package:flutter/material.dart';

import '../config/plan_limits.dart';
import '../theme/app_theme.dart';

/// The upgrade screen shown when someone hits a plan limit (more clinics, more
/// members, more patients).
///
/// TEMPLATE ONLY: the plans and prices are placeholders and the button does not
/// charge anything yet.
Future<void> showPaywallDialog(BuildContext context, {required PlanLimit reason}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PaywallDialog(reason: reason),
  );
}

class _PaywallDialog extends StatelessWidget {
  final PlanLimit reason;
  const _PaywallDialog({required this.reason});

  String get _title => switch (reason) {
        PlanLimit.clinics => 'Add more clinics',
        PlanLimit.members => 'Add more team members',
        PlanLimit.patients => 'Store more patient records',
      };

  String get _lead {
    final free = PlanLimits.free;
    return switch (reason) {
      PlanLimit.clinics => 'The ${free.name} plan includes ${free.maxClinics} clinic${free.maxClinics == 1 ? '' : 's'} that you create.',
      PlanLimit.members => 'The ${free.name} plan includes up to ${free.maxMembersPerClinic} members in each clinic.',
      PlanLimit.patients => 'The ${free.name} plan stores up to ${_number(free.maxPatientsPerClinic)} patient records in each clinic.',
    };
  }

  static String _number(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final free = PlanLimits.free;
    final pro = PlanLimits.pro;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryBlue, size: 26),
              ),
              const SizedBox(height: 14),
              Text(_title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(_lead, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
              const SizedBox(height: 16),
              _PlanTable(free: free, pro: pro),
              const SizedBox(height: 16),
              const Text(
                'Subscriptions are not available yet. This is a preview of how upgrading will look.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Not now', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  const ElevatedButton(onPressed: null, child: Text('Upgrade — coming soon')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTable extends StatelessWidget {
  final PlanLimits free;
  final PlanLimits pro;
  const _PlanTable({required this.free, required this.pro});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String a, String b, {bool header = false}) {
      final style = TextStyle(
        fontSize: 12,
        fontWeight: header ? FontWeight.bold : FontWeight.w500,
        color: header ? AppTheme.textPrimary : AppTheme.textSecondary,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(label, style: style)),
            Expanded(flex: 2, child: Text(a, style: style)),
            Expanded(flex: 2, child: Text(b, style: style.copyWith(color: header ? AppTheme.primaryBlue : AppTheme.textPrimary))),
          ],
        ),
      );
    }

    String n(int v) => _PaywallDialog._number(v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          row('', free.name, pro.name, header: true),
          const Divider(height: 1, color: AppTheme.borderColor),
          row('Clinics you create', '${free.maxClinics}', '${pro.maxClinics}'),
          const Divider(height: 1, color: AppTheme.borderColor),
          row('Members per clinic', '${free.maxMembersPerClinic}', '${pro.maxMembersPerClinic}'),
          const Divider(height: 1, color: AppTheme.borderColor),
          row('Patients per clinic', n(free.maxPatientsPerClinic), n(pro.maxPatientsPerClinic)),
        ],
      ),
    );
  }
}
