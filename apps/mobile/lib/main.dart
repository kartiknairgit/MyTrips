import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';

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
  await SupabaseService.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const FlightPathApp());
}

class FlightPathApp extends StatelessWidget {
  const FlightPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'FlightPath',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0a0a0a),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFF10F0),
            secondary: const Color(0xFFFF10F0),
            surface: const Color(0xFF0a0a0a),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
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
          // TODO: Replace with actual home screen once implemented
          return Scaffold(
            backgroundColor: const Color(0xFF0a0a0a),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to FlightPath!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signed in as: ${authProvider.currentUser?.email}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => authProvider.signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF10F0),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
