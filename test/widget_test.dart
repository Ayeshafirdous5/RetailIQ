// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:retail_iq/main.dart';
import 'package:retail_iq/services/auth_service.dart';

void main() {
  testWidgets('shows login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      RetailIqApp(
        authService: AuthService.forTesting(authStateChanges: Stream.value(null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to manage your retail business.'), findsOneWidget);

  });
}
