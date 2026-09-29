import 'app_limits.dart';

/// What each thing the plan can be limited on.
enum PlanLimit { clinics, members, patients }

/// The numbers a subscription plan allows.
///
/// TEMPLATE ONLY: there is no billing yet, so every account is on [free] and the
/// [pro] numbers are placeholders for the paywall screen. The server rules still
/// enforce [AppLimits.maxPatients] for everyone; raising it for [pro] means
/// changing `firestore.rules` too.
class PlanLimits {
  final String name;

  /// Clinics one account may create (clinics joined through an invite don't count).
  final int maxClinics;
  final int maxMembersPerClinic;
  final int maxPatientsPerClinic;

  const PlanLimits({
    required this.name,
    required this.maxClinics,
    required this.maxMembersPerClinic,
    required this.maxPatientsPerClinic,
  });

  static const free = PlanLimits(
    name: 'Free',
    maxClinics: 1,
    maxMembersPerClinic: 10,
    maxPatientsPerClinic: AppLimits.maxPatients,
  );

  static const pro = PlanLimits(
    name: 'Pro',
    maxClinics: 10,
    maxMembersPerClinic: 50,
    maxPatientsPerClinic: 10000,
  );

  /// The plan in force for the signed-in account.
  static PlanLimits current = free;

  int allowed(PlanLimit limit) => switch (limit) {
        PlanLimit.clinics => maxClinics,
        PlanLimit.members => maxMembersPerClinic,
        PlanLimit.patients => maxPatientsPerClinic,
      };
}

/// Thrown when an action would go past [limit] on the current plan.
class PlanLimitException implements Exception {
  final PlanLimit limit;
  final int allowed;
  const PlanLimitException(this.limit, this.allowed);

  @override
  String toString() => switch (limit) {
        PlanLimit.clinics => 'Your plan allows $allowed clinic${allowed == 1 ? '' : 's'}.',
        PlanLimit.members => 'Your plan allows $allowed members per clinic.',
        PlanLimit.patients => 'Your plan allows $allowed patient records per clinic.',
      };
}
