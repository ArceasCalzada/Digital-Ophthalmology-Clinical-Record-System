import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/main.dart';

void main() {
  testWidgets('App renders DOCRS clinical workstation title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OphthalmologyApp());
    await tester.pumpAndSettle();

    // Verify that DOCRS title is displayed
    expect(find.text('DOCRS'), findsOneWidget);
  });
}
