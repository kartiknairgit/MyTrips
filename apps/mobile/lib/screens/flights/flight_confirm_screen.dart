import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/flight_service.dart';
import '../../providers/flights_provider.dart';

class FlightConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> flightData;
  final String source; // 'auto' or 'manual'

  const FlightConfirmScreen({
    super.key,
    required this.flightData,
    required this.source,
  });

  @override
  State<FlightConfirmScreen> createState() => _FlightConfirmScreenState();
}

class _FlightConfirmScreenState extends State<FlightConfirmScreen> {
  final _flightService = FlightService();
  bool _isSaving = false;
  String? _error;

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _flightService.saveFlight(widget.flightData);

      if (!mounted) return;

      // Refresh flights provider
      await context.read<FlightsProvider>().refresh();

      if (!mounted) return;

      // Pop back to map screen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flight added successfully!'),
          backgroundColor: Color(0xFFFF10F0),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a0a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Confirm Flight',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.source == 'auto'
                    ? const Color(0xFFFF10F0)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.source == 'auto' ? 'AUTO-LOOKED UP' : 'MANUAL ENTRY',
                style: TextStyle(
                  color: widget.source == 'auto' ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Flight details card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flight number
                  _buildDetailRow(
                    icon: Icons.flight,
                    label: 'Flight Number',
                    value: widget.flightData['flight_number']?.toString() ??
                        'Unknown',
                  ),

                  const Divider(color: Colors.white24, height: 32),

                  // Route
                  _buildDetailRow(
                    icon: Icons.flight_takeoff,
                    label: 'From',
                    value: widget.flightData['departure_iata']?.toString() ??
                        'Unknown',
                  ),

                  const SizedBox(height: 16),

                  _buildDetailRow(
                    icon: Icons.flight_land,
                    label: 'To',
                    value: widget.flightData['arrival_iata']?.toString() ??
                        'Unknown',
                  ),

                  const Divider(color: Colors.white24, height: 32),

                  // Times
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: 'Departure',
                    value: _formatDateTime(
                        widget.flightData['departure_time']?.toString()),
                  ),

                  const SizedBox(height: 16),

                  _buildDetailRow(
                    icon: Icons.access_time_filled,
                    label: 'Arrival',
                    value: _formatDateTime(
                        widget.flightData['arrival_time']?.toString()),
                  ),

                  if (widget.flightData['airline_iata'] != null) ...[
                    const Divider(color: Colors.white24, height: 32),
                    _buildDetailRow(
                      icon: Icons.airlines,
                      label: 'Airline',
                      value: widget.flightData['airline_iata'].toString(),
                    ),
                  ],

                  if (widget.flightData['status'] != null) ...[
                    const Divider(color: Colors.white24, height: 32),
                    _buildDetailRow(
                      icon: Icons.info_outline,
                      label: 'Status',
                      value: widget.flightData['status'].toString(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Note about editing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Review the details above. Tap back to make changes.',
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF10F0),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Save Flight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF10F0), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('MMM d, y • HH:mm').format(dateTime);
    } catch (e) {
      return isoString;
    }
  }
}
