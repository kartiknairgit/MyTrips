import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/flight_service.dart';
import 'flight_confirm_screen.dart';

class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({super.key});

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flightService = FlightService();

  // Form controllers
  final _flightNumberController = TextEditingController();
  final _departureIataController = TextEditingController();
  final _arrivalIataController = TextEditingController();
  final _airlineIataController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  DateTime? _departureTime;
  DateTime? _arrivalTime;

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _departureIataController.dispose();
    _arrivalIataController.dispose();
    _airlineIataController.dispose();
    super.dispose();
  }

  Future<void> _handleAutoLookup() async {
    if (_flightNumberController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a flight number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final flightData = await _flightService.lookupFlight(
        flightCode: _flightNumberController.text.trim(),
        date: _selectedDate,
      );

      if (!mounted) return;

      // Navigate to confirm screen with looked-up data
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlightConfirmScreen(
            flightData: flightData,
            source: 'auto',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_departureTime == null || _arrivalTime == null) {
      setState(() {
        _error = 'Please select departure and arrival times';
      });
      return;
    }

    // Build manual flight data
    final flightData = {
      'flight_number': _flightNumberController.text.trim(),
      'airline_iata': _airlineIataController.text.trim().isEmpty
          ? null
          : _airlineIataController.text.trim(),
      'departure_iata': _departureIataController.text.trim().toUpperCase(),
      'arrival_iata': _arrivalIataController.text.trim().toUpperCase(),
      'departure_time': _departureTime!.toIso8601String(),
      'arrival_time': _arrivalTime!.toIso8601String(),
      'source': 'manual',
    };

    if (!mounted) return;

    // Navigate to confirm screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlightConfirmScreen(
          flightData: flightData,
          source: 'manual',
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF10F0),
              surface: Color(0xFF0a0a0a),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDateTime(bool isDeparture) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF10F0),
              surface: Color(0xFF0a0a0a),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF10F0),
              surface: Color(0xFF0a0a0a),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final dateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );

      setState(() {
        if (isDeparture) {
          _departureTime = dateTime;
        } else {
          _arrivalTime = dateTime;
        }
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Flight',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Auto-lookup section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF10F0), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Quick Lookup',
                      style: TextStyle(
                        color: Color(0xFFFF10F0),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _flightNumberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Flight Number (e.g., SQ308)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(Icons.calendar_today,
                                color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleAutoLookup,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.black),
                      label: Text(
                        _isLoading ? 'Looking up...' : 'Auto-Lookup',
                        style: const TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF10F0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR ENTER MANUALLY',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),

              const SizedBox(height: 24),

              // Manual entry section
              TextFormField(
                controller: _departureIataController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Departure Airport (IATA Code)',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'e.g., SIN',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required for manual entry';
                  }
                  if (value.length != 3) {
                    return 'Must be 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _arrivalIataController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Arrival Airport (IATA Code)',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'e.g., SYD',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required for manual entry';
                  }
                  if (value.length != 3) {
                    return 'Must be 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _airlineIataController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Airline Code (Optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'e.g., SQ',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectDateTime(true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _departureTime == null
                            ? 'Departure Time (tap to select)'
                            : 'Departure: ${DateFormat('MMM d, y HH:mm').format(_departureTime!)}',
                        style: TextStyle(
                          color: _departureTime == null
                              ? Colors.white54
                              : Colors.white,
                        ),
                      ),
                      const Icon(Icons.access_time, color: Colors.white70),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectDateTime(false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _arrivalTime == null
                            ? 'Arrival Time (tap to select)'
                            : 'Arrival: ${DateFormat('MMM d, y HH:mm').format(_arrivalTime!)}',
                        style: TextStyle(
                          color: _arrivalTime == null
                              ? Colors.white54
                              : Colors.white,
                        ),
                      ),
                      const Icon(Icons.access_time, color: Colors.white70),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Manual submit button
              ElevatedButton(
                onPressed: _handleManualSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Continue with Manual Entry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
