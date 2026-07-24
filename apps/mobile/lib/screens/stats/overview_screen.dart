import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/stats_service.dart';
import '../../models/stats.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/percentile_badge.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final _statsService = StatsService();
  final _numberFormat = NumberFormat('#,###');
  final _decimalFormat = NumberFormat('#,###.0');

  OverviewStats? _overviewStats;
  MileagePercentile? _percentile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _statsService.getOverviewStats(),
        _statsService.getMileagePercentile(),
      ]);

      setState(() {
        _overviewStats = results[0] as OverviewStats;
        _percentile = results[1] as MileagePercentile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
        title: const Text(
          'Overview',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF10F0)),
            SizedBox(height: 16),
            Text(
              'Loading your statistics...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF10F0),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_overviewStats == null || _percentile == null) {
      return const Center(
        child: Text(
          'No statistics available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Check if user has no flights
    if (_overviewStats!.totalFlights == 0) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bar_chart,
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'No flights logged yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start adding flights to see your statistics!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Percentile badge
          PercentileBadge(percentile: _percentile!),
          const SizedBox(height: 24),

          // Total flights
          StatCard(
            icon: Icons.flight,
            label: 'Total Flights',
            value: _numberFormat.format(_overviewStats!.totalFlights),
          ),
          const SizedBox(height: 16),

          // Total kilometers
          StatCard(
            icon: Icons.public,
            label: 'Total Distance',
            value: '${_decimalFormat.format(_overviewStats!.totalKm)} km',
          ),
          const SizedBox(height: 16),

          // Total hours
          StatCard(
            icon: Icons.access_time,
            label: 'Total Hours',
            value: '${_decimalFormat.format(_overviewStats!.totalHours)} hrs',
          ),
        ],
      ),
    );
  }
}
