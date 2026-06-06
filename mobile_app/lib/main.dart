import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DateTimeChecker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DateTimeCheckerPage(),
    );
  }
}

class DateTimeCheckerPage extends StatefulWidget {
  const DateTimeCheckerPage({super.key});

  @override
  State<DateTimeCheckerPage> createState() => _DateTimeCheckerPageState();
}

class _DateTimeCheckerPageState extends State<DateTimeCheckerPage> {
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  String _message = '';
  bool _isValid = false;
  bool _isLoading = false;
  bool _hasResult = false;

  Future<void> _check() async {
    final day = _dayController.text.trim();
    final month = _monthController.text.trim();
    final year = _yearController.text.trim();

    if (day.isEmpty || month.isEmpty || year.isEmpty) {
      setState(() {
        _message = 'Please fill in all fields.';
        _isValid = false;
        _hasResult = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasResult = false;
    });

    try {
      final response = await http.post(
        Uri.parse('/api/datetime/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'day': day, 'month': month, 'year': year}),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _message = data['message'];
        _isValid = data['valid'];
        _hasResult = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Connection error. Please try again.';
        _isValid = false;
        _hasResult = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clear() {
    _dayController.clear();
    _monthController.clear();
    _yearController.clear();
    setState(() {
      _message = '';
      _hasResult = false;
    });
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text(
                      'DateTimeChecker',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildTextField(_dayController, 'Day', '1 - 31'),
                    const SizedBox(height: 16),
                    _buildTextField(_monthController, 'Month', '1 - 12'),
                    const SizedBox(height: 16),
                    _buildTextField(_yearController, 'Year', 'e.g. 2000'),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _check,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Check',
                                    style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clear,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Clear',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                    if (_hasResult) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isValid
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isValid ? Colors.green : Colors.red,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _isValid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
