import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophthalmology_clinical_record_system/widgets/shake_widget.dart';

/// How far the nearest [ShakeWidget] around [inside] is currently pushed sideways.
/// Zero when it is at rest, so a non-zero value a moment after a failed submit
/// means the field is shaking.
double shakeOffset(WidgetTester tester, Finder inside) {
  final shake = find.ancestor(of: inside, matching: find.byType(ShakeWidget)).first;
  final transform = tester.widget<Transform>(find.descendant(of: shake, matching: find.byType(Transform)).first);
  return transform.transform.getTranslation().x;
}

/// Lets a shake get going (it lasts 420 ms) without letting it finish.
Future<void> letShakeStart(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}
