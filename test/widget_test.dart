import 'package:flutter_test/flutter_test.dart';
import 'package:gst_billing/main.dart';

void main() {
  testWidgets('App shell loads', (WidgetTester tester) async {
    await tester.pumpWidget(const GstBillingApp(firebaseReady: false));
    expect(find.text('GST Billing MVP'), findsOneWidget);
  });
}
