import 'package:flutter_test/flutter_test.dart';

import 'package:flumi/main.dart';

void main() {
  testWidgets('App se inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const FlumiApp());
    expect(find.text('Flumi'), findsWidgets);
  });
}
