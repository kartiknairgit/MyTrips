import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/main.dart';

void main() {
  testWidgets('App boots and shows placeholder text', (tester) async {
    await tester.pumpWidget(const FlightPathApp());
    expect(find.text('FlightPath map view goes here'), findsOneWidget);
  });
}
