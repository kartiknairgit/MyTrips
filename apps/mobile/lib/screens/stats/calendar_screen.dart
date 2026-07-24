import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/stats_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _statsService = StatsService();

  List<int>? _availableYears;
  int? _selectedYear;
  Map<int, int>? _monthlyCounts;
  Map<int, int>? _dailyCounts;
  bool _dayView = false;
  int _selectedMonth = DateTime.now().month;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadYearRange();
  }

  Future<void> _loadYearRange() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final years = await _statsService.getYearRange();

      if (years == null || years.isEmpty) {
        setState(() {
          _availableYears = null;
          _selectedYear = null;
          _isLoading = false;
        });
        return;
      }

      // Default to most recent year
      final selectedYear = years.last;

      setState(() {
        _availableYears = years;
        _selectedYear = selectedYear;
      });

      await _loadMonthlyCounts(selectedYear);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonthlyCounts(int year) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final counts = await _statsService.getMonthlyCounts(year);

      setState(() {
        _monthlyCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDailyCounts() async {
    if (_selectedYear == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final counts =
          await _statsService.getDailyCounts(_selectedYear!, _selectedMonth);
      if (mounted) {
        setState(() {
          _dailyCounts = counts;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onYearChanged(int? year) {
    if (year != null && year != _selectedYear) {
      setState(() {
        _selectedYear = year;
      });
      _loadMonthlyCounts(year);
      if (_dayView) _loadDailyCounts();
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
          'Flight Calendar',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadYearRange,
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
              'Loading calendar data...',
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
              onPressed: _loadYearRange,
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

    if (_availableYears == null || _availableYears!.isEmpty) {
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
                Icons.calendar_today,
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
                'Start adding flights to see your calendar!',
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
          // Year selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFFFF10F0), size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Year:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    dropdownColor: const Color(0xFF1a1a1a),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    underline: Container(),
                    isExpanded: true,
                    items: _availableYears!.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: _onYearChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Month')),
              ButtonSegment(value: true, label: Text('Day')),
            ],
            selected: {_dayView},
            onSelectionChanged: (selection) {
              setState(() => _dayView = selection.first);
              if (_dayView) _loadDailyCounts();
            },
          ),
          if (_dayView) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(
                  labelText: 'Month', border: OutlineInputBorder()),
              items: List.generate(
                12,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(
                      DateFormat('MMMM').format(DateTime(2000, index + 1))),
                ),
              ),
              onChanged: (month) {
                if (month == null) return;
                setState(() => _selectedMonth = month);
                _loadDailyCounts();
              },
            ),
          ],
          const SizedBox(height: 24),

          // Monthly bar chart
          if (!_dayView && _monthlyCounts != null) ...[
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
                  const Text(
                    'Monthly Flight Count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 300,
                    child: _buildBarChart(),
                  ),
                ],
              ),
            ),
          ],
          if (_dayView && _dailyCounts != null) _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width < 360 ? 5 : 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: _dailyCounts!.entries.map((entry) {
          final count = entry.value;
          return Semantics(
            label:
                'Day ${entry.key}, $count ${count == 1 ? 'flight' : 'flights'}',
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: count == 0
                    ? Colors.white10
                    : const Color(0xFFFF10F0)
                        .withOpacity((0.35 + count * 0.15).clamp(0.0, 1.0)),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${entry.key}',
                  style: TextStyle(
                      color: count > 0 ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart() {
    final maxCount = _monthlyCounts!.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxCount > 0 ? (maxCount + 1).toDouble() : 5.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barGroups: List.generate(12, (index) {
          final month = index + 1;
          final count = _monthlyCounts![month] ?? 0;

          return BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: const Color(0xFFFF10F0),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white12,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final monthIndex = value.toInt();
                if (monthIndex < 1 || monthIndex > 12) {
                  return const SizedBox.shrink();
                }
                final monthName =
                    DateFormat('MMM').format(DateTime(2000, monthIndex));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    monthName,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month =
                  DateFormat('MMMM').format(DateTime(2000, group.x + 1));
              final count = rod.toY.toInt();
              final plural = count == 1 ? 'flight' : 'flights';
              return BarTooltipItem(
                '$month\n$count $plural',
                const TextStyle(
                  color: Color(0xFFFF10F0),
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
