import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../providers/flights_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/flight_path_service.dart';
import '../../models/flight.dart';
import '../flights/add_flight_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _mapController;
  final FlightPathService _flightPathService = FlightPathService();
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a0a),
        elevation: 0,
        title: const Text(
          'FlightPath',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<FlightsProvider>().refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF10F0)),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<FlightsProvider>(
        builder: (context, flightsProvider, _) {
          if (flightsProvider.isLoading && !_mapReady) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF10F0)),
                  SizedBox(height: 16),
                  Text(
                    'Loading your flights...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          if (flightsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    flightsProvider.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => flightsProvider.refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF10F0),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show empty state for new users
          if (flightsProvider.flights.isEmpty && _mapReady) {
            return Stack(
              children: [
                _buildMap(),
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF10F0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flight_takeoff,
                          color: Color(0xFFFF10F0),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No flights yet!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start logging your flights to see them mapped here.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AddFlightScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF10F0),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Add Your First Flight'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return _buildMap();
        },
      ),
      floatingActionButton: Consumer<FlightsProvider>(
        builder: (context, flightsProvider, _) {
          if (flightsProvider.flights.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddFlightScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFFFF10F0),
            child: const Icon(Icons.add, color: Colors.black),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return MapLibreMap(
      styleString: 'https://tiles.openfreemap.org/styles/liberty',
      initialCameraPosition: const CameraPosition(
        target: LatLng(20.0, 0.0),
        zoom: 2.0,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onStyleLoadedCallback: () {
        setState(() {
          _mapReady = true;
        });
        _addFlightArcs();
      },
      myLocationEnabled: false,
      compassEnabled: true,
    );
  }

  Future<void> _addFlightArcs() async {
    if (_mapController == null || !_mapReady) return;

    final flights = context.read<FlightsProvider>().flights;

    for (final flight in flights) {
      await _addFlightArc(flight);
    }
  }

  Future<void> _addFlightArc(Flight flight) async {
    if (_mapController == null) return;

    try {
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

      // Get paint properties based on flight status
      final currentStatus = flight.deriveStatus();
      final paint = _flightPathService.paintForStatus(
        currentStatus,
        flight.airlineColor,
      );

      // Add line layer with status-based styling
      await _mapController!.addLineLayer(
        sourceId,
        layerId,
        LineLayerProperties(
          lineColor: paint['line-color'] as String,
          lineWidth: (paint['line-width'] as num).toDouble(),
          lineOpacity: (paint['line-opacity'] as num?)?.toDouble(),
        ),
      );
    } catch (e) {
      debugPrint('Error adding flight arc for ${flight.id}: $e');
    }
  }
}
