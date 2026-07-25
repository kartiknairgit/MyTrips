# Mobile Implementation Guide

**Status as of 2026-07-24**

This guide provides detailed implementation instructions for completing the MyTrips Flutter mobile app. It picks up from where the initial implementation left off.

---

## ✅ Completed Work

### Prerequisites
- ✅ GitHub CLI installed and authenticated
- ✅ Flutter SDK installed (3.44.8)
- ✅ Branch `feature/mobile-ui` checked out
- ✅ Dependencies added to `pubspec.yaml`:
  - `supabase_flutter: ^2.5.0`
  - `maplibre_gl: ^0.20.0`
  - `fl_chart: ^0.68.0`
  - `latlong2: ^0.9.0`
  - `great_circle_distance_calculator: ^1.0.0`
  - `intl: ^0.19.0`
  - `provider: ^6.1.0`

### GitHub Issues Created
- Issue #10: Supabase Flutter Wiring ✅ **COMPLETE**
- Issue #11: MapLibre Flight-Arc Map View ⏳ **IN PROGRESS**
- Issue #12: Flight Entry Screen
- Issue #13: Overview Statistics Screen
- Issue #14: Flight Calendar Screen
- Issue #15: Geographic & Airline Statistics Screen
- Issue #16: Aircraft Statistics Screen
- Issue #17: Compatibility Quiz Flow

### Issue #10: Supabase Flutter Wiring ✅ COMPLETE

**Files Created:**
- `lib/services/supabase_service.dart` - Singleton for Supabase client
- `lib/services/auth_service.dart` - Auth operations wrapper
- `lib/providers/auth_provider.dart` - App-wide auth state
- `lib/screens/auth/login_screen.dart` - Email/password sign in
- `lib/screens/auth/signup_screen.dart` - Email/password registration

**Files Modified:**
- `lib/main.dart` - Added AuthGate routing, Provider setup
- `test/widget_test.dart` - Basic service validation tests

**Commit:** `71aa2ff` - "feat(mobile): supabase flutter client wiring and auth session (#10)"

### Partial Work: Data Models Created

**Files Created:**
- `lib/models/airport.dart` - Airport model with lat/lng
- `lib/models/airline.dart` - Airline model with brand colors
- `lib/models/flight.dart` - Flight model with status enum, joined data support

---

## 🚧 Remaining Implementation

---

## Issue #11: MapLibre Flight-Arc Map View

**Status:** Models created, need services + UI

### Step 1: Create Flight Path Service

Create `lib/services/flight_path_service.dart`:

```dart
import 'package:latlong2/latlong.dart';
import 'package:great_circle_distance_calculator/great_circle_distance_calculator.dart';
import '../models/flight.dart';

/// Service for great-circle arc calculations and MapLibre styling.
/// Ports logic from apps/web/lib/flightPath.ts.
class FlightPathService {
  static const GreatCircleDistance _gcd = GreatCircleDistance();

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

  /// Interpolate point along great circle path.
  LatLng _interpolatePoint(LatLng from, LatLng to, double fraction) {
    // Simple linear interpolation for MVP
    // For production, use proper spherical interpolation
    final lat = from.latitude + (to.latitude - from.latitude) * fraction;
    final lng = from.longitude + (to.longitude - from.longitude) * fraction;
    return LatLng(lat, lng);
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
          'line-dasharray': [2, 2],
          'line-opacity': 1.0,
        };
      case FlightStatus.scheduled:
        return {
          'line-color': color,
          'line-width': 1.0,
          'line-opacity': 0.35,
          'line-dasharray': [1, 3],
        };
      case FlightStatus.cancelled:
        return {
          'line-color': '#9ca3af',
          'line-width': 1.0,
          'line-opacity': 0.2,
          'line-dasharray': [1, 3],
        };
    }
  }
}
```

### Step 2: Create Flights Provider

