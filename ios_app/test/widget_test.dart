import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material 根组件可渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('家庭 AI 助手')),
        ),
      ),
    );
    expect(find.text('家庭 AI 助手'), findsOneWidget);
  });
}
