import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hci_project/main.dart';

void main() {
  testWidgets('App loads music player screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'Test'),
      ),
    );

    expect(find.text('PLAYLIST NAME'), findsOneWidget);
  });
}