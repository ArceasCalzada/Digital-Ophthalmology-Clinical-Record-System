import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/theme/app_theme.dart';
import 'package:ophthalmology_clinical_record_system/views/main_layout.dart';

Future<void> pumpLayout(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: MainLayout(onLogout: () {})));
  await tester.pumpAndSettle();
}

/// Opacity of the grey shadow that hints at hidden sidebar items.
double scrollShadowOpacity(WidgetTester tester) {
  final shadow = find.descendant(of: find.byType(Scaffold).first, matching: find.byType(AnimatedOpacity));
  return tester.widget<AnimatedOpacity>(shadow.first).opacity;
}

void main() {
  testWidgets('labels never wrap or overflow while the sidebar animates open and closed', (tester) async {
    await pumpLayout(tester);
    // Heights of the labels when the sidebar is settled open: what "on one line" means here
    // (the test font is wider than the real one, so some labels wrap even when settled).
    final labels = ['Notifications', 'Dashboard', 'Prescriptions'];
    final settled = {for (final l in labels) l: tester.getSize(find.text(l)).height};

    Future<void> animate(IconData toggle) async {
      await tester.tap(find.byIcon(toggle));
      // Step through the 250 ms animation and check every in-between frame.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull, reason: 'no overflow at frame $i of $toggle');
        for (final label in labels) {
          final visible = find.text(label);
          if (visible.evaluate().isNotEmpty) {
            expect(tester.getSize(visible.first).height, settled[label], reason: '"$label" must not reflow mid-animation');
          }
        }
      }
      await tester.pumpAndSettle();
    }

    await animate(Icons.chevron_left); // collapse
    // Collapsed: icon-only rail, no labels.
    expect(find.text('Dashboard'), findsNothing);
    await animate(Icons.chevron_right); // expand
    expect(find.text('Dashboard'), findsOneWidget);
  });

  // The shadow must say the same thing as the list itself: on only while items are hidden below.
  void expectShadowMatchesList(WidgetTester tester, String when) {
    final list = tester.state<ScrollableState>(
      find.ancestor(of: find.byIcon(Icons.dashboard), matching: find.byType(Scrollable)).first,
    );
    final hidden = list.position.maxScrollExtent - list.position.pixels > 1;
    expect(scrollShadowOpacity(tester), hidden ? 1 : 0, reason: 'shadow out of sync with the list $when (hidden items: $hidden)');
  }

  for (final height in [1000.0, 520.0]) {
    testWidgets('the sidebar scroll shadow stays in sync after collapsing and expanding (window ${height.toInt()} high)', (tester) async {
      tester.view.physicalSize = Size(1400, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: MainLayout(onLogout: () {})));
      await tester.pumpAndSettle();
      expectShadowMatchesList(tester, 'at start');

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        expectShadowMatchesList(tester, 'after collapsing (round $i)');

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expectShadowMatchesList(tester, 'after expanding (round $i)');
      }
    });
  }
}
