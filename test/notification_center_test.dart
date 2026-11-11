import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/models/clinical_notification.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/notification_center_view.dart';

void main() {
  testWidgets('Opening the notification center marks everything read, with no per-card actions or icons', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = ClinicalNotificationRepository();
    repo.seedDefaultNotificationsForTesting();
    expect(repo.unreadCount, greaterThan(0));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const NotificationCenterView()),
    );
    await tester.pumpAndSettle();
    // Each queued change starts a short offline-sync delay; let it finish.
    await tester.pump(const Duration(seconds: 1));

    expect(repo.unreadCount, 0);

    expect(find.text('Mark Read'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);

    // Header has the notification bell and close 'X' icon; cards carry no icons.
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byKey(const Key('notification_center_close_button')), findsOneWidget);
  });

  testWidgets('Clicking header close icon invokes onClose callback', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationCenterView(
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final closeButtonFinder = find.byKey(const Key('notification_center_close_button'));
    expect(closeButtonFinder, findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('Pressing Escape key closes the modal via keyboard shortcut', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationCenterView(
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('Close icon dismisses modal dialog when popped via Navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    child: NotificationCenterView(
                      onClose: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                );
              },
              child: const Text('Open Alerts'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Clinical Alerts & Notifications'), findsOneWidget);
    expect(find.byKey(const Key('notification_center_close_button')), findsOneWidget);

    // Dismiss using close button
    await tester.tap(find.byKey(const Key('notification_center_close_button')));
    await tester.pumpAndSettle();

    // Modal dialog is dismissed
    expect(find.text('Clinical Alerts & Notifications'), findsNothing);
  });
}
