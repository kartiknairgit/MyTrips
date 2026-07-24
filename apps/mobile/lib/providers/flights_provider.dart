import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/flight.dart';

/// Provider for app-wide flights state with Realtime subscriptions.
class FlightsProvider with ChangeNotifier {
  final SupabaseClient _client = SupabaseService.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  List<Flight> _flights = [];
  bool _isLoading = true;
  String? _error;

  List<Flight> get flights => _flights;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FlightsProvider() {
    _init();
  }

  Future<void> _init() async {
    await fetchFlights();
    _subscribeToRealtime();
  }

  /// Fetch all flights for the current user with joined airport/airline data.
  Future<void> fetchFlights() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.from('flights').select('''
            *,
            departure:airports!flights_departure_iata_fkey(lat, lng),
            arrival:airports!flights_arrival_iata_fkey(lat, lng),
            airline:airlines(brand_color_hex)
          ''').order('departure_time', ascending: false);

      _flights = (response as List)
          .map((json) => Flight.fromJson(json as Map<String, dynamic>))
          .toList();

      _error = null;
    } catch (e) {
      _error = 'Failed to load flights: $e';
      _flights = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to Realtime changes on the flights table.
  /// Refreshes all flights when any change occurs.
  void _subscribeToRealtime() {
    try {
      final stream = _client
          .from('flights')
          .stream(primaryKey: ['id']).order('departure_time');

      _realtimeSubscription = stream.listen(
        (data) {
          // Refresh flights on any change
          fetchFlights();
        },
        onError: (error) {
          debugPrint('Realtime subscription error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe to realtime: $e');
    }
  }

  /// Add a new flight.
  Future<void> addFlight(Map<String, dynamic> flightData) async {
    try {
      await _client.from('flights').insert(flightData);
      // Realtime will trigger refresh
    } catch (e) {
      _error = 'Failed to add flight: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh flights manually.
  Future<void> refresh() async {
    await fetchFlights();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
