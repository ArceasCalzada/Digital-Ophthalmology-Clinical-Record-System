import 'package:flutter/material.dart';

import '../config/plan_limits.dart';
import '../models/clinic.dart';
import '../services/clinic_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/clinic_dialogs.dart';
import '../widgets/page_header.dart';
import '../widgets/paywall_dialog.dart';

/// The Teams page (opened from the account menu): the clinics this account leads or
/// belongs to, creating a clinic or joining one with an invite code, the people in
/// the active clinic, and the plan's limits.
class TeamsView extends StatelessWidget {
  const TeamsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ClinicStore.instance, ProfileStore.instance]),
      builder: (context, _) {
        final store = ClinicStore.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(PageHeader.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Teams',
                subtitle: 'Your clinics and the people you work with.',
              ),
              _ClinicsCard(store: store),
              const SizedBox(height: 20),
              if (store.active != null) ...[
                _PeopleCard(clinic: store.active!),
                const SizedBox(height: 20),
              ],
              _PlanCard(store: store),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      );
}

class _ClinicsCard extends StatelessWidget {
  final ClinicStore store;
  const _ClinicsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final active = store.active;
    return _Card(
      title: 'Your clinics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final clinic in store.clinics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: clinic.id == active?.id ? AppTheme.primaryBlue.withValues(alpha: 0.06) : AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: clinic.id == active?.id ? AppTheme.primaryBlue.withValues(alpha: 0.4) : AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 20, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clinic.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, children: [
                            _Pill(clinic.role.label, clinic.role == ClinicRole.leader ? AppTheme.primaryBlue : AppTheme.textSecondary),
                            if (clinic.id == active?.id) const _Pill('Active', Color(0xFF059669)),
                          ]),
                        ],
                      ),
                    ),
                    if (clinic.id != active?.id)
                      TextButton(
                        onPressed: () => store.switchTo(clinic.id),
                        child: const Text('Switch', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create a clinic'),
                onPressed: () => showCreateClinicDialog(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_outlined, size: 18),
                label: const Text('Join with a code'),
                onPressed: () => showJoinClinicDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  final Clinic clinic;
  const _PeopleCard({required this.clinic});

  @override
  Widget build(BuildContext context) {
    final name = ProfileStore.instance.doctorName.text.trim();
    // Only this account is listed until sharing a clinic is switched on.
    const memberCount = 1;
    return _Card(
      title: 'People in ${clinic.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(ProfileStore.initialsOf(name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name.isEmpty ? 'You' : '$name (you)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
              _Pill(clinic.role.label, clinic.role == ClinicRole.leader ? AppTheme.primaryBlue : AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$memberCount of ${PlanLimits.current.maxMembersPerClinic} members',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Inviting people to share this clinic uses the cloud service, which is not switched on yet.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ClinicStore store;
  const _PlanCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final plan = PlanLimits.current;
    return _Card(
      title: '${plan.name} plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${store.createdCount} of ${plan.maxClinics} clinics created  •  up to ${plan.maxMembersPerClinic} members per clinic  •  up to ${plan.maxPatientsPerClinic} patients per clinic',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('See plans'),
            onPressed: () => showPaywallDialog(context, reason: PlanLimit.clinics),
          ),
        ],
      ),
    );
  }
}
