import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for flight-related operations.
class FlightService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Call lookup-flight Edge Function to auto-fetch flight details.
  /// Returns normalized flight data from AviationStack.
  Future<Map<String, dynamic>> lookupFlight({
    required String flightCode,
    required DateTime date,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'lookup-flight',
        body: {
          'flight_code': flightCode,
          'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
        },
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

      flightData['user_id'] = userId;

      await _client.from('flights').insert(flightData);
    } catch (e) {
      throw Exception('Failed to save flight: $e');
    }
  }
}
