import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import 'qr_display_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _subjectController = TextEditingController();
  final _sessionService = SessionService();
  final _authService = AuthService();

  int _durationMinutes = 10;
  bool _isLoading = false;

  Future<void> _createSession() async {
    if (_subjectController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final teacherId = _authService.currentUser?.uid ?? '';

    final session = await _sessionService.createSession(
      teacherId: teacherId,
      subject: _subjectController.text.trim(),
      durationMinutes: _durationMinutes,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QrDisplayScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Attendance Session')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject / Class Name',
                hintText: 'e.g. Data Structures - Period 3',
              ),
            ),
            const SizedBox(height: 20),
            const Text('QR valid for:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _durationMinutes,
              items: const [5, 10, 15, 20]
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes')))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _durationMinutes = val);
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createSession,
                    child: const Text('Generate QR Code'),
                  ),
          ],
        ),
      ),
    );
  }
}