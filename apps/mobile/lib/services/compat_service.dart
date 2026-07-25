import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CompatService {
  final SupabaseClient _client;

  CompatService({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false);

  static Map<String, dynamic> requestInsert(
      String requesterId, String targetId) {
    if (!_uuid.hasMatch(targetId)) {
      throw const FormatException('Enter a complete flyer user ID.');
    }
    if (requesterId == targetId) {
      throw const FormatException('You cannot compare with yourself.');
    }
    return {
      'requester_id': requesterId,
      'target_id': targetId,
      'status': 'pending',
    };
  }

  Future<void> sendRequest(String targetId) async {
    final userId = _requireUser();
    final payload = requestInsert(userId, targetId.trim());
    final existing = await _client
        .from('compat_requests')
        .select('id')
        .eq('requester_id', userId)
        .eq('target_id', targetId.trim())
        .maybeSingle();
    if (existing != null) {
      throw Exception('A request to this flyer already exists.');
    }
    await _client.from('compat_requests').insert(payload);
  }

  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final response = await _client
        .from('compat_requests')
        .select()
        .eq('requester_id', _requireUser())
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    final response = await _client
        .from('compat_requests')
        .select()
        .eq('target_id', _requireUser())
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> acceptRequest(String requestId) =>
      _respond(requestId, 'accepted');

  Future<void> declineRequest(String requestId) =>
      _respond(requestId, 'declined');

  Future<void> _respond(String requestId, String status) async {
    await _client
        .from('compat_requests')
        .update({
          'status': status,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('target_id', _requireUser());
  }

  Future<Map<String, dynamic>?> getCompatReport(String requestId) async {
    final request = await _client
        .from('compat_requests')
        .select('status')
        .eq('id', requestId)
        .maybeSingle();
    if (request == null) throw Exception('Compatibility request not found.');
    if (request['status'] != 'accepted') {
      throw Exception('Waiting for the invited flyer to accept.');
    }
    final response = await _client
        .rpc('get_compat_report', params: {'request_id': requestId});
    if (response is! List || response.isEmpty) return null;
    return response.first as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAcceptedCompats() async {
    final userId = _requireUser();
    final response = await _client
        .from('compat_requests')
        .select()
        .eq('status', 'accepted')
        .or('requester_id.eq.$userId,target_id.eq.$userId')
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  String _requireUser() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Sign in to use compatibility.');
    return id;
  }
}
