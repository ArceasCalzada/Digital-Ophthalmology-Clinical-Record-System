import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/follow_up_reminder.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/models/prescription.dart';
import 'package:ophthalmology_clinical_record_system/services/clinical_reminder_service.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/dashboard_screen.dart';
import 'package:ophthalmology_clinical_record_system/widgets/add_event_modal.dart';
import 'package:ophthalmology_clinical_record_system/widgets/filter_pill.dart';
import 'package:ophthalmology_clinical_record_system/widgets/follow_up_reminders_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime.now();
  final threeDaysAgo = today.subtract(const Duration(days: 3));
  final twoDaysLater = today.add(const Duration(days: 2));
  final tenDaysLater = today.add(const Duration(days: 10));

  String formatDateIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  group('FollowUpReminder Model Tests', () {
    test('Correctly computes status, labels, and colors for overdue, today, and upcoming', () {
      final overdueReminder = FollowUpReminder(
        id: 'rem-1',
        patientId: 'p-1',
        patientName: 'Eleanor Vance',
        patientMrn: 'MRN-101',
        dueDate: threeDaysAgo,
        followUpType: 'Glaucoma Evaluation',
        title: 'Glaucoma Follow-Up',
      );

      expect(overdueReminder.getStatus(), FollowUpStatus.overdue);
      expect(overdueReminder.getStatusLabel(), 'Overdue by 3 days');
      expect(overdueReminder.getStatusColor(), const Color(0xFFDC2626));
      expect(overdueReminder.daysUntilDue(), -3);

      final dueTodayReminder = FollowUpReminder(
        id: 'rem-2',
        patientId: 'p-2',
        patientName: 'Carlos Mendoza',
        patientMrn: 'MRN-102',
        dueDate: today,
        followUpType: 'Post-Op Review',
        title: 'Post-Op Cataract Evaluation',
      );

      expect(dueTodayReminder.getStatus(), FollowUpStatus.dueToday);
      expect(dueTodayReminder.getStatusLabel(), 'Due Today');
      expect(dueTodayReminder.getStatusColor(), const Color(0xFFD97706));
      expect(dueTodayReminder.daysUntilDue(), 0);

      final dueSoonReminder = FollowUpReminder(
        id: 'rem-3',
        patientId: 'p-3',
        patientName: 'Lourdes Sterling',
        patientMrn: 'MRN-103',
        dueDate: twoDaysLater,
        followUpType: 'Post-Op Review',
        title: 'Cataract Corneal Check',
      );

      expect(dueSoonReminder.getStatus(), FollowUpStatus.dueSoon);
      expect(dueSoonReminder.getStatusLabel(), 'Due in 2 days');
      expect(dueSoonReminder.getStatusColor(), const Color(0xFF2563EB));

      final upcomingReminder = FollowUpReminder(
        id: 'rem-4',
        patientId: 'p-4',
        patientName: 'Arthur Pendelton',
        patientMrn: 'MRN-104',
        dueDate: tenDaysLater,
        followUpType: 'Annual Eye Exam',
        title: 'Diabetic Retinopathy Screening',
      );

      expect(upcomingReminder.getStatus(), FollowUpStatus.upcoming);
      expect(upcomingReminder.getStatusLabel(), 'Due in 10 days');
    });
  });

  group('ClinicalReminderService Date Parsing & Scanning Logic', () {
    test('parseFollowUpDate handles ISO format, relative terms, and human dates', () {
      final isoParsed = ClinicalReminderService.parseFollowUpDate('2026-11-20');
      expect(isoParsed, isNotNull);
      expect(isoParsed!.year, 2026);
      expect(isoParsed.month, 11);
      expect(isoParsed.day, 20);

      // Relative terms
      final twoWeeks = ClinicalReminderService.parseFollowUpDate(
        'In 2 weeks',
        referenceDate: '2026-11-01',
      );
      expect(twoWeeks, isNotNull);
      expect(twoWeeks!.day, 15);
      expect(twoWeeks.month, 11);

      final threeDays = ClinicalReminderService.parseFollowUpDate(
        '3 days',
        referenceDate: '2026-11-01',
      );
      expect(threeDays, isNotNull);
      expect(threeDays!.day, 4);

      // Human date formats
      final humanDateA = ClinicalReminderService.parseFollowUpDate('November 25, 2026');
      expect(humanDateA, isNotNull);
      expect(humanDateA!.year, 2026);
      expect(humanDateA.month, 11);
      expect(humanDateA.day, 25);

      final humanDateB = ClinicalReminderService.parseFollowUpDate('18 Dec 2026');
      expect(humanDateB, isNotNull);
      expect(humanDateB!.year, 2026);
      expect(humanDateB.month, 12);
      expect(humanDateB.day, 18);

      // Invalid strings return null
      expect(ClinicalReminderService.parseFollowUpDate(''), isNull);
      expect(ClinicalReminderService.parseFollowUpDate('_________________'), isNull);
      expect(ClinicalReminderService.parseFollowUpDate('as needed PRN'), isNull);
    });

    test('Aggregates prescription follow-ups and links scheduled calendar events', () async {
      PatientRepository.clearForTesting();
      ClinicalReminderService.instance.clearForTesting();

      final overdueRx = Prescription(
        id: 'rx-overdue',
        patientId: 'patient-test-1',
        encounterId: 'enc-1',
        doctorName: 'Dr. Robillos',
        date: formatDateIso(threeDaysAgo.subtract(const Duration(days: 14))),
        items: [
          PrescriptionItem(
            id: 'item-1',
            medicationName: 'Latanoprost 0.005%',
            strength: '0.005%',
            dosage: '1 drop',
            frequency: 'QHS',
            duration: '30 days',
            instructions: '1 drop OU',
          ),
        ],
        followUpDate: formatDateIso(threeDaysAgo),
        notes: 'Glaucoma pressure evaluation review',
      );

      final scheduledRx = Prescription(
        id: 'rx-scheduled',
        patientId: 'patient-test-2',
        encounterId: 'enc-2',
        doctorName: 'Dr. Robillos',
        date: formatDateIso(today),
        items: [
          PrescriptionItem(
            id: 'item-2',
            medicationName: 'Prednisolone acetate',
            strength: '1%',
            dosage: '1 drop',
            frequency: 'QID',
            duration: '14 days',
            instructions: 'Post-op drops',
          ),
        ],
        followUpDate: formatDateIso(twoDaysLater),
        notes: 'Post-op cataract clarity inspection',
      );

      final patient1 = Patient(
        id: 'patient-test-1',
        mrn: 'MRN-TEST-1',
        fullName: 'Eleanor Vance',
        dateOfBirth: '1970-01-01',
        gender: 'Female',
        phone: '09171234567',
        address: 'Davao',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        prescriptions: [overdueRx],
        previousDiagnoses: ['Primary Open-Angle Glaucoma'],
      );

      final patient2 = Patient(
        id: 'patient-test-2',
        mrn: 'MRN-TEST-2',
        fullName: 'Carlos Test-Mendoza',
        dateOfBirth: '1965-05-12',
        gender: 'Male',
        phone: '09189876543',
        address: 'Bukidnon',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        prescriptions: [scheduledRx],
        previousDiagnoses: ['Senile Cataract OD, Post-Op Day 1'],
      );

      PatientRepository.addPatient(patient1);
      PatientRepository.addPatient(patient2);

      // Book an appointment for patient 2 on twoDaysLater
      final bookedEvent = CalendarEvent(
        id: 'evt-booked-carlos',
        title: 'Post-Op Cataract Check',
        eventType: 'Follow-up',
        location: 'Bukidnon',
        dateTime: twoDaysLater,
        patientName: 'Carlos Test-Mendoza',
        patientId: 'patient-test-2',
      );
      CalendarEventRepository().addEvent(bookedEvent);

      final service = ClinicalReminderService.instance;
      await service.runScheduledCheck();

      // Check results
      expect(service.reminders.isNotEmpty, isTrue);

      final overdueReminder = service.reminders.firstWhere((r) => r.patientId == 'patient-test-1');
      expect(overdueReminder.getStatus(), FollowUpStatus.overdue);
      expect(overdueReminder.isScheduled, isFalse); // Needs scheduling!
      expect(overdueReminder.followUpType, 'Glaucoma Evaluation');

      final scheduledReminder = service.reminders.firstWhere((r) => r.patientId == 'patient-test-2');
      expect(scheduledReminder.getStatus(), FollowUpStatus.dueSoon);
      expect(scheduledReminder.isScheduled, isTrue); // Appointment is booked!
      expect(scheduledReminder.linkedCalendarEventId, 'evt-booked-carlos');
      expect(scheduledReminder.followUpType, 'Post-Op Review');

      // Check that automated clinical notifications were posted for overdue item
      final notifications = ClinicalNotificationRepository().notifications;
      final overdueNotif = notifications.firstWhere(
        (n) => n.id == 'notif-followup-rx-patient-test-1-rx-overdue',
      );
      expect(overdueNotif.severity, NotificationSeverity.urgent);
      expect(overdueNotif.category, 'Reminder');
      expect(overdueNotif.message.contains('No return appointment has been booked yet'), isTrue);
    });
  });

  group('FollowUpRemindersWidget & Dashboard UI Tests', () {
    testWidgets('FollowUpRemindersWidget displays reminder queue with badges, filters, and actions', (tester) async {
      PatientRepository.clearForTesting();
      CalendarEventRepository().deleteEvent('evt-booked-carlos');
      ClinicalReminderService.instance.clearForTesting();

      final overduePatient = Patient(
        id: 'p-ui-1',
        mrn: 'MRN-UI-1',
        fullName: 'Roberto Garcia',
        dateOfBirth: '1975-03-10',
        gender: 'Male',
        phone: '09170001111',
        address: 'Davao City',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        prescriptions: [
          Prescription(
            id: 'rx-roberto',
            patientId: 'p-ui-1',
            encounterId: 'enc-r',
            doctorName: 'Dr. Robillos',
            date: formatDateIso(threeDaysAgo.subtract(const Duration(days: 7))),
            items: [
              PrescriptionItem(
                id: 'i-1',
                medicationName: 'Brimonidine',
                strength: '0.2%',
                dosage: '1 drop',
                frequency: 'BID',
                duration: '30 days',
                instructions: 'OU',
              ),
            ],
            followUpDate: formatDateIso(threeDaysAgo),
            notes: 'Glaucoma follow-up evaluation',
          ),
        ],
      );

      final dueTodayPatient = Patient(
        id: 'p-ui-2',
        mrn: 'MRN-UI-2',
        fullName: 'Maria Santos',
        dateOfBirth: '1982-11-22',
        gender: 'Female',
        phone: '09172223333',
        address: 'Bukidnon',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        prescriptions: [
          Prescription(
            id: 'rx-maria',
            patientId: 'p-ui-2',
            encounterId: 'enc-m',
            doctorName: 'Dr. Robillos',
            date: formatDateIso(today.subtract(const Duration(days: 7))),
            items: [
              PrescriptionItem(
                id: 'i-2',
                medicationName: 'Vigamox',
                strength: '0.5%',
                dosage: '1 drop',
                frequency: 'TID',
                duration: '7 days',
                instructions: 'OD',
              ),
            ],
            followUpDate: formatDateIso(today),
            notes: 'Post-op cataract checkup',
          ),
        ],
      );

      PatientRepository.addPatient(overduePatient);
      PatientRepository.addPatient(dueTodayPatient);

      await ClinicalReminderService.instance.runScheduledCheck();

      Patient? selectedPatient;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FollowUpRemindersWidget(
                onSelectPatient: (p) => selectedPatient = p,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Widget exists and shows header
      expect(find.byKey(const Key('follow_up_reminders_widget')), findsOneWidget);
      expect(find.text('Patient Follow-Up & Return Queue'), findsOneWidget);

      // Verify both patients appear in the list
      expect(find.text('Roberto Garcia'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);

      // Verify status pills
      expect(find.text('Overdue by 3 days'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('reminder_card_rx-p-ui-2-rx-maria')),
          matching: find.text('Due Today'),
        ),
        findsOneWidget,
      );

      // Verify "Needs Scheduling" badge is visible
      expect(find.text('Needs Scheduling'), findsWidgets);

      // Test "View Chart" quick action for Roberto Garcia
      final viewChartBtn = find.byKey(const Key('btn_view_chart_rx-p-ui-1-rx-roberto'));
      expect(viewChartBtn, findsOneWidget);
      await tester.tap(viewChartBtn);
      await tester.pumpAndSettle();
      expect(selectedPatient?.fullName, 'Roberto Garcia');

      // Test filter pills: Click "Due Today" filter
      await tester.tap(find.byWidgetPredicate((w) => w is FilterPill && w.label.startsWith('Due Today')));
      await tester.pumpAndSettle();

      // Only Maria Santos should be shown under Due Today filter
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Roberto Garcia'), findsNothing);

      // Click "All" filter
      await tester.tap(find.byWidgetPredicate((w) => w is FilterPill && w.label.startsWith('All')));
      await tester.pumpAndSettle();
      expect(find.text('Roberto Garcia'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders reminder alert banner and follow-up queue widget', (tester) async {
      PatientRepository.clearForTesting();
      ClinicalReminderService.instance.clearForTesting();

      final patient = Patient(
        id: 'p-dash-1',
        mrn: 'MRN-DASH-1',
        fullName: 'Elena Rostova',
        dateOfBirth: '1985-06-15',
        gender: 'Female',
        phone: '09178889999',
        address: 'Davao City',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        prescriptions: [
          Prescription(
            id: 'rx-dash',
            patientId: 'p-dash-1',
            encounterId: 'enc-dash',
            doctorName: 'Dr. Robillos',
            date: formatDateIso(threeDaysAgo.subtract(const Duration(days: 14))),
            items: [
              PrescriptionItem(
                id: 'i-d',
                medicationName: 'Latanoprost',
                strength: '0.005%',
                dosage: '1 drop',
                frequency: 'QHS',
                duration: '30 days',
                instructions: 'OU',
              ),
            ],
            followUpDate: formatDateIso(threeDaysAgo),
            notes: 'Glaucoma follow-up',
          ),
        ],
      );

      PatientRepository.addPatient(patient);
      await ClinicalReminderService.instance.runScheduledCheck();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the reminder alert banner appears on Dashboard
      expect(find.byKey(const Key('dashboard_reminder_alert_banner')), findsOneWidget);
      expect(find.textContaining('1 overdue follow-up'), findsOneWidget);

      // Verify the FollowUpRemindersWidget appears on Dashboard
      expect(find.byKey(const Key('follow_up_reminders_widget')), findsOneWidget);
      expect(find.text('Elena Rostova'), findsWidgets);

      // Test "Schedule Visit" quick action opens the AddEventModal
      final scheduleBtn = find.byKey(const Key('btn_schedule_rx-p-dash-1-rx-dash'));
      expect(scheduleBtn, findsOneWidget);
      await tester.ensureVisible(scheduleBtn);
      await tester.tap(scheduleBtn);
      await tester.pumpAndSettle();

      // AddEventModal should be open with patient pre-selected
      expect(find.byType(AddEventModal), findsOneWidget);
      expect(find.text('Add Clinical Event'), findsOneWidget);
    });
  });
}
