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

      final profile = await _client
          .from('profiles')
          .select('home_country')
          .eq('id', userId)
          .maybeSingle();
      final response = await _client.rpc('my_mileage_percentile', params: {
        'scope_country': profile?['home_country'],
      });

      if (response is! List || response.isEmpty) {
        return MileagePercentile.empty();
      }

      return MileagePercentile.fromJson(response.first as Map<String, dynamic>);
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
          .eq('status', 'completed')
          .gte('departure_time', startDate)
          .lt('departure_time', endDate);

      // Count flights per month
      final monthlyCounts = <int, int>{};
      for (int i = 1; i <= 12; i++) {
        monthlyCounts[i] = 0;
      }

      for (final flight in response as List) {
        final departureTime =
            DateTime.parse(flight['departure_time'] as String);
        final month = departureTime.month;
        monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
      }

      return monthlyCounts;
    } catch (e) {
      throw Exception('Failed to fetch monthly counts: $e');
    }
  }

  Future<Map<int, int>> getDailyCounts(int year, int month) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    final start = DateTime.utc(year, month);
    final end = DateTime.utc(year, month + 1);
    final response = await _client
        .from('flights')
        .select('departure_time')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .gte('departure_time', start.toIso8601String())
        .lt('departure_time', end.toIso8601String());
    return countDays(response as List, year, month);
  }

  static Map<int, int> countDays(List<dynamic> rows, int year, int month) {
    final days = DateTime.utc(year, month + 1, 0).day;
    final result = {for (var day = 1; day <= days; day++) day: 0};
    for (final row in rows) {
      final date = DateTime.parse(
              (row as Map<String, dynamic>)['departure_time'] as String)
          .toUtc();
      result[date.day] = (result[date.day] ?? 0) + 1;
    }
    return result;
  }

  static List<int> yearRangeFromRows(List<dynamic> rows, DateTime now) {
    if (rows.isEmpty) return [now.year];
    final years = rows
        .map((row) => DateTime.parse(
            (row as Map<String, dynamic>)['departure_time'] as String))
        .map((date) => date.year)
        .toList();
    final earliest = years.reduce((a, b) => a < b ? a : b);
    final flightLatest = years.reduce((a, b) => a > b ? a : b);
    final latest = flightLatest > now.year ? flightLatest : now.year;
    return List.generate(latest - earliest + 1, (index) => earliest + index);
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

      return yearRangeFromRows(response as List, DateTime.now());
    } catch (e) {
      throw Exception('Failed to fetch year range: $e');
    }
  }

  /// Get geographic statistics (continents, countries, cities, top airport, top route).
  Future<Map<String, dynamic>> getGeoStats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch all flights with joined airport data
      final response = await _client.from('flights').select('''
        departure_iata,
        arrival_iata,
        departure:airports!flights_departure_iata_fkey(continent, country, city, name),
        arrival:airports!flights_arrival_iata_fkey(continent, country, city, name)
      ''').eq('user_id', userId).eq('status', 'completed');

      final flights = response as List;

      if (flights.isEmpty) {
        return {
          'continents': 0,
          'countries': 0,
          'cities': 0,
          'topAirport': null,
          'topRoute': null,
        };
      }

      // Count unique continents, countries, cities
      final continents = <String>{};
      final countries = <String>{};
      final cities = <String>{};
      final airportCounts = <String, int>{};
      final routeCounts = <String, int>{};

      for (final flight in flights) {
        final depAirport = flight['departure'] as Map<String, dynamic>?;
        final arrAirport = flight['arrival'] as Map<String, dynamic>?;

        // Add departure airport data
        if (depAirport != null) {
          if (depAirport['continent'] != null)
            continents.add(depAirport['continent'] as String);
          if (depAirport['country'] != null)
            countries.add(depAirport['country'] as String);
          if (depAirport['city'] != null)
            cities.add(depAirport['city'] as String);

          final depIata = flight['departure_iata'] as String;
          airportCounts[depIata] = (airportCounts[depIata] ?? 0) + 1;
        }

        // Add arrival airport data
        if (arrAirport != null) {
          if (arrAirport['continent'] != null)
            continents.add(arrAirport['continent'] as String);
          if (arrAirport['country'] != null)
            countries.add(arrAirport['country'] as String);
          if (arrAirport['city'] != null)
            cities.add(arrAirport['city'] as String);

          final arrIata = flight['arrival_iata'] as String;
          airportCounts[arrIata] = (airportCounts[arrIata] ?? 0) + 1;
        }

        // Count routes (origin-destination pairs)
        final depIata = flight['departure_iata'] as String;
        final arrIata = flight['arrival_iata'] as String;
        final route = '$depIata-$arrIata';
        routeCounts[route] = (routeCounts[route] ?? 0) + 1;
      }

      // Find top airport
      String? topAirportIata;
      int maxAirportCount = 0;
      airportCounts.forEach((iata, count) {
        if (count > maxAirportCount) {
          topAirportIata = iata;
          maxAirportCount = count;
        }
      });

      // Find top route
      String? topRoute;
      int maxRouteCount = 0;
      routeCounts.forEach((route, count) {
        if (count > maxRouteCount) {
          topRoute = route;
          maxRouteCount = count;
        }
      });

      return {
        'continents': continents.length,
        'countries': countries.length,
        'cities': cities.length,
        'topAirport': topAirportIata != null
            ? {'iata': topAirportIata, 'count': maxAirportCount}
            : null,
        'topRoute': topRoute != null
            ? {'route': topRoute, 'count': maxRouteCount}
            : null,
      };
    } catch (e) {
      throw Exception('Failed to fetch geo stats: $e');
    }
  }

  /// Get airline statistics (alliance breakdown, top airline).
  Future<Map<String, dynamic>> getAirlineStats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch all flights with joined airline data
      final response = await _client.from('flights').select('''
        airline_iata,
        airline:airlines(name, alliance)
      ''').eq('user_id', userId).eq('status', 'completed');

      final flights = response as List;

      if (flights.isEmpty) {
        return {
          'allianceCounts': <String, int>{},
          'topAirline': null,
        };
      }

      // Count flights by alliance
      final allianceCounts = <String, int>{};
      final airlineCounts = <String, int>{};

      for (final flight in flights) {
        final airline = flight['airline'] as Map<String, dynamic>?;
        final airlineIata = flight['airline_iata'] as String?;

        if (airline != null && airlineIata != null) {
          final alliance = airline['alliance'] as String? ?? 'None';
          allianceCounts[alliance] = (allianceCounts[alliance] ?? 0) + 1;

          airlineCounts[airlineIata] = (airlineCounts[airlineIata] ?? 0) + 1;
        }
      }

      // Find top airline
      String? topAirlineIata;
      int maxAirlineCount = 0;
      airlineCounts.forEach((iata, count) {
        if (count > maxAirlineCount) {
          topAirlineIata = iata;
          maxAirlineCount = count;
        }
      });

      return {
        'allianceCounts': allianceCounts,
        'topAirline': topAirlineIata != null
            ? {'iata': topAirlineIata, 'count': maxAirlineCount}
            : null,
      };
    } catch (e) {
      throw Exception('Failed to fetch airline stats: $e');
    }
  }

  /// Get aircraft statistics (manufacturer breakdown).
  /// Groups by aircraft manufacturer, treating null aircraft_iata as "Unknown".
  Future<Map<String, int>> getAircraftStats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch manufacturer through the frozen aircraft_types relationship.
      final response = await _client
          .from('flights')
          .select('aircraft:aircraft_types(manufacturer)')
          .eq('user_id', userId)
          .eq('status', 'completed');

      final flights = response as List;

      if (flights.isEmpty) {
        return {};
      }

      // Count flights by manufacturer (derived from aircraft IATA prefix)
      final manufacturerCounts = <String, int>{};

      for (final flight in flights) {
        final aircraft = flight['aircraft'] as Map<String, dynamic>?;
        final manufacturer = aircraft?['manufacturer'] as String? ?? 'Unknown';

        manufacturerCounts[manufacturer] =
            (manufacturerCounts[manufacturer] ?? 0) + 1;
      }

      return manufacturerCounts;
    } catch (e) {
      throw Exception('Failed to fetch aircraft stats: $e');
    }
  }
}
