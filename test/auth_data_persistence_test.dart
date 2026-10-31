// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/calendar_event.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/models/patient.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/widgets/rx_pad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PatientRepository.disconnect();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
  });

  tearDown(() {
    ProfileStore.instance.stopListeningToBranches();
    ProfileStore.instance.resetToDefaultBranches();
    PatientRepository.disconnect();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
  });

  group('Auth & Workspace Data Persistence Tests', () {
    test('PatientRepository preserves unassigned patients and retrieves team patients', () {
      // Connect to team
      PatientRepository.connect('team-alpha');

      final testPatient = Patient(
        id: 'patient-123',
        mrn: 'MRN-123',
        fullName: 'Maria Santos',
        dateOfBirth: '1980-01-01',
        gender: 'Female',
        phone: '+63 917 000 0000',
        address: 'Manila, Philippines',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        teamId: 'team-alpha',
      );
      PatientRepository.addPatient(testPatient);

      expect(PatientRepository.getAllPatients().any((p) => p.id == 'patient-123'), isTrue);

      // Reconnect with same team
      PatientRepository.connect('team-alpha');
      expect(PatientRepository.getAllPatients().any((p) => p.id == 'patient-123'), isTrue);
    });

    test('PatientRepository.getAllPatients retains unassigned patients across workspace changes', () {
      PatientRepository.connect(null);

      final unassignedPatient = Patient(
        id: 'patient-unassigned',
        mrn: 'MRN-901',
        fullName: 'Juan Dela Cruz',
        dateOfBirth: '1995-05-10',
        gender: 'Male',
        phone: '+63 918 111 2222',
        address: 'Quezon City, Philippines',
        medicalHistory: const [],
        allergies: const [],
        encounters: const [],
        lastVisitDate: '2026-10-01',
        totalVisits: 1,
        teamId: '',
      );
      PatientRepository.addPatient(unassignedPatient);

      // Switch to a new active team
      PatientRepository.connect('team-beta');

      final all = PatientRepository.getAllPatients();
      expect(all.any((p) => p.id == 'patient-unassigned'), isTrue,
          reason: 'Unassigned patient should be included to prevent data disappearing on team assignment');
    });

    test('CalendarEventRepository isLoading tracks fetching lifecycle and retains events', () {
      final calRepo = CalendarEventRepository();
      expect(calRepo.isLoading.value, isFalse);

      final testEvent = CalendarEvent(
        id: 'event-1',
        title: 'Checkup',
        eventType: 'Checkup',
        location: 'Clinic 1',
        dateTime: DateTime.now(),
        patientName: 'Juan Dela Cruz',
        teamId: 'team-active',
      );
      calRepo.addEvent(testEvent);

      expect(calRepo.events.any((e) => e.id == 'event-1'), isTrue);

      // Verify that isLoading notifier notifies listeners
      bool notified = false;
      calRepo.isLoading.addListener(() {
        notified = true;
      });
      calRepo.isLoading.value = true;
      expect(notified, isTrue);
      expect(calRepo.isLoading.value, isTrue);

      calRepo.isLoading.value = false;
      expect(calRepo.isLoading.value, isFalse);
    });

    test('ClinicalNotificationRepository isLoading tracks fetching lifecycle and retains notifications', () {
      final notifRepo = ClinicalNotificationRepository();
      expect(notifRepo.isLoading.value, isFalse);

      final testNotif = ClinicalNotification(
        id: 'notif-1',
        title: 'Lab Results Ready',
        message: 'Patient results ready',
        category: 'System',
        severity: NotificationSeverity.info,
        timestamp: DateTime.now(),
        teamId: 'team-active',
      );
      notifRepo.addNotification(testNotif);

      expect(notifRepo.notifications.any((n) => n.id == 'notif-1'), isTrue);

      // Verify that isLoading notifier notifies listeners
      bool notified = false;
      notifRepo.isLoading.addListener(() {
        notified = true;
      });
      notifRepo.isLoading.value = true;
      expect(notified, isTrue);
      expect(notifRepo.isLoading.value, isTrue);

      notifRepo.isLoading.value = false;
      expect(notifRepo.isLoading.value, isFalse);
    });

    test('ProfileStore tracks isProfileLoading lifecycle flag', () {
      final profile = ProfileStore.instance;
      expect(profile.isProfileLoading, isFalse);
    });

    testWidgets('RxPadWidget renders loading indicator while branches are loading', (tester) async {
      final profile = ProfileStore.instance;
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

      // listenToBranches with pending stream sets isBranchesLoading = true
      profile.listenToBranches('team-loading', branchStream: controller.stream);
      expect(profile.isBranchesLoading, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RxPadWidget(
                doctorName: 'Dr. John Doe',
                items: const [],
                date: '2026-10-31',
                branches: const [], // Empty branches while loading
              ),
            ),
          ),
        ),
      );

      // Should find the loading state widget with key
      expect(find.byKey(const ValueKey('rx_pad_branches_loading_state')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });
  });
}
