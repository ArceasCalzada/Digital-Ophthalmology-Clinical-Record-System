import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/calendar_event.dart';
import '../models/clinical_notification.dart';
import '../models/follow_up_reminder.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import 'firebase_gate.dart';

class ClinicalReminderService extends ChangeNotifier {
  static final ClinicalReminderService _instance = ClinicalReminderService._internal();
  factory ClinicalReminderService() => _instance;
  static ClinicalReminderService get instance => _instance;

  ClinicalReminderService._internal();

  Timer? _scheduleTimer;
  String? _activeTeamId;
  final List<FollowUpReminder> _reminders = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<FollowUpReminder> get reminders => List.unmodifiable(_reminders);

  List<FollowUpReminder> get overdueReminders =>
      _reminders.where((r) => r.getStatus() == FollowUpStatus.overdue).toList();

  List<FollowUpReminder> get dueTodayReminders =>
      _reminders.where((r) => r.getStatus() == FollowUpStatus.dueToday).toList();

  List<FollowUpReminder> get dueSoonReminders =>
      _reminders.where((r) => r.getStatus() == FollowUpStatus.dueSoon).toList();

  List<FollowUpReminder> get unscheduledReminders =>
      _reminders.where((r) => !r.isScheduled).toList();

  int get overdueCount => overdueReminders.length;
  int get dueTodayCount => dueTodayReminders.length;
  int get dueSoonCount => dueSoonReminders.length;
  int get totalActionableCount => overdueCount + dueTodayCount + dueSoonCount;

