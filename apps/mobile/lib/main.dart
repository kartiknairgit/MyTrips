import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same status → styling rules as apps/web/lib/flightPath.ts:
//   scheduled  -> faint dotted arc
//   in_transit -> dashed, animated, airline colour
//   completed  -> solid, airline colour
// Great-circle arc math + MapLibre layer wiring lives in
// lib/map/flight_map_view.dart (to be built alongside apps/web/components/MapView.tsx).
// Map style: same free OpenFreeMap style URL as the web app — no token needed.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const FlightPathApp());
}

class FlightPathApp extends StatelessWidget {
  const FlightPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlightPath',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text('FlightPath map view goes here'),
        ),
      ),
    );
  }
}
