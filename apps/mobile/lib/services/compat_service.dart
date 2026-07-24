import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for compatibility quiz operations.
class CompatService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Send a compatibility request to another user by their email.
  Future<void> sendRequest(String otherUserEmail) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Look up the other user by email
      final userResponse = await _client
          .from('profiles')
          .select('id')
          .eq('email', otherUserEmail)
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('User not found with email: $otherUserEmail');
      }

      final otherUserId = userResponse['id'] as String;

      if (otherUserId == userId) {
        throw Exception('Cannot send request to yourself');
      }

      // Check if request already exists
      final existingRequest = await _client
          .from('compat_requests')
          .select()
          .eq('requester_id', userId)
          .eq('requested_id', otherUserId)
          .maybeSingle();

      if (existingRequest != null) {
        throw Exception('Request already sent to this user');
      }

      // Create request
      await _client.from('compat_requests').insert({
        'requester_id': userId,
        'requested_id': otherUserId,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to send compatibility request: $e');
    }
  }

  /// Get all pending requests sent by current user.
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('compat_requests')
          .select(
              '*, requested:profiles!compat_requests_requested_id_fkey(email)')
          .eq('requester_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch sent requests: $e');
    }
  }

  /// Get all pending requests received by current user.
  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('compat_requests')
          .select(
              '*, requester:profiles!compat_requests_requester_id_fkey(email)')
          .eq('requested_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch received requests: $e');
    }
  }

  /// Accept a compatibility request.
  Future<void> acceptRequest(String requestId) async {
    try {
      await _client
          .from('compat_requests')
          .update({'status': 'accepted'}).eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to accept request: $e');
    }
  }

  /// Decline a compatibility request.
  Future<void> declineRequest(String requestId) async {
    try {
      await _client
          .from('compat_requests')
          .update({'status': 'declined'}).eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to decline request: $e');
    }
  }

  /// Get compatibility report for a specific user.
  /// Returns aggregate stats (shared airports, airlines, routes) via get_compat_report RPC.
  Future<Map<String, dynamic>?> getCompatReport(String otherUserId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if there's an accepted request between these users
      final request = await _client
          .from('compat_requests')
          .select()
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,requested_id.eq.$userId')
          .or('requester_id.eq.$otherUserId,requested_id.eq.$otherUserId')
          .maybeSingle();

      if (request == null) {
        throw Exception('No accepted compatibility request with this user');
      }

      // Call get_compat_report RPC
      final response = await _client.rpc('get_compat_report', params: {
        'other_user': otherUserId,
      });

      if (response == null) {
        return null;
      }

      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch compatibility report: $e');
    }
  }

  /// Get list of users with accepted compatibility requests.
  Future<List<Map<String, dynamic>>> getAcceptedCompats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('compat_requests')
          .select('''
            *,
            requester:profiles!compat_requests_requester_id_fkey(id, email),
            requested:profiles!compat_requests_requested_id_fkey(id, email)
          ''')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,requested_id.eq.$userId');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch accepted compatibilities: $e');
    }
  }
}
