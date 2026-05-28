import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_android_application/main.dart';

void main() {
  testWidgets('Smoke test - Verify Sign In screen renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DogAdoptionApp());

    // Verify that the Sign In title and fields are present.
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
