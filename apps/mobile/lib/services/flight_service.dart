import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for flight-related operations.
class FlightService {
  final SupabaseClient? _providedClient;

  FlightService({SupabaseClient? client}) : _providedClient = client;

  SupabaseClient get _client =>
      _providedClient ?? SupabaseService.instance.client;

  /// Call lookup-flight Edge Function to auto-fetch flight details.
  /// Returns normalized flight data from AviationStack.
  Future<Map<String, dynamic>> lookupFlight({
    required String flightCode,
    required DateTime date,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'lookup-flight',
        body: lookupPayload(flightCode, date),
      );

      if (response.data == null) {
        throw Exception('No data returned from lookup-flight');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Flight lookup failed: $e');
    }
  }

  /// Save a flight to the database.
  /// flightData should include all required fields from the flights table.
  Future<void> saveFlight(Map<String, dynamic> flightData) async {
    try {
      // Ensure user_id is set
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = Map<String, dynamic>.from(flightData);
      data['user_id'] = userId;
      await _client.from('flights').insert(data);
    } catch (e) {
      throw Exception('Failed to save flight: $e');
    }
  }

  static Map<String, String> lookupPayload(String flightIata, DateTime date) {
    final normalized = flightIata.trim().toUpperCase();
    return {
      'flight_iata': normalized,
      'flight_date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    };
  }

  static String statusForTimes(DateTime departure, DateTime arrival,
      {DateTime? now, String? explicitStatus}) {
    if (explicitStatus == 'cancelled') return 'cancelled';
    final clock = now ?? DateTime.now();
    if (clock.isBefore(departure)) return 'scheduled';
    if (clock.isBefore(arrival)) return 'in_transit';
    return 'completed';
  }

  static Map<String, dynamic> prepareForSave(
    Map<String, dynamic> input, {
    required String source,
    DateTime? now,
  }) {
    final data = Map<String, dynamic>.from(input)
      ..remove('airline_name')
      ..remove('live_status')
      ..remove('id')
      ..remove('created_at')
      ..remove('user_id');
    final departure = DateTime.parse(data['departure_time'] as String);
    final arrival = DateTime.parse(data['arrival_time'] as String);
    data['flight_number'] =
        (data['flight_number'] as String).trim().toUpperCase();
    data['departure_iata'] =
        (data['departure_iata'] as String).trim().toUpperCase();
    data['arrival_iata'] =
        (data['arrival_iata'] as String).trim().toUpperCase();
    final airline = (data['airline_iata'] as String?)?.trim().toUpperCase();
    data['airline_iata'] = airline?.isEmpty == true ? null : airline;
    data['source'] = source;
    data['status'] = statusForTimes(departure, arrival,
        now: now, explicitStatus: data['status'] as String?);
    return data;
  }
}
