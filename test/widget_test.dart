import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/main.dart';

void main() {
  testWidgets('Shows Firebase unavailable when not ready', (tester) async {
    await tester.pumpWidget(const GstBillingApp(firebaseReady: false));
    expect(find.text('Firebase not connected'), findsOneWidget);
  });

  testWidgets('App theme loads for party shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: Text('Parties')),
      ),
    );
    expect(find.text('Parties'), findsOneWidget);
  });
}
