import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/session.dart';
import 'session_attendance_screen.dart';

class QrDisplayScreen extends StatefulWidget {
  final AttendanceSession session;

  const QrDisplayScreen({super.key, required this.session});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    final remaining = widget.session.expiresAt.difference(DateTime.now());
    setState(() {
      _timeLeft = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _timeLeft == Duration.zero;

    return Scaffold(
      appBar: AppBar(title: Text(widget.session.subject)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isExpired) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: widget.session.sessionId,
                  version: QrVersions.auto,
                  size: 280,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Expires in: ${_formatDuration(_timeLeft)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ] else ...[
              const Icon(Icons.timer_off, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'This QR code has expired',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('View Attendance'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionAttendanceScreen(session: widget.session),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}