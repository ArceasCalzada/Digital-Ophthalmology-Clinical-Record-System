/// Hard storage and usage limits for DOCRS.
///
/// These values are the single source of truth for the client. The same numbers
/// are enforced server-side in `firestore.rules` — if you change one, change the
/// other (see `docs/FIREBASE_SETUP.md`). The client limits give friendly errors;
/// the rules are what actually protect the Firebase bill.
class AppLimits {
  AppLimits._();

  /// Maximum number of stored patient records in the whole clinic.
  static const int maxPatients = 1000;

  /// Maximum encounters (visits) kept per patient.
  static const int maxEncountersPerPatient = 200;

  /// Maximum encounters / prescriptions across all patients (server counters).
  static const int maxEncountersTotal = 20000;
  static const int maxPrescriptionsTotal = 20000;

  /// Firestore offline cache ceiling on mobile/desktop (bytes). Web keeps no cache.
  static const int firestoreCacheBytes = 100 * 1024 * 1024;

  /// Documents a single list query may return (rules enforce `request.query.limit`).
  static const int patientListLimit = maxPatients;
  static const int subcollectionListLimit = maxEncountersPerPatient;
  static const int auxListLimit = 500;

  /// Document size budgets (Firestore stored size, bytes).
  static const int maxPatientDocBytes = 8 * 1024;
  static const int maxEncounterDocBytes = 50 * 1024;
  static const int maxPrescriptionDocBytes = 8 * 1024;
  static const int maxSmallDocBytes = 2 * 1024;

  /// Packed drawing budgets (bytes). Typical drawings pack to 2–10 KB.
  static const int maxPaperSheetDrawingBytes = 20 * 1024;
  static const int maxEyeDrawingBytes = 8 * 1024;

  /// Recent diagnoses summarised on the patient document.
  static const int maxDiagnosisSummary = 10;

  /// Maximum length of free-text fields written to Firestore (characters).
  /// Short: names, ids, acuity values. Long: complaint / diagnosis / plan.
  /// Notes: slit-lamp and fundoscopy notes, prescription notes.
  static const int maxShortTextLength = 300;
  static const int maxLongTextLength = 2000;
  static const int maxNotesLength = 1000;

  /// Maximum entries in the string lists on a patient document. Firestore rules
  /// cannot loop, so they check each element up to exactly these counts.
  static const int maxListItems = 15; // medical history, allergies
  static const int maxSummaryListItems = 10; // previous diagnoses / prescriptions

  /// Maximum medications on one prescription.
  static const int maxPrescriptionItems = 10;
}
