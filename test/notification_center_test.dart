import 'package:flutter/material.dart';
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

    // Only the header bell remains; cards carry no icons.
    expect(find.byType(Icon), findsOneWidget);
  });
}
