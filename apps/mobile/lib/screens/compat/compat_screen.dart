import 'package:flutter/material.dart';
import '../../services/compat_service.dart';

class CompatScreen extends StatefulWidget {
  const CompatScreen({super.key});

  @override
  State<CompatScreen> createState() => _CompatScreenState();
}

class _CompatScreenState extends State<CompatScreen> with SingleTickerProviderStateMixin {
  final _compatService = CompatService();
  final _emailController = TextEditingController();

  late TabController _tabController;

  List<Map<String, dynamic>> _sentRequests = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _acceptedCompats = [];

  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _compatService.getSentRequests(),
        _compatService.getReceivedRequests(),
        _compatService.getAcceptedCompats(),
      ]);

      setState(() {
        _sentRequests = results[0];
        _receivedRequests = results[1];
        _acceptedCompats = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _sendError = 'Please enter an email address';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      await _compatService.sendRequest(email);
      _emailController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compatibility request sent!'),
          backgroundColor: Color(0xFFFF10F0),
        ),
      );

      await _loadData();
    } catch (e) {
      setState(() {
        _sendError = e.toString();
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _handleAccept(String requestId) async {
    try {
      await _compatService.acceptRequest(requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted!'),
          backgroundColor: Color(0xFFFF10F0),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleDecline(String requestId) async {
    try {
      await _compatService.declineRequest(requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request declined'),
          backgroundColor: Colors.grey,
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _viewReport(String otherUserId, String otherUserEmail) async {
    try {
      final report = await _compatService.getCompatReport(otherUserId);

      if (!mounted) return;

      if (report == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No compatibility data available'),
            backgroundColor: Colors.grey,
          ),
        );
        return;
      }

      _showReportDialog(otherUserEmail, report);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showReportDialog(String otherUserEmail, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: Text(
          'Compatibility with $otherUserEmail',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportItem('Shared Airports', report['shared_airports']?.toString() ?? '0'),
              _buildReportItem('Shared Airlines', report['shared_airlines']?.toString() ?? '0'),
              _buildReportItem('Shared Routes', report['shared_routes']?.toString() ?? '0'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFFFF10F0))),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFF10F0),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a0a),
        elevation: 0,
        title: const Text(
          'Compatibility',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF10F0),
          labelColor: const Color(0xFFFF10F0),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Send'),
            Tab(text: 'Requests'),
            Tab(text: 'Accepted'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF10F0)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF10F0),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSendTab(),
                    _buildRequestsTab(),
                    _buildAcceptedTab(),
                  ],
                ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Send Compatibility Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the email of another user to compare your flight histories.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _sendError!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: _isSending ? null : _handleSendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF10F0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text('Send Request'),
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Sent Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_sentRequests.isEmpty)
            const Text(
              'No sent requests',
              style: TextStyle(color: Colors.white54),
            )
          else
            ..._sentRequests.map((request) {
              final requestedEmail = request['requested']?['email'] ?? 'Unknown';
              final status = request['status'] as String;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestedEmail,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'accepted'
                                  ? Colors.greenAccent
                                  : status == 'declined'
                                      ? Colors.redAccent
                                      : Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pending Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_receivedRequests.isEmpty)
            const Text(
              'No pending requests',
              style: TextStyle(color: Colors.white54),
            )
          else
            ..._receivedRequests.map((request) {
              final requesterEmail = request['requester']?['email'] ?? 'Unknown';
              final requestId = request['id'] as String;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF10F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterEmail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAccept(requestId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF10F0),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleDecline(requestId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAcceptedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accepted Compatibilities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_acceptedCompats.isEmpty)
            const Text(
              'No accepted compatibilities yet',
              style: TextStyle(color: Colors.white54),
            )
          else
            ..._acceptedCompats.map((compat) {
              final requesterProfile = compat['requester'] as Map<String, dynamic>?;
              final requestedProfile = compat['requested'] as Map<String, dynamic>?;

              // Determine which user is "the other user"
              final currentUserId = compat['requester_id'];
              final otherProfile = currentUserId == requesterProfile?['id']
                  ? requestedProfile
                  : requesterProfile;

              final otherEmail = otherProfile?['email'] ?? 'Unknown';
              final otherUserId = otherProfile?['id'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otherEmail,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _viewReport(otherUserId, otherEmail),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF10F0),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('View Report'),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
