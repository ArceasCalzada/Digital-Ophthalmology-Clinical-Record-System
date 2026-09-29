import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ophthalmology_clinical_record_system/services/clinic_store.dart';
import 'package:ophthalmology_clinical_record_system/services/profile_store.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';
import 'package:ophthalmology_clinical_record_system/views/profile_view.dart';
import 'package:ophthalmology_clinical_record_system/views/settings_view.dart';
import 'package:ophthalmology_clinical_record_system/views/teams_view.dart';
import 'package:ophthalmology_clinical_record_system/widgets/account_menu.dart';

Future<void> pumpLayout(WidgetTester tester, {required void Function() onLogout}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: MainLayout(onLogout: onLogout)));
  await tester.pumpAndSettle();
}

final trigger = find.byKey(const ValueKey('account-menu-trigger'));

/// Whether the account card's own Material currently paints an ink highlight.
bool highlightPaints(WidgetTester tester) {
  final material = tester.renderObject(find.ancestor(of: trigger, matching: find.byType(Material)).first);
  try {
    expect(material, paints..rrect());
    return true;
  } on TestFailure {
    return false;
  }
}

/// Signs the clinic store in as a test account that has named one clinic.
Future<void> createClinic(String name) async {
  SharedPreferences.setMockInitialValues({});
  await ClinicStore.instance.load('test-user');
  await ClinicStore.instance.createClinic(name);
}

void main() {
  tearDown(() {
    ProfileStore.instance.doctorName.text = 'Dr. Sigrid Robillos, MD';
    ClinicStore.instance.resetForTesting();
  });

  testWidgets('the sidebar has no Settings tab and one line above the account card, not two', (tester) async {
    await pumpLayout(tester, onLogout: () {});

    expect(find.widgetWithText(ListTile, 'Settings'), findsNothing);
    final notificationsBottom = tester.getBottomLeft(find.text('Notifications')).dy;
    final cardTop = tester.getTopLeft(trigger).dy;
    final linesBetween = find.byType(Divider).evaluate().where((e) {
      final y = tester.getTopLeft(find.byWidget(e.widget)).dy;
      return y > notificationsBottom && y < cardTop;
    });
    expect(linesBetween, hasLength(1));
  });

  testWidgets('the card shows the name, and the clinic under it once there is one', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    expect(find.descendant(of: trigger, matching: find.text('Dr. Sigrid Robillos, MD')), findsOneWidget);
    expect(find.descendant(of: trigger, matching: find.text('Metro Eye Center')), findsNothing);

    await tester.runAsync(() => createClinic('Metro Eye Center'));
    await tester.pump();
    expect(find.descendant(of: trigger, matching: find.text('Metro Eye Center')), findsOneWidget);
  });

  testWidgets('the account card has no up/down icon and highlights on hover like the other buttons', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(trigger));
    await tester.pumpAndSettle();

    expect(highlightPaints(tester), isTrue, reason: 'hovering paints the highlight');

    await mouse.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(highlightPaints(tester), isFalse, reason: 'moving away removes it');
  });

  testWidgets('the menu shows no email or account role, and no clinic lines without a clinic', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(find.textContaining('@'), findsNothing);
    for (final role in ['Administrator', 'Physician', 'Staff']) {
      expect(find.text(role), findsNothing);
    }
    expect(find.textContaining('Clinic:'), findsNothing);
    expect(find.text('Leader'), findsNothing);
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('the menu shows the clinic and the role in it', (tester) async {
    await tester.runAsync(() => createClinic('Metro Eye Center'));
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(find.text('Clinic: Metro Eye Center'), findsOneWidget);
    expect(find.text('Leader'), findsOneWidget);
    expect(find.text('Switch clinic'), findsNothing, reason: 'only one clinic, nothing to switch to');
  });

  testWidgets('Teams in the menu opens the Teams page', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teams'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamsView), findsOneWidget);
    expect(find.text('Create a clinic'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('the card opens a menu above it with Profile, Teams, Settings and Log out', (tester) async {
    var loggedOut = false;
    await pumpLayout(tester, onLogout: () => loggedOut = true);

    expect(find.text('Log out'), findsNothing);
    final triggerTop = tester.getTopLeft(trigger).dy;

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Log out')).dy, lessThan(triggerTop), reason: 'the menu opens above the account row');

    // Tapping outside closes it without doing anything.
    await tester.tapAt(const Offset(900, 100));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsNothing);
    expect(loggedOut, isFalse);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    expect(find.text('Log out'), findsNothing, reason: 'the menu closes');
  });

  testWidgets('Settings opens the settings page, without the doctor and clinic sections', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Prescription Settings'), findsWidgets);
    expect(find.text('Doctor Profile'), findsNothing);
    expect(find.text('Clinic Information'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile opens the profile page with doctor profile and clinic information', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileView), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);

    await tester.tap(find.text('Clinic Information'));
    await tester.pumpAndSettle();
    expect(find.text('Clinic Branding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a new name on the profile page updates the sidebar card', (tester) async {
    await pumpLayout(tester, onLogout: () {});
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Dr. Sigrid Robillos, MD'), 'Dr. Ana Cruz, MD');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: trigger, matching: find.text('Dr. Ana Cruz, MD')), findsOneWidget);
  });

  test('initials skip titles and credentials', () {
    expect(ProfileStore.initialsOf('Dr. Sigrid Robillos, MD'), 'SR');
    expect(ProfileStore.initialsOf('Ana'), 'A');
    expect(ProfileStore.initialsOf('  '), '?');
    expect(roleLabel(null), isNull);
  });
}
