import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/models/flight.dart';
import 'package:flightpath_mobile/services/flight_path_service.dart';

Flight flight({FlightStatus status = FlightStatus.completed}) => Flight(
      id: 'flight',
      userId: 'user',
      flightNumber: 'SQ1',
      departureIata: 'SIN',
      arrivalIata: 'LHR',
      departureTime: DateTime.utc(2020),
      arrivalTime: DateTime.utc(2020, 1, 2),
      status: status,
      source: FlightSource.manual,
      createdAt: DateTime.utc(2020),
      departureLat: 1.35,
      departureLng: 103.8,
      arrivalLat: 51.47,
      arrivalLng: -0.45,
      airlineColor: '#FF10F0',
    );

void main() {
  test('cancelled status remains cancelled after scheduled times', () {
    expect(flight(status: FlightStatus.cancelled).deriveStatus(),
        FlightStatus.cancelled);
  });

  test('status styling binds dash arrays for non-solid routes', () {
    final service = FlightPathService();
    expect(
        service.paintForStatus(
            FlightStatus.scheduled, '#fff')['line-dasharray'],
        [1.0, 3.0]);
    expect(
        service.paintForStatus(
            FlightStatus.inTransit, '#fff')['line-dasharray'],
        [2.0, 2.0]);
    expect(
        service
            .paintForStatus(FlightStatus.completed, '#fff')
            .containsKey('line-dasharray'),
        isFalse);
  });

  test('valid route coordinates are accepted', () {
    expect(FlightPathService.hasValidCoordinates(flight()), isTrue);
  });
}