Create `lib/providers/flights_provider.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/flight.dart';

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

  Future<void> fetchFlights() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client
          .from('flights')
          .select('''
            *,
            departure:airports!flights_departure_iata_fkey(lat, lng),
            arrival:airports!flights_arrival_iata_fkey(lat, lng),
            airline:airlines(brand_color_hex)
          ''')
          .order('departure_time', ascending: false);

      _flights = (response as List)
          .map((json) => Flight.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load flights: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    final stream = _client
        .from('flights')
        .stream(primaryKey: ['id'])
        .order('departure_time');

    _realtimeSubscription = stream.listen((data) {
      // Refresh flights on any change
      fetchFlights();
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
```

### Step 3: Create Map Screen

Create `lib/screens/map/map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../providers/flights_provider.dart';
import '../../services/flight_path_service.dart';
import '../../models/flight.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _mapController;
  final FlightPathService _flightPathService = FlightPathService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: Consumer<FlightsProvider>(
        builder: (context, flightsProvider, _) {
          if (flightsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF10F0)),
            );
          }

          if (flightsProvider.error != null) {
            return Center(
              child: Text(
                flightsProvider.error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          return MapLibreMap(
            styleString: 'https://tiles.openfreemap.org/styles/liberty',
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.0, 0.0),
              zoom: 2.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _addFlightArcs(flightsProvider.flights);
            },
            onStyleLoadedCallback: () {
              if (_mapController != null) {
                _addFlightArcs(flightsProvider.flights);
              }
            },
          );
        },
      ),
    );
  }

  void _addFlightArcs(List<Flight> flights) async {
    if (_mapController == null) return;

    for (final flight in flights) {
      final arcCoordinates = _flightPathService.greatCircleArc(
        fromLat: flight.departureLat,
        fromLng: flight.departureLng,
        toLat: flight.arrivalLat,
        toLng: flight.arrivalLng,
      );

      final geojson = {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': arcCoordinates,
        },
        'properties': {},
      };

      final sourceId = 'flight-${flight.id}';
      final layerId = 'flight-layer-${flight.id}';

      // Add source
      await _mapController!.addSource(
        sourceId,
        GeojsonSourceProperties(data: geojson),
      );

      // Add layer with status-based styling
      final paint = _flightPathService.paintForStatus(
        flight.deriveStatus(),
        flight.airlineColor,
      );

      await _mapController!.addLayer(
        sourceId,
        layerId,
        LineLayerProperties(
          lineColor: paint['line-color'] as String,
          lineWidth: (paint['line-width'] as num).toDouble(),
          lineOpacity: (paint['line-opacity'] as num).toDouble(),
        ),
      );
    }
  }
}
```

### Step 4: Update main.dart

Add FlightsProvider and replace placeholder home screen:

```dart
// In main.dart, update MultiProvider:
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => FlightsProvider()),
  ],
  child: MaterialApp(
    // ... rest stays same
  ),
);

// Replace the authenticated state in AuthGate with:
if (authProvider.isAuthenticated) {
  return const MapScreen();
}
```

### Step 5: Run Validation

```bash
flutter analyze
flutter test
git add -A
git commit -m "feat(mobile): maplibre flight-arc map view with status-based styling (#11)"
gh issue close 11 --comment "Implementation complete. Map renders flight arcs with correct styling per status."
```

---

## Issue #12: Flight Entry Screen

### File Structure

Create these files:
- `lib/screens/flights/add_flight_screen.dart` - Main form
- `lib/screens/flights/flight_confirm_screen.dart` - Confirm/edit before save
- `lib/services/flight_service.dart` - Edge Function calls

### Implementation Pattern

```dart
// lib/services/flight_service.dart
class FlightService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Call lookup-flight Edge Function
  Future<Map<String, dynamic>> lookupFlight({
    required String flightCode,
    required DateTime date,
  }) async {
    final response = await _client.functions.invoke(
      'lookup-flight',
      body: {
        'flight_code': flightCode,
        'date': date.toIso8601String().split('T')[0],
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Save flight to database
  Future<void> saveFlight(Map<String, dynamic> flightData) async {
    await _client.from('flights').insert(flightData);
  }
}
```

