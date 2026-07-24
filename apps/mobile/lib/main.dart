import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/flights_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/configuration_screen.dart';

// Same status → styling rules as apps/web/lib/flightPath.ts:
//   scheduled  -> faint dotted arc
//   in_transit -> dashed, animated, airline colour
//   completed  -> solid, airline colour
// Great-circle arc math + MapLibre layer wiring lives in
// lib/map/flight_map_view.dart (to be built alongside apps/web/components/MapView.tsx).
// Map style: same free OpenFreeMap style URL as the web app — no token needed.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with environment-provided credentials
  await SupabaseService.initialize();

  runApp(const FlightPathApp());
}

class FlightPathApp extends StatelessWidget {
  const FlightPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isConfigured) {
      return MaterialApp(
        title: 'FlightPath',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: const ConfigurationScreen(),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'FlightPath',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: const AuthGate(),
      ),
    );
  }

  static final ThemeData _theme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0a0a0a),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFF10F0),
      secondary: Color(0xFFFF10F0),
      surface: Color(0xFF0a0a0a),
    ),
  );
}

/// Routes user to login screen if not authenticated, or home screen if authenticated.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0a0a0a),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF10F0),
              ),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return ChangeNotifierProvider(
            key: ValueKey(authProvider.currentUser!.id),
            create: (_) => FlightsProvider(),
            child: const MapScreen(),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
