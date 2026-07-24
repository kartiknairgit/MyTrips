import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/main.dart';
import 'package:flightpath_mobile/screens/configuration_screen.dart';
import 'package:flightpath_mobile/services/supabase_service.dart';

void main() {
  test('missing compile-time values are reported as unconfigured', () {
    expect(SupabaseService.isConfigured, isFalse);
  });

  testWidgets('missing configuration renders a safe actionable screen',
      (tester) async {
    await tester.pumpWidget(const FlightPathApp());
    expect(find.byType(ConfigurationScreen), findsOneWidget);
    expect(find.textContaining('needs Supabase configuration'), findsOneWidget);
    expect(find.textContaining('service-role'), findsOneWidget);
  });
}