Form should have:
- Flight number field (e.g., "SQ308")
- Date picker
- Manual override fields (origin, destination, airline, times)
- "Auto-lookup" button → calls Edge Function
- On success → navigate to confirm screen
- Confirm screen → allows edits before final save

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): flight entry screen with auto-lookup (#12)`

---

## Issue #13: Overview Statistics Screen

### Files to Create

- `lib/services/stats_service.dart` - Port web stats queries
- `lib/screens/stats/overview_screen.dart` - Main UI
- `lib/widgets/stat_card.dart` - Reusable stat display
- `lib/widgets/percentile_badge.dart` - Ranking badge
- `lib/models/stats.dart` - Stats data models

### Key Queries

```dart
// lib/services/stats_service.dart
class StatsService {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<Map<String, dynamic>> getOverviewStats({String? homeCountry}) async {
    // Query user_flight_stats view
    final statsResponse = await _client
        .from('user_flight_stats')
        .select('total_flights, total_km, total_hours')
        .single();

    // Call my_mileage_percentile RPC
    final percentileResponse = await _client.rpc(
      'my_mileage_percentile',
      params: {'scope_country': homeCountry},
    );

    return {
      'totalFlights': statsResponse['total_flights'] ?? 0,
      'totalKm': (statsResponse['total_km'] ?? 0).round(),
      'totalHours': ((statsResponse['total_hours'] ?? 0) * 10).round() / 10,
      'percentile': percentileResponse[0]['percentile'],
      'percentileScope': percentileResponse[0]['scope'],
      'sampleSize': percentileResponse[0]['sample_size'],
    };
  }
}
```

### UI Components

Use `fl_chart` for visualizations. Use `intl` package for number formatting (1,234 km).

Empty state: "Start logging flights to see your stats!"

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): overview statistics screen with percentile badge (#13)`

---

## Issue #14: Flight Calendar Screen

### Files

- `lib/screens/stats/calendar_screen.dart`
- Update `lib/services/stats_service.dart` with `getMonthlyCounts(int year)`

### Implementation

```dart
Future<List<int>> getMonthlyCounts(int year) async {
  final response = await _client
      .from('flights')
      .select('departure_time')
      .eq('status', 'completed')
      .gte('departure_time', '$year-01-01')
      .lt('departure_time', '${year + 1}-01-01');

  final counts = List<int>.filled(12, 0);
  for (final row in response as List) {
    final month = DateTime.parse(row['departure_time'] as String).month - 1;
    counts[month]++;
  }
  return counts;
}
```

Use `fl_chart.BarChart` with:
- 12 bars (Jan-Dec)
- Neon pink (#FF10F0) bars
- Black background
- White axis labels

Year dropdown: Derive from min/max departure_time in user's flights.

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): flight calendar screen with bar chart (#14)`

---

## Issue #15: Geographic & Airline Statistics

### Files

- `lib/screens/stats/geo_airline_screen.dart`
- Add `getGeoStats()` and `getAirlineStats()` to `lib/services/stats_service.dart`

### Queries

```dart
Future<Map<String, dynamic>> getGeoStats() async {
  // Top airport/route from views
  final topAirport = await _client
      .from('user_top_airports')
      .select('iata_code, visit_count')
      .order('visit_count', ascending: false)
      .limit(1)
      .single();

  final topRoute = await _client
      .from('user_top_routes')
      .select('route_pair, flight_count')
      .order('flight_count', ascending: false)
      .limit(1)
      .single();

  // Continents/countries/cities: client-side Set from flights
  final flights = await _client.from('flights').select('''
    departure:airports!flights_departure_iata_fkey(continent, country, city),
    arrival:airports!flights_arrival_iata_fkey(continent, country, city)
  ''').eq('status', 'completed');

  final continents = <String>{};
  final countries = <String>{};
  final cities = <String>{};

  for (final row in flights as List) {
    final dep = row['departure'] as Map?;
    final arr = row['arrival'] as Map?;
    if (dep?['continent'] != null) continents.add(dep!['continent']);
    if (dep?['country'] != null) countries.add(dep!['country']);
    if (dep?['city'] != null) cities.add(dep!['city']);
    if (arr?['continent'] != null) continents.add(arr!['continent']);
    if (arr?['country'] != null) countries.add(arr!['country']);
    if (arr?['city'] != null) cities.add(arr!['city']);
  }

  return {
    'continents': continents.length,
    'countries': countries.length,
    'cities': cities.length,
    'topAirport': topAirport,
    'topRoute': topRoute,
  };
}
```

Use `fl_chart.PieChart` for alliance breakdown.

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): geographic and airline statistics screen (#15)`

---

## Issue #16: Aircraft Statistics

### Files

- `lib/screens/stats/aircraft_screen.dart`
- Add `getAircraftStats()` to `lib/services/stats_service.dart`

### Query

```dart
Future<Map<String, int>> getAircraftStats() async {
  final response = await _client
      .from('flights')
      .select('aircraft:aircraft_types(manufacturer)')
      .eq('status', 'completed');

  final byManufacturer = <String, int>{};
  for (final row in response as List) {
    final manufacturer = row['aircraft']?['manufacturer'] ?? 'Unknown';
    byManufacturer[manufacturer] = (byManufacturer[manufacturer] ?? 0) + 1;
  }
  return byManufacturer;
}
```

**Critical:** Handle null `aircraft_iata` as explicit "Unknown" bucket.

Use `fl_chart.PieChart` with distinct colors.

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): aircraft manufacturer statistics screen (#16)`

---

## Issue #17: Compatibility Quiz Flow

### Files

- `lib/screens/compat/compat_screen.dart`
- `lib/services/compat_service.dart`

### Service

```dart
class CompatService {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> sendRequest(String targetUserId) async {
    await _client.from('compat_requests').insert({
      'requester_id': _client.auth.currentUser!.id,
      'target_user_id': targetUserId,
      'status': 'pending',
    });
  }

  Future<void> acceptRequest(String requestId) async {
    await _client.from('compat_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  Future<void> declineRequest(String requestId) async {
    await _client.from('compat_requests')
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  Future<Map<String, dynamic>> getReport(String requestId) async {
    final response = await _client.rpc('get_compat_report', params: {
      'request_id': requestId,
    });
    return response[0] as Map<String, dynamic>;
  }
}
```

### UI States

1. Send request form
2. Pending requests list (incoming)
3. "Awaiting acceptance" for sent requests
4. Report view (aggregate overlap data only)

**Validation:** flutter analyze + flutter test

**Commit:** `feat(mobile): compatibility quiz flow with consent gating (#17)`

---

## Final Steps

### Update FEATURES.md

After each issue, update `docs/FEATURES.md` status table:

```markdown
| # | Feature | Status | Notes |
|---|---|---|---|
| ... | ... | ... | ... |
| Mobile Auth | ✅ Built | `lib/screens/auth/*`, `lib/providers/auth_provider.dart` |
| Mobile Map | ✅ Built | `lib/screens/map/map_screen.dart` |
| ... | ... | ... | ... |
```

### Run Full Validation Suite

```bash
cd apps/mobile
flutter pub get
flutter analyze  # Must pass with no errors
flutter test     # Must pass all tests
```

Note: `flutter build apk --release` requires Android SDK. CI will handle this.

### Push and Create Draft PR

```bash
git push origin feature/mobile-ui

gh pr create --draft --base main --title "feat(mobile): complete Flutter app implementation" --body "$(cat <<'EOF'
## Summary
Implements complete Flutter mobile app mirroring web functionality:
- ✅ Supabase auth & client wiring (#10)
- ✅ MapLibre flight-arc map with status-based styling (#11)
- ✅ Flight entry (manual + auto-lookup via Edge Function) (#12)
- ✅ Overview stats (mileage, duration, count, percentile) (#13)
- ✅ Flight calendar (month/day toggle, bar chart) (#14)
- ✅ Geographic & airline statistics (#15)
- ✅ Aircraft manufacturer statistics (#16)
- ✅ Compatibility quiz flow (#17)

## Validation
\`\`\`
flutter analyze - PASSED
flutter test - PASSED
\`\`\`

## Known Limitations
- No content export (per ADR-0003: web-only, browser APIs)
- Android SDK not available locally; CI builds APK

## Backend & Docs
- ✅ No backend modifications
- ✅ No apps/web/ changes
- ✅ docs/FEATURES.md updated

## Issues
Closes #10, #11, #12, #13, #14, #15, #16, #17
EOF
)"
```

---

## Testing Strategy

### Unit Tests (test/widget_test.dart)

Add tests for each service:

```dart
test('FlightPathService generates arc coordinates', () {
  final service = FlightPathService();
  final arc = service.greatCircleArc(
    fromLat: 0, fromLng: 0,
    toLat: 10, toLng: 10,
  );
  expect(arc.length, equals(101)); // 100 segments + 1
});
```

### Integration Tests (Requires Android SDK)

Create `test_driver/app_test.dart` for full E2E flows:

```dart
testWidgets('User can sign up and view map', (tester) async {
  // ... test full flow
});
```

---

## Common Issues & Solutions

### Issue: Supabase not initialized in tests
**Solution:** Use simplified unit tests that don't require platform channels (like current widget_test.dart)

### Issue: MapLibre plugin not available
**Solution:** Install Android SDK or rely on CI for full device testing

### Issue: Deprecation warnings from supabase_flutter
**Solution:** These are acceptable for now; API is stable despite warnings

### Issue: flutter analyze shows const constructor warnings
**Solution:** Add `const` keyword to constructors where possible

---

## Brand Guidelines Reminder

- Background: `#0a0a0a` (black)
- Accent: `#FF10F0` (neon pink) - highlights ONLY, not body text
- WCAG AA contrast: 4.5:1 minimum for text
- Loading states: CircularProgressIndicator in neon pink
- Empty states: Helpful message + call-to-action
- Error states: Red accent with clear error message

---

## ADR Constraints (Critical!)

- **ADR-0002:** MapLibre only, NO Mapbox dependencies
- **ADR-0003:** NO monetization UI (paywalls, upsells)
- **ADR-0003:** NO content export on mobile (web-only feature)
- **ADR-0003:** Build against FROZEN backend schema
- **COLLABORATION.md:** NO changes to `apps/web/` or `supabase/`

---

## Commit Message Format

```
feat(mobile): <description> (#<issue-number>)

<detailed explanation>

- Bullet point changes
- More details
- Addresses acceptance criteria
```

**No "Claude" or "AI-generated" mentions** per user's global CLAUDE.md

---

## Questions or Blockers?

If you encounter issues:

1. Check the web implementation (`apps/web/lib/*.ts`) for reference
2. Review the ADRs in `docs/ADR-*.md`
3. Verify against `docs/ARCHITECTURE.md` section 5 for flight status rules
4. Check `docs/DATA_MODEL.md` for schema details

---

## Estimated Effort Per Issue

- Issue #11 (Map): 3-4 hours (MapLibre integration complex)
- Issue #12 (Flight Entry): 2-3 hours (Edge Function + form)
- Issue #13 (Overview Stats): 2 hours (queries + UI)
- Issue #14 (Calendar): 2 hours (fl_chart integration)
- Issue #15 (Geo/Airline): 2-3 hours (multiple charts)
- Issue #16 (Aircraft): 1-2 hours (similar to #15)
- Issue #17 (Compat Quiz): 2 hours (RPC + UI states)

**Total:** ~14-18 hours

---

**Good luck! The foundation is solid. Follow this guide step-by-step and you'll have a complete mobile app mirroring the web functionality.**
