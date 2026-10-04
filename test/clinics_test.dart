import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/config/plan_limits.dart';
import 'package:ophthalmology_clinical_record_system/models/clinic.dart';
import 'package:ophthalmology_clinical_record_system/services/clinic_store.dart';
import 'package:ophthalmology_clinical_record_system/services/invite_code.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/calendar_page_view.dart';
import 'package:ophthalmology_clinical_record_system/views/teams_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/account_menu.dart';
import 'package:ophthalmology_clinical_record_system/widgets/clinic_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = ClinicStore.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    store.resetForTesting();
    PlanLimits.current = PlanLimits.free;
  });

  group('invite codes', () {
    test('a generated code has the DOCRS-XXXXX-XXXXX shape and reads back as itself', () {
      final code = InviteCode.generate(Random(1));
      expect(code, matches(RegExp(r'^DOCRS-[A-Z2-9]{5}-[A-Z2-9]{5}$')));
      expect(InviteCode.parse(code), code);
    });

    test('codes never use characters that are easy to misread', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final body = InviteCode.generate(rng).substring(6).replaceAll('-', '');
        expect(body, isNot(matches(RegExp(r'[01OIL]'))));
      }
    });

    test('typed codes are forgiving about case, spaces and dashes', () {
      const code = 'DOCRS-7K4MQ-92XPT';
      expect(InviteCode.parse('docrs-7k4mq-92xpt'), code);
      expect(InviteCode.parse('  7K4MQ92XPT '), code);
      expect(InviteCode.parse('docrs 7k4mq 92xpt'), code);
    });

    test('a pasted invite link gives the code inside it', () {
      const code = 'DOCRS-7K4MQ-92XPT';
      expect(InviteCode.parse('https://docrs.example.com/?join=DOCRS-7K4MQ-92XPT'), code);
      expect(InviteCode.parse('https://docrs.example.com/#/join/7K4MQ92XPT'), code);
      final link = InviteCode.linkFor(code, Uri.parse('https://docrs.example.com/app'));
      expect(link, 'https://docrs.example.com/app?join=DOCRS-7K4MQ-92XPT');
      expect(InviteCode.parse(link), code);
    });

    test('wrong length, blank and look-alike characters are rejected', () {
      expect(InviteCode.parse(''), isNull);
      expect(InviteCode.parse('DOCRS-7K4MQ'), isNull);
      expect(InviteCode.parse('DOCRS-7K4MQ-92XPTT'), isNull);
      expect(InviteCode.parse('DOCRS-7K4M0-92XPT'), isNull, reason: 'zero');
      expect(InviteCode.parse('DOCRS-7K4MI-92XPT'), isNull, reason: 'letter I');
      expect(InviteCode.parse('https://docrs.example.com/'), isNull);
    });
  });

  group('ClinicStore', () {
    test('a new account starts with no clinic', () async {
      await store.load('user-a');
      expect(store.clinics, isEmpty);
      expect(store.active, isNull);
    });

    test('creating a clinic trims the name, makes the account its leader and activates it', () async {
      await store.load('user-a');
      final clinic = await store.createClinic('  Metro Eye Center ');
      expect(clinic.name, 'Metro Eye Center');
      expect(clinic.role, ClinicRole.leader);
      expect(store.active?.id, clinic.id);
      expect(store.clinics, hasLength(1));
    });

    test('clinics are remembered per account across restarts', () async {
      await store.load('user-a');
      await store.createClinic('Metro Eye Center');
      store.unload();
      expect(store.clinics, isEmpty);

      await store.load('user-a');
      expect(store.active?.name, 'Metro Eye Center');
      expect(store.active?.role, ClinicRole.leader);

      store.unload();
      await store.load('user-b');
      expect(store.clinics, isEmpty, reason: 'another account on the same device sees none of them');
    });

    test('empty and over-long names are refused', () async {
      await store.load('user-a');
      expect(ClinicStore.nameProblem('   '), isNotNull);
      expect(ClinicStore.nameProblem('x' * 61), isNotNull);
      expect(ClinicStore.nameProblem('x' * 60), isNull);
      expect(() => store.createClinic(' '), throwsFormatException);
    });

    test('the free plan allows one clinic; a plan with more allows more, and switching works', () async {
      await store.load('user-a');
      final first = await store.createClinic('Clinic One');
      expect(store.canCreateClinic, isFalse);
      await expectLater(
        store.createClinic('Clinic Two'),
        throwsA(isA<PlanLimitException>().having((e) => e.limit, 'limit', PlanLimit.clinics)),
      );
      expect(store.clinics, hasLength(1));

      PlanLimits.current = PlanLimits.pro;
      final second = await store.createClinic('Clinic Two');
      expect(store.active?.id, second.id, reason: 'a new clinic becomes the active one');

      await store.switchTo(first.id);
      expect(store.active?.id, first.id);
      store.unload();
      await store.load('user-a');
      expect(store.active?.id, first.id, reason: 'the chosen clinic is remembered');
    });

    test('joining with a code says the cloud service is not on yet', () async {
      await expectLater(store.joinWithCode('DOCRS-7K4MQ-92XPT'), throwsA(isA<CloudUnavailableException>()));
    });

    test('the plan numbers match what was agreed', () {
      expect(PlanLimits.free.maxMembersPerClinic, 10);
      expect(PlanLimits.free.maxPatientsPerClinic, 1000);
      expect(PlanLimits.pro.maxClinics, greaterThan(PlanLimits.free.maxClinics));
      expect(PlanLimits.pro.maxPatientsPerClinic, greaterThan(1000));
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: home)));
      await tester.pumpAndSettle();
    }

    Future<void> signIn(WidgetTester tester, {String? firstClinic}) async {
      await tester.runAsync(() async {
        await store.load('user-a');
        if (firstClinic != null) await store.createClinic(firstClinic);
      });
    }

    /// A button that runs [ensureClinic] the way a "New patient" button does.
    Future<void> pumpGate(WidgetTester tester, void Function(bool) onResult) => pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await ensureClinic(context)),
              child: const Text('create something'),
            ),
          ),
        );

    testWidgets('creating something without a clinic asks for one first; a name lets it continue', (tester) async {
      bool? result;
      await signIn(tester);
      await pumpGate(tester, (r) => result = r);

      await tester.tap(find.text('create something'));
      await tester.pumpAndSettle();
      expect(find.text('Create your clinic first'), findsOneWidget);

      // An empty name is not accepted.
      await tester.tap(find.text('Create clinic'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Create your clinic first'), findsOneWidget);
      expect(store.clinics, isEmpty);

      await tester.enterText(find.byType(EditableText), 'Metro Eye Center');
      await tester.tap(find.text('Create clinic'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(store.active?.name, 'Metro Eye Center');
    });

    testWidgets('declining to create a clinic stops the action and creates nothing', (tester) async {
      bool? result;
      await signIn(tester);
      await pumpGate(tester, (r) => result = r);

      await tester.tap(find.text('create something'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(store.clinics, isEmpty);
    });

    testWidgets('with a clinic already there, nothing is asked', (tester) async {
      bool? result;
      await signIn(tester, firstClinic: 'Clinic One');
      await pumpGate(tester, (r) => result = r);

      await tester.tap(find.text('create something'));
      await tester.pumpAndSettle();
      expect(find.text('Create your clinic first'), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('the calendar\'s Add Event button asks for a clinic before opening the event form', (tester) async {
      await signIn(tester);
      await pump(tester, CalendarPageView(onSelectPatient: (_) {}));

      await tester.tap(find.text('Add Event'));
      await tester.pumpAndSettle();
      expect(find.text('Create your clinic first'), findsOneWidget);
      expect(find.text('Confirm & Save Event'), findsNothing);
    });

    testWidgets('Teams: creating a team from the dialog works', (tester) async {
      await signIn(tester, firstClinic: 'Clinic One');
      await pump(tester, const TeamsView());

      expect(find.text('Clinic One'), findsNothing);
      await tester.tap(find.text('Create a Team'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Clinic Two');
      await tester.enterText(find.byType(TextFormField).last, 'Davao City');
      await tester.tap(find.text('Create'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('Teams & Collaboration'), findsOneWidget);
    });

    testWidgets('Join dialog: searching with code', (tester) async {
      await signIn(tester, firstClinic: 'Clinic One');
      await pump(tester, const TeamsView());

      await tester.tap(find.text('Join with Code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'DOC-1234');
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
    });

    testWidgets('the account menu lists the clinics to switch between once there are two', (tester) async {
      PlanLimits.current = PlanLimits.pro;
      await signIn(tester, firstClinic: 'Clinic One');
      await tester.runAsync(() => store.createClinic('Clinic Two'));
      await pump(
        tester,
        // Like the sidebar: the card sits at the bottom of a column.
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 260, child: AccountMenuTrigger(collapsed: false, onOpenProfile: () {}, onOpenTeams: () {}, onOpenSettings: () {}, onLogout: () {})),
          ],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('account-menu-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Switch clinic'), findsOneWidget);
      expect(find.text('Clinic: Clinic Two'), findsOneWidget);

      await tester.tap(find.text('Clinic One'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(store.active?.name, 'Clinic One');
      expect(find.text('Switch clinic'), findsNothing, reason: 'the menu closes');
    });
  });
}
