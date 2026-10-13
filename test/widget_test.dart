import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_supreme_admin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Admin panel initial render smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('ADMIN PANEL'), findsOneWidget);
  });
}
