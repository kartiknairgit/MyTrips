import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/stats.dart';

/// Service for statistics-related operations.
class StatsService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Fetch overview stats from user_flight_stats view.
  Future<OverviewStats> getOverviewStats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('user_flight_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return OverviewStats.empty();
      }

      return OverviewStats.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch overview stats: $e');
    }
  }

  /// Call my_mileage_percentile() RPC to get user's percentile ranking.
  Future<MileagePercentile> getMileagePercentile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client.rpc('my_mileage_percentile');

      if (response == null) {
        return MileagePercentile.empty();
      }

      return MileagePercentile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch mileage percentile: $e');
    }
  }

  /// Get monthly flight counts for a specific year.
  /// Returns a map where keys are month numbers (1-12) and values are flight counts.
  Future<Map<int, int>> getMonthlyCounts(int year) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Query flights for the specified year
      final startDate = DateTime(year, 1, 1).toIso8601String();
      final endDate = DateTime(year + 1, 1, 1).toIso8601String();

      final response = await _client
          .from('flights')
          .select('departure_time')
          .eq('user_id', userId)
          .gte('departure_time', startDate)
          .lt('departure_time', endDate);

      // Count flights per month
      final monthlyCounts = <int, int>{};
      for (int i = 1; i <= 12; i++) {
        monthlyCounts[i] = 0;
      }

      for (final flight in response as List) {
        final departureTime = DateTime.parse(flight['departure_time'] as String);
        final month = departureTime.month;
        monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
      }

      return monthlyCounts;
    } catch (e) {
      throw Exception('Failed to fetch monthly counts: $e');
    }
  }

  /// Get the year range of user's flights (min year to max year).
  /// Returns null if user has no flights.
  Future<List<int>?> getYearRange() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('flights')
          .select('departure_time')
          .eq('user_id', userId)
          .order('departure_time', ascending: true);

      if ((response as List).isEmpty) {
        return null;
      }

      final flights = response as List;
      final firstFlight = DateTime.parse(flights.first['departure_time'] as String);
      final lastFlight = DateTime.parse(flights.last['departure_time'] as String);

      final minYear = firstFlight.year;
      final maxYear = lastFlight.year;

      return List.generate(maxYear - minYear + 1, (i) => minYear + i);
    } catch (e) {
      throw Exception('Failed to fetch year range: $e');
    }
  }
}
