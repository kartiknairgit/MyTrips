import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/flights_provider.dart';
import '../../services/flight_service.dart';

class FlightConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> flightData;
  final String source;

  const FlightConfirmScreen({
    super.key,
    required this.flightData,
    required this.source,
  });

  @override
  State<FlightConfirmScreen> createState() => _FlightConfirmScreenState();
}

class _FlightConfirmScreenState extends State<FlightConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FlightService();
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in const [
        'flight_number',
        'airline_iata',
        'departure_iata',
        'arrival_iata',
        'departure_time',
        'arrival_time',
        'aircraft_iata',
      ])
        key: TextEditingController(
            text: widget.flightData[key]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final edited = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text,
        if (widget.flightData['status'] == 'cancelled') 'status': 'cancelled',
      };
      if (edited['aircraft_iata'] == '') edited.remove('aircraft_iata');
      final data = FlightService.prepareForSave(edited, source: widget.source);
      await _service.saveFlight(data);
      if (!mounted) return;
      await context.read<FlightsProvider>().refresh();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flight saved.'),
          backgroundColor: Color(0xFF087F5B),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _iata(String? value) {
    if (value == null || !RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim())) {
      return 'Enter a 3-letter IATA code';
    }
    return null;
  }

  String? _dateTime(String? value) {
    if (value == null || DateTime.tryParse(value.trim()) == null) {
      return 'Enter an ISO date and time';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm and edit')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.source == 'auto'
                    ? 'Auto-looked-up flight'
                    : 'Manual flight',
                style: const TextStyle(
                    color: Color(0xFFFF10F0), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review every field. Changes made here are saved as entered.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              _field('flight_number', 'Flight number', _required),
              _field('airline_iata', 'Airline IATA (optional)', null),
              _field('departure_iata', 'Departure IATA', _iata),
              _field('arrival_iata', 'Arrival IATA', _iata),
              _field('departure_time', 'Departure time (ISO 8601)', _dateTime),
              _field('arrival_time', 'Arrival time (ISO 8601)', _dateTime),
              _field('aircraft_iata', 'Aircraft IATA (optional)', null),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      key: const Key('save-error'),
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save flight'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
      String key, String label, String? Function(String?)? validator) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: Key('confirm-$key'),
        controller: _fields[key],
        validator: validator,
        textCapitalization: key.contains('iata') || key == 'flight_number'
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
