import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/flight.dart';

/// Service for great-circle arc calculations and MapLibre styling.
/// Ports logic from apps/web/lib/flightPath.ts.
class FlightPathService {
  static bool hasValidCoordinates(Flight flight) =>
      flight.departureLat >= -90 &&
      flight.departureLat <= 90 &&
      flight.arrivalLat >= -90 &&
      flight.arrivalLat <= 90 &&
      flight.departureLng >= -180 &&
      flight.departureLng <= 180 &&
      flight.arrivalLng >= -180 &&
      flight.arrivalLng <= 180 &&
      !(flight.departureLat == 0 &&
          flight.departureLng == 0 &&
          flight.arrivalLat == 0 &&
          flight.arrivalLng == 0);

  /// Generate great-circle arc coordinates between two points.
  /// Returns list of [lng, lat] coordinates for MapLibre GeoJSON.
  List<List<double>> greatCircleArc({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    int nPoints = 100,
  }) {
    final List<List<double>> coordinates = [];

    for (int i = 0; i <= nPoints; i++) {
      final fraction = i / nPoints;
      final point = _interpolatePoint(
        LatLng(fromLat, fromLng),
        LatLng(toLat, toLng),
        fraction,
      );
      coordinates.add([point.longitude, point.latitude]);
    }

    return coordinates;
  }

  /// Interpolate point along great circle path using spherical geometry.
  LatLng _interpolatePoint(LatLng from, LatLng to, double fraction) {
    // Convert to radians
    final lat1 = _toRadians(from.latitude);
    final lng1 = _toRadians(from.longitude);
    final lat2 = _toRadians(to.latitude);
    final lng2 = _toRadians(to.longitude);

    // Calculate great circle distance
    final d = 2 *
        math.asin(math.sqrt(math.pow(math.sin((lat1 - lat2) / 2), 2) +
            math.cos(lat1) *
                math.cos(lat2) *
                math.pow(math.sin((lng1 - lng2) / 2), 2)));

    if (d == 0) {
      // Same point
      return from;
    }

    final a = math.sin((1 - fraction) * d) / math.sin(d);
    final b = math.sin(fraction * d) / math.sin(d);

    final x = a * math.cos(lat1) * math.cos(lng1) +
        b * math.cos(lat2) * math.cos(lng2);
    final y = a * math.cos(lat1) * math.sin(lng1) +
        b * math.cos(lat2) * math.sin(lng2);
    final z = a * math.sin(lat1) + b * math.sin(lat2);

    final lat = math.atan2(z, math.sqrt(x * x + y * y));
    final lng = math.atan2(y, x);

    return LatLng(_toDegrees(lat), _toDegrees(lng));
  }

  /// Get MapLibre line paint properties based on flight status.
  /// Mirrors paintForStatus() from apps/web/lib/flightPath.ts.
  Map<String, dynamic> paintForStatus(FlightStatus status, String color) {
    switch (status) {
      case FlightStatus.completed:
        return {
          'line-color': color,
          'line-width': 2.5,
          'line-opacity': 1.0,
        };
      case FlightStatus.inTransit:
        return {
          'line-color': color,
          'line-width': 2.5,
          'line-opacity': 1.0,
          'line-dasharray': [2.0, 2.0],
        };
      case FlightStatus.scheduled:
        return {
          'line-color': color,
          'line-width': 1.0,
          'line-opacity': 0.35,
          'line-dasharray': [1.0, 3.0],
        };
      case FlightStatus.cancelled:
        return {
          'line-color': '#9ca3af',
          'line-width': 1.0,
          'line-opacity': 0.2,
          'line-dasharray': [1.0, 3.0],
        };
    }
  }

  // Math helpers
  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;
}
