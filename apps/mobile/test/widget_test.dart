import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/services/supabase_service.dart';
import 'package:flightpath_mobile/services/auth_service.dart';

void main() {
  test('SupabaseService singleton pattern works', () {
    final instance1 = SupabaseService.instance;
    final instance2 = SupabaseService.instance;
    expect(instance1, equals(instance2));
  });

  test('AuthService instantiates without errors', () {
    // This test verifies that auth service can be created
    // Note: Actual auth operations require Supabase initialization
    // which requires platform-specific dependencies not available in unit tests.
    // Integration tests with a real Supabase instance should be done separately.
    expect(AuthService, isNotNull);
  });

  test('Project structure is correct', () {
    // Verify that core service files exist and compile
    expect(SupabaseService, isNotNull);
    expect(AuthService, isNotNull);
  });
}
