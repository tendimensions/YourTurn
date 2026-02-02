// Basic widget test for YourTurn app
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:yourturn/main.dart';

void main() {
  testWidgets('App loads and displays lobby screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YourTurnApp());

    // Verify that the app title is displayed
    expect(find.text('YourTurn'), findsOneWidget);

    // Verify lobby screen elements are present
    expect(find.text('Create a Session'), findsOneWidget);
    expect(find.text('Join a Session'), findsOneWidget);
  });
}
