import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/session_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import '../services/ble_service.dart';
import '../models/attendance.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'face_capture_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _sessionService = SessionService();
  final _attendanceService = AttendanceService();
  final _authService = AuthService();
  final _faceService = FaceService();
  final _bleService = BleService();

  bool _isProcessing = false;
  String? _statusMessage;
  bool _success = false;

  Future<void> _handleScan(String sessionId) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Checking session…';
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

      if (currentUser.faceEmbedding == null) {
        setState(() => _statusMessage = 'No registered face found. Please contact admin.');
        return;
      }

      setState(() => _statusMessage = 'Verifying your face…');
      if (!mounted) return;

      final liveEmbedding = await Navigator.push<List<double>>(
        context,
        MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
      );

      if (liveEmbedding == null) {
        setState(() => _statusMessage = 'Face verification cancelled.');
        return;
      }

      await _faceService.loadModel();
      final similarity = _faceService.cosineSimilarity(
        currentUser.faceEmbedding!,
        liveEmbedding,
      );

      const threshold = 0.55;
      if (similarity < threshold) {
        // Save a pending record so the teacher can manually override if needed
        try {
          final pendingRecord = AttendanceRecord(
            sessionId: session.sessionId,
            studentId: currentUser.uid,
            studentName: currentUser.name,
            rollNumber: currentUser.rollNumber,
            markedAt: DateTime.now(),
            faceVerified: false,
            verificationStatus: 'failed',
          );
          await _attendanceService.markAttendancePending(pendingRecord);
        } catch (_) {
          // Silently ignore if already pending (duplicate session/student)
        }
        setState(() => _statusMessage =
            'Face verification failed.\nYour attendance has been flagged for teacher review.');
        return;
      }

      // ── BLE Proximity check ────────────────────────────────────────────
      // Only runs when the teacher's beacon is active (bleEnabled == true).
      // Uses flutter_blue_plus scanning — supported on ALL Android devices.
      if (session.bleEnabled) {
        setState(() => _statusMessage = 'Checking proximity…');

        bool btOn = await _bleService.isBluetoothOn();
        if (!btOn) {
          btOn = await _bleService.ensureBluetoothOn();
        }
        if (!btOn) {
          setState(() => _statusMessage =
              'Bluetooth is required to mark attendance.\nPlease enable Bluetooth and try again.');
          return;
        }

        setState(
            () => _statusMessage = '📡 Scanning for classroom beacon…');
        final inRange =
            await _bleService.checkProximity(session.sessionId);

        if (!mounted) return;
        if (!inRange) {
          setState(() => _statusMessage =
              'You must be in the classroom to mark attendance.\n(Beacon not detected or out of range)');
          return;
        }
      }

      final record = AttendanceRecord(
        sessionId: session.sessionId,
        studentId: currentUser.uid,
        studentName: currentUser.name,
        rollNumber: currentUser.rollNumber,
        markedAt: DateTime.now(),
        faceVerified: true,
      );

      await _attendanceService.markAttendance(record);

      setState(() {
        _success = true;
        _statusMessage = 'Attendance marked for\n${session.subject}!';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: _statusMessage == null ? _buildScanner() : _buildResult(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        // Camera view
        MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final code = barcodes.first.rawValue;
              if (code != null) _handleScan(code);
            }
          },
        ),

        // Overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Bottom hint
        Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Column(
            children: [
              if (_isProcessing)
                const CircularProgressIndicator(color: Colors.white)
              else
                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white54, size: 32),
              const SizedBox(height: 12),
              Text(
                _isProcessing ? 'Processing…' : 'Align the QR code within the frame',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status icon
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _success ? AppTheme.successLight : AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    _success ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _success ? AppTheme.success : AppTheme.error,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _success ? 'Attendance Marked!' : 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 36),

              if (!_success)
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Try Again'),
                  onPressed: () {
                    setState(() {
                      _statusMessage = null;
                      _success = false;
                    });
                  },
                ),

              if (_success)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Home'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}