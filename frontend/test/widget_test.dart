import 'package:flutter_test/flutter_test.dart';

import 'package:xjtu_course_genius/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CourseGeniusApp());
    expect(find.text('统一身份认证'), findsOneWidget);
  });
}
