import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/services/flight_service.dart';

void main() {
  test('lookup payload matches the frozen Edge Function contract', () {
    expect(
      FlightService.lookupPayload(' sq308 ', DateTime(2026, 7, 5)),
      {'flight_iata': 'SQ308', 'flight_date': '2026-07-05'},
    );
  });

  test('save preparation preserves source and derives status', () {
    final result = FlightService.prepareForSave({
      'flight_number': ' sq308 ',
      'airline_iata': 'sq',
      'departure_iata': 'sin',
      'arrival_iata': 'lhr',
      'departure_time': '2026-07-25T10:00:00Z',
      'arrival_time': '2026-07-25T20:00:00Z',
      'live_status': 'scheduled',
    }, source: 'auto', now: DateTime.utc(2026, 7, 25, 12));
    expect(result['source'], 'auto');
    expect(result['status'], 'in_transit');
    expect(result['flight_number'], 'SQ308');
    expect(result.containsKey('live_status'), isFalse);
  });

  test('explicit cancellation is never overwritten by wall clock', () {
    expect(
      FlightService.statusForTimes(
        DateTime.utc(2020),
        DateTime.utc(2020, 1, 2),
        now: DateTime.utc(2026),
        explicitStatus: 'cancelled',
      ),
      'cancelled',
    );
  });
}
