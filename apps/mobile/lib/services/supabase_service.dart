import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service for accessing the Supabase client throughout the app.
/// Mirrors the pattern from apps/web/lib/supabaseClient.ts, adapted for Flutter.
class SupabaseService {
  SupabaseService._();

  static SupabaseService? _instance;
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// The Supabase client instance. Access via SupabaseService.instance.client.
  SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase with environment-provided URL and anon key.
  /// Call this once in main() before runApp().
  ///
  /// URL and key should be passed via --dart-define:
  ///   flutter run \
  ///     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  ///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}
