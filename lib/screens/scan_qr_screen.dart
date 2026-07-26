import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/session_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _sessionService = SessionService();
  final _attendanceService = AttendanceService();
  final _authService = AuthService();
  final _deviceService = DeviceService();

  bool _isProcessing = false;
  String? _statusMessage;
  bool _success = false;

  Future<void> _handleScan(String sessionId) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Checking session...';
    });

    try {
      final session = await _sessionService.getSession(sessionId);

      if (session == null) {
        setState(() => _statusMessage = 'Invalid QR code.');
        return;
      }

      if (session.isExpired) {
        setState(() => _statusMessage = 'This QR code has expired.');
        return;
      }

      final AppUser? currentUser = await _authService.getCurrentAppUser();
      if (currentUser == null) {
        setState(() => _statusMessage = 'You must be logged in.');
        return;
      }

      // NOTE: Face verification will be inserted here in Section 5,
      // before marking attendance. GPS check deferred to final stretch.

      final deviceId = await _deviceService.getDeviceId();

      final record = AttendanceRecord(
        sessionId: session.sessionId,
        studentId: currentUser.uid,
        studentName: currentUser.name,
        rollNumber: currentUser.rollNumber,
        markedAt: DateTime.now(),
        deviceId: deviceId,
      );

      await _attendanceService.markAttendance(record);

      setState(() {
        _success = true;
        _statusMessage = 'Attendance marked for ${session.subject}!';
      });
    } catch (e) {
      setState(() => _statusMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Attendance QR')),
      body: _statusMessage == null
          ? MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final code = barcodes.first.rawValue;
                  if (code != null) {
                    _handleScan(code);
                  }
                }
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error,
                      color: _success ? Colors.green : Colors.red,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _statusMessage = null;
                          _success = false;
                        });
                      },
                      child: const Text('Scan Again'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}