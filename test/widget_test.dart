import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test renders a widget tree', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Panpanskii'))),
    );

    expect(find.text('Panpanskii'), findsOneWidget);
  });
}
