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
}
