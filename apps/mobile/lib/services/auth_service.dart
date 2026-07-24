import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for authentication operations: sign up, sign in, sign out.
/// Wraps Supabase Auth methods with app-specific error handling.
class AuthService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Get the current auth session, or null if not signed in.
  Session? get currentSession => _client.auth.currentSession;

  /// Get the current user, or null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new user with email and password.
  /// Throws AuthException on failure.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in an existing user with email and password.
  /// Throws AuthException on failure.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  /// Throws AuthException on failure.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