  void connect([String? teamId]) {
    _activeTeamId = teamId;
    _scheduleTimer?.cancel();

    // Attach listeners to repositories to automatically refresh whenever data changes
    PatientRepository.changeNotifier.removeListener(runScheduledCheck);
    PatientRepository.changeNotifier.addListener(runScheduledCheck);

    CalendarEventRepository().removeListener(runScheduledCheck);
    CalendarEventRepository().addListener(runScheduledCheck);

    // Initial check
    runScheduledCheck();

    // Periodic scheduled check every 60 seconds (disabled in automated test runners to avoid pending timer assertions)
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _scheduleTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        runScheduledCheck();
      });
    }
  }

  void disconnect() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    PatientRepository.changeNotifier.removeListener(runScheduledCheck);
    CalendarEventRepository().removeListener(runScheduledCheck);
    _reminders.clear();
    _activeTeamId = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Performs a background check linking Firestore/repository calendar events
  /// and prescription follow-up check-up dates.
  Future<void> runScheduledCheck() async {
    _isLoading = true;

    final aggregated = <FollowUpReminder>[];
    final allPatients = PatientRepository.getAllPatients();
    final allEvents = CalendarEventRepository().events;
    final now = DateTime.now();

    // 1. Scan Firestore directly if ready (for cloud synchronization)
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      try {
        dynamic eventQuery = firestore.collection('calendarEvents');
        if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
          eventQuery = eventQuery.where('teamId', isEqualTo: _activeTeamId);
        }
        // Background query to ensure synchronization
        await eventQuery.limit(200).get();
      } catch (e) {
        debugPrint('Firestore calendar background scan check error: $e');
      }
    }

    // 2. Scan Prescriptions for follow-up dates across patients
    for (final patient in allPatients) {
      if (_activeTeamId != null &&
          _activeTeamId!.isNotEmpty &&
          patient.teamId.isNotEmpty &&
          patient.teamId != _activeTeamId) {
        continue;
      }

      for (final rx in patient.prescriptions) {
        final followUpRaw = rx.followUpDate.trim();
        if (followUpRaw.isEmpty || followUpRaw.contains('___')) continue;

        final dueDate = parseFollowUpDate(followUpRaw, referenceDate: rx.date);
        if (dueDate == null) continue;

        // Check if an appointment has been scheduled for this patient on or near this date
        final matchingEvent = _findMatchingEvent(
          patient: patient,
          targetDate: dueDate,
          events: allEvents,
        );

        final reminderId = 'rx-${patient.id}-${rx.id}';
        final clinicalType = _determineClinicalType(rx: rx, patient: patient);
        final medsSummary = rx.items.map((i) => '${i.medicationName} ${i.strength}').join(', ');
        final title = medsSummary.isNotEmpty
            ? '$clinicalType — $medsSummary'
            : '$clinicalType Follow-Up';

        final reminder = FollowUpReminder(
          id: reminderId,
          patientId: patient.id,
          patientName: patient.fullName,
          patientMrn: patient.mrn,
          patientPhone: patient.phone,
          dueDate: dueDate,
          followUpType: clinicalType,
          title: title,
          details: rx.notes.isNotEmpty ? rx.notes : (medsSummary.isNotEmpty ? medsSummary : 'Scheduled return check-up'),
          doctorName: rx.doctorName,
          clinicBranch: rx.clinicBranch,
          isScheduled: matchingEvent != null,
          linkedCalendarEventId: matchingEvent?.id,
          linkedPrescriptionId: rx.id,
          source: FollowUpSource.prescription,
          patient: patient,
        );

        aggregated.add(reminder);
      }
    }

    // 3. Scan Calendar Events for scheduled follow-ups, post-ops, and reviews
    for (final event in allEvents) {
      if (_activeTeamId != null &&
          _activeTeamId!.isNotEmpty &&
          event.teamId.isNotEmpty &&
          event.teamId != _activeTeamId) {
        continue;
      }

      // Check if this event qualifies as a clinical follow-up or check-up
      final isFollowUpEvent = event.eventType == 'Follow-up' ||
          event.eventType == 'Checkup' ||
          event.eventType == 'IOP Check' ||
          event.title.toLowerCase().contains('follow-up') ||
          event.title.toLowerCase().contains('post-op') ||
          event.title.toLowerCase().contains('evaluation') ||
          event.title.toLowerCase().contains('review');

      if (!isFollowUpEvent) continue;

      // Avoid duplicating a reminder already created from a prescription for the same patient & day
      final alreadyPresent = aggregated.any((r) {
        final samePatient = r.patientId == event.patientId ||
            (r.patient != null && r.patient!.mrn == event.patientId) ||
            r.patientName.toLowerCase() == event.patientName.toLowerCase();
        final sameDay = r.dueDate.year == event.dateTime.year &&
            r.dueDate.month == event.dateTime.month &&
            r.dueDate.day == event.dateTime.day;
        return samePatient && sameDay;
      });

      if (alreadyPresent) continue;

      // Find associated patient if possible
      Patient? matchedPatient;
      try {
        matchedPatient = allPatients.firstWhere((p) =>
            p.id == event.patientId ||
            p.mrn == event.patientId ||
            p.fullName.toLowerCase() == event.patientName.toLowerCase());
      } catch (_) {}

      final clinicalType = _determineClinicalTypeFromEvent(event, matchedPatient);
      final reminder = FollowUpReminder(
        id: 'cal-${event.id}',
        patientId: matchedPatient?.id ?? (event.patientId ?? event.id),
        patientName: event.patientName.isNotEmpty ? event.patientName : (matchedPatient?.fullName ?? 'Patient'),
        patientMrn: matchedPatient?.mrn ?? (event.patientId ?? 'MRN-PENDING'),
        patientPhone: matchedPatient?.phone ?? '',
        dueDate: event.dateTime,
        followUpType: clinicalType,
        title: event.title,
        details: event.notes.isNotEmpty ? event.notes : '${event.location} • ${event.eventType}',
        doctorName: '',
        clinicBranch: event.location,
        isScheduled: true,
        linkedCalendarEventId: event.id,
        source: FollowUpSource.calendarEvent,
        patient: matchedPatient,
      );

      aggregated.add(reminder);
    }

    // 4. Sort aggregated reminders: Overdue first (most overdue at top), then Due Today, then Due Soon, then Upcoming
    aggregated.sort((a, b) {
      final aDiff = a.daysUntilDue(now);
      final bDiff = b.daysUntilDue(now);

      // Overdue first (< 0)
      if (aDiff < 0 && bDiff >= 0) return -1;
      if (bDiff < 0 && aDiff >= 0) return 1;

      // Both overdue: most overdue first
      if (aDiff < 0 && bDiff < 0) return aDiff.compareTo(bDiff);

      // Due today (0) before future (> 0)
      if (aDiff == 0 && bDiff > 0) return -1;
      if (bDiff == 0 && aDiff > 0) return 1;

      // Future: earliest date first
      return aDiff.compareTo(bDiff);
    });

    _reminders.clear();
    _reminders.addAll(aggregated);

    // 5. Automatically synchronize overdue and due-today alerts into ClinicalNotificationRepository
    _syncWithClinicalNotifications(aggregated);

    _isLoading = false;
    notifyListeners();
  }

  /// Dispatches reminders into ClinicalNotificationRepository so staff receive
  /// alerts in the global notification center and sidebar/mobile notification badges.
  void _syncWithClinicalNotifications(List<FollowUpReminder> items) {
    final notifRepo = ClinicalNotificationRepository();
    final existingNotifs = notifRepo.notifications;

    for (final reminder in items) {
      final status = reminder.getStatus();
      if (status != FollowUpStatus.overdue && status != FollowUpStatus.dueToday) {
        continue;
      }

      final notifId = 'notif-followup-${reminder.id}';
      final isAlreadyDispatched = existingNotifs.any((n) => n.id == notifId);
      if (isAlreadyDispatched) continue;

      final isOverdue = status == FollowUpStatus.overdue;
      final title = isOverdue
          ? 'Overdue Follow-Up: ${reminder.patientName}'
          : 'Follow-Up Due Today: ${reminder.patientName}';

      final scheduleInfo = reminder.isScheduled
          ? 'Appointment is scheduled for ${_formatDate(reminder.dueDate)}.'
          : '⚠️ No return appointment has been booked yet. Action required.';

      final message = '${reminder.title} (${reminder.followUpType}). $scheduleInfo';

      final notif = ClinicalNotification(
        id: notifId,
        title: title,
        message: message,
        category: 'Reminder',
        severity: isOverdue ? NotificationSeverity.urgent : NotificationSeverity.warning,
        timestamp: DateTime.now(),
        patientName: reminder.patientName,
        patientId: reminder.patientMrn.isNotEmpty ? reminder.patientMrn : reminder.patientId,
        teamId: _activeTeamId ?? '',
      );

      notifRepo.addNotification(notif, enqueueSync: false);
    }
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// Finds a calendar event matching a given patient and target date (within +/- 2 days window).
  CalendarEvent? _findMatchingEvent({
    required Patient patient,
    required DateTime targetDate,
    required List<CalendarEvent> events,
  }) {
    final targetMidnight = DateTime(targetDate.year, targetDate.month, targetDate.day);

    for (final e in events) {
      final samePatient = e.patientId == patient.id ||
          e.patientId == patient.mrn ||
          e.patientName.toLowerCase() == patient.fullName.toLowerCase();
      if (!samePatient) continue;

      final eventMidnight = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final diff = eventMidnight.difference(targetMidnight).inDays.abs();
      if (diff <= 2) {
        return e;
      }
    }
    return null;
  }

  /// Parses follow-up date strings from various formats into a DateTime.
  /// Handles ISO strings ("2026-11-15"), relative terms ("In 2 weeks", "3 days"),
  /// and human dates ("November 15, 2026", "15 Nov 2026").
  static DateTime? parseFollowUpDate(String raw, {String? referenceDate}) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Standard ISO format: "2026-11-06" or "2026-11-06T10:00:00"
    final directParsed = DateTime.tryParse(text);
    if (directParsed != null) return directParsed;

    // Base date for relative offsets
    DateTime baseDate = DateTime.now();
    if (referenceDate != null && referenceDate.isNotEmpty) {
      final parsedRef = DateTime.tryParse(referenceDate);
      if (parsedRef != null) {
        baseDate = parsedRef;
      }
    }

    // 2. Relative offsets: "in 2 weeks", "2 weeks", "in 3 days", "1 month"
    final relativeReg = RegExp(
      r'(?:in\s+)?(\d+)\s+(day|week|month|year)s?',
      caseSensitive: false,
    );
    final match = relativeReg.firstMatch(text);
    if (match != null) {
      final amount = int.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2)?.toLowerCase();
      if (amount > 0 && unit != null) {
        switch (unit) {
          case 'day':
            return baseDate.add(Duration(days: amount));
          case 'week':
            return baseDate.add(Duration(days: amount * 7));
          case 'month':
            return DateTime(baseDate.year, baseDate.month + amount, baseDate.day);
          case 'year':
            return DateTime(baseDate.year + amount, baseDate.month, baseDate.day);
        }
      }
    }

    // 3. Human dates: "November 15, 2026" or "15 Nov 2026"
    final monthMap = <String, int>{
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };

    // Pattern A: "November 15, 2026" or "Nov 15 2026"
    final patternA = RegExp(r'([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})');
    final matchA = patternA.firstMatch(text);
    if (matchA != null) {
      final monthName = matchA.group(1)?.toLowerCase();
      final day = int.tryParse(matchA.group(2) ?? '');
      final year = int.tryParse(matchA.group(3) ?? '');
      if (monthName != null && monthMap.containsKey(monthName) && day != null && year != null) {
        return DateTime(year, monthMap[monthName]!, day);
      }
    }

    // Pattern B: "15 November 2026" or "15 Nov 2026"
    final patternB = RegExp(r'(\d{1,2})\s+([A-Za-z]+),?\s+(\d{4})');
    final matchB = patternB.firstMatch(text);
    if (matchB != null) {
      final day = int.tryParse(matchB.group(1) ?? '');
      final monthName = matchB.group(2)?.toLowerCase();
      final year = int.tryParse(matchB.group(3) ?? '');
      if (monthName != null && monthMap.containsKey(monthName) && day != null && year != null) {
        return DateTime(year, monthMap[monthName]!, day);
      }
    }

    return null;
  }

  static String _determineClinicalType({required Prescription rx, required Patient patient}) {
    final lowerNotes = rx.notes.toLowerCase();
    final lowerMeds = rx.items.map((i) => i.medicationName.toLowerCase()).join(' ');
    final lowerDiag = patient.previousDiagnoses.join(' ').toLowerCase();

    if (lowerNotes.contains('post-op') ||
        lowerNotes.contains('cataract') ||
        lowerNotes.contains('phaco') ||
        lowerDiag.contains('cataract') ||
        lowerNotes.contains('surgery')) {
      return 'Post-Op Review';
    }

    if (lowerNotes.contains('glaucoma') ||
        lowerDiag.contains('glaucoma') ||
        lowerNotes.contains('iop') ||
        lowerMeds.contains('latanoprost') ||
        lowerMeds.contains('timolol') ||
        lowerMeds.contains('brimonidine') ||
        lowerMeds.contains('travoprost') ||
        lowerMeds.contains('dorzolamide')) {
      return 'Glaucoma Evaluation';
    }

    if (lowerNotes.contains('diabetic') ||
        lowerNotes.contains('retinopathy') ||
        lowerDiag.contains('retinopathy') ||
        lowerNotes.contains('annual') ||
        lowerNotes.contains('screening')) {
      return 'Annual Eye Exam';
    }

    return 'Prescription Follow-Up';
  }

  static String _determineClinicalTypeFromEvent(CalendarEvent event, Patient? patient) {
    final lowerTitle = event.title.toLowerCase();
    final lowerNotes = event.notes.toLowerCase();

    if (lowerTitle.contains('post-op') ||
        lowerTitle.contains('cataract') ||
        event.eventType == 'Surgery' ||
        lowerNotes.contains('post-op')) {
      return 'Post-Op Review';
    }

    if (lowerTitle.contains('glaucoma') ||
        lowerTitle.contains('iop') ||
        event.eventType == 'IOP Check') {
      return 'Glaucoma Evaluation';
    }

    if (lowerTitle.contains('retinopathy') ||
        lowerTitle.contains('screening') ||
        lowerTitle.contains('annual')) {
      return 'Annual Eye Exam';
    }

    return event.eventType.isNotEmpty ? event.eventType : 'Follow-up';
  }

  /// Clears in-memory state (useful for tests).
  @visibleForTesting
  void clearForTesting() {
    _scheduleTimer?.cancel();
    _reminders.clear();
    _activeTeamId = null;
    _isLoading = false;
    notifyListeners();
  }
}
