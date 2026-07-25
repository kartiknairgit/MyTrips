/// Flight status enum mirroring the database enum.
enum FlightStatus {
  scheduled,
  inTransit('in_transit'),
  completed,
  cancelled;

  final String? _value;
  const FlightStatus([this._value]);

  String get value => _value ?? name;

  static FlightStatus fromString(String value) {
    return FlightStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => FlightStatus.completed,
    );
  }
}

/// Flight source enum.
enum FlightSource {
  auto,
  manual;

  static FlightSource fromString(String value) {
    return FlightSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => FlightSource.manual,
    );
  }
}

/// Flight model matching the flights table schema,
/// with joined airport and airline data.
class Flight {
  final String id;
  final String userId;
  final String flightNumber;
  final String? airlineIata;
  final String departureIata;
  final String arrivalIata;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final FlightStatus status;
  final FlightSource source;
  final String? aircraftIata;
  final DateTime createdAt;

  // Joined data from airports and airlines
  final double departureLat;
  final double departureLng;
  final double arrivalLat;
  final double arrivalLng;
  final String airlineColor;

  Flight({
    required this.id,
    required this.userId,
    required this.flightNumber,
    this.airlineIata,
    required this.departureIata,
    required this.arrivalIata,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.source,
    this.aircraftIata,
    required this.createdAt,
    required this.departureLat,
    required this.departureLng,
    required this.arrivalLat,
    required this.arrivalLng,
    required this.airlineColor,
  });

  /// Factory constructor from Supabase JSON with joined data.
  /// Expects query like:
  /// ```
  /// .select('''
  ///   *,
  ///   departure:airports!flights_departure_iata_fkey(lat, lng),
  ///   arrival:airports!flights_arrival_iata_fkey(lat, lng),
  ///   airline:airlines(brand_color_hex)
  /// ''')
  /// ```
  factory Flight.fromJson(Map<String, dynamic> json) {
    final departure = json['departure'] as Map<String, dynamic>?;
    final arrival = json['arrival'] as Map<String, dynamic>?;
    final airline = json['airline'] as Map<String, dynamic>?;

    return Flight(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      flightNumber: json['flight_number'] as String,
      airlineIata: json['airline_iata'] as String?,
      departureIata: json['departure_iata'] as String,
      arrivalIata: json['arrival_iata'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      arrivalTime: DateTime.parse(json['arrival_time'] as String),
      status: FlightStatus.fromString(json['status'] as String),
      source: FlightSource.fromString(json['source'] as String),
      aircraftIata: json['aircraft_iata'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      departureLat: (departure?['lat'] as num?)?.toDouble() ?? 0.0,
      departureLng: (departure?['lng'] as num?)?.toDouble() ?? 0.0,
      arrivalLat: (arrival?['lat'] as num?)?.toDouble() ?? 0.0,
      arrivalLng: (arrival?['lng'] as num?)?.toDouble() ?? 0.0,
      airlineColor: (airline?['brand_color_hex'] as String?) ?? '#6b7280',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'flight_number': flightNumber,
      'airline_iata': airlineIata,
      'departure_iata': departureIata,
      'arrival_iata': arrivalIata,
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime.toIso8601String(),
      'status': status.value,
      'source': source.name,
      'aircraft_iata': aircraftIata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Recompute status from wall-clock time (mirrors compute_flight_status() in SQL).
  FlightStatus deriveStatus() {
    if (status == FlightStatus.cancelled) return FlightStatus.cancelled;
    final now = DateTime.now();
    if (now.isBefore(departureTime)) return FlightStatus.scheduled;
    if (now.isBefore(arrivalTime)) return FlightStatus.inTransit;
    return FlightStatus.completed;
  }

  /// How far along the arc (0-1) the plane should be for in_transit flights.
  double progressFraction() {
    final now = DateTime.now();
    if (now.isBefore(departureTime)) return 0.0;
    if (now.isAfter(arrivalTime)) return 1.0;

    final totalDuration = arrivalTime.difference(departureTime).inMilliseconds;
    if (totalDuration <= 0) return 1.0;
    final elapsed = now.difference(departureTime).inMilliseconds;
    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }
}
