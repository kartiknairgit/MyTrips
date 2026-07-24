import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/screens/flights/flight_confirm_screen.dart';

void main() {
  testWidgets('looked-up values are editable before save', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FlightConfirmScreen(
        source: 'auto',
        flightData: {
          'flight_number': 'SQ308',
          'airline_iata': 'SQ',
          'departure_iata': 'SIN',
          'arrival_iata': 'LHR',
          'departure_time': '2026-07-25T10:00:00Z',
          'arrival_time': '2026-07-25T20:00:00Z',
        },
      ),
    ));
    final field = find.byKey(const Key('confirm-flight_number'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'SQ318');
    expect(find.text('SQ318'), findsOneWidget);
  });
}
