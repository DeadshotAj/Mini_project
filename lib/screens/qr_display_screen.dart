import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/session.dart';
import '../services/ble_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
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

  final _bleService = BleService();
  final _sessionService = SessionService();

  // 'idle' | 'broadcasting' | 'bt_off' | 'permission_denied' | 'unavailable'
  String _bleStatus = 'idle';

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
    _initBle();
  }

  Future<void> _initBle() async {
    setState(() => _bleStatus = 'idle');

    if (!_bleService.canAdvertise) {
      setState(() => _bleStatus = 'unavailable');
      return;
    }

    // Request permissions (Android needs runtime grants)
    if (Platform.isAndroid) {
      final granted = await _bleService.requestPermissions();
      if (!mounted) return;
      if (!granted) {
        setState(() => _bleStatus = 'permission_denied');
        return;
      }
    }

    bool btOn = await _bleService.isBluetoothOn();
    if (!btOn) {
      btOn = await _bleService.ensureBluetoothOn();
    }
    if (!mounted) return;
    if (!btOn) {
      setState(() => _bleStatus = 'bt_off');
      return;
    }

    final started =
        await _bleService.startAdvertising(widget.session.sessionId);
    if (!mounted) return;

    if (started) {
      setState(() => _bleStatus = 'broadcasting');
      // Persist the flag so students know to run the proximity check
      await _sessionService.updateBleEnabled(widget.session.sessionId,
          enabled: true);
    } else {
      setState(() => _bleStatus = 'unavailable');
    }
  }

  Future<void> _retryBle() async {
    await _bleService.stopAdvertising();
    await _initBle();
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
    _bleService.stopAdvertising();
    super.dispose();
  }


  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _progress {
    final total = widget.session.expiresAt.difference(widget.session.createdAt).inSeconds;
    if (total <= 0) return 0.0;
    return (_timeLeft.inSeconds / total).clamp(0.0, 1.0);
  }

  Color get _timerColor {
    if (_progress > 0.5) return AppTheme.success;
    if (_progress > 0.25) return Colors.orange;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _timeLeft == Duration.zero;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(widget.session.subject)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // QR or Expired state
              Expanded(
                child: Center(
                  child: isExpired ? _buildExpiredState() : _buildQrState(),
                ),
              ),

              // View Attendance button
              ElevatedButton.icon(
                icon: const Icon(Icons.people_alt_rounded),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.successLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text(
                'Active',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // QR card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: QrImageView(
            data: widget.session.sessionId,
            version: QrVersions.auto,
            size: 240,
          ),
        ),
        const SizedBox(height: 24),

        // Countdown + progress
        Text(
          _formatDuration(_timeLeft),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: _timerColor,
            letterSpacing: 2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Time remaining',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: AppTheme.divider,
            valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
          ),
        ),
        const SizedBox(height: 14),
        _buildBleChip(),
      ],
    );
  }

  Widget _buildBleChip() {
    switch (_bleStatus) {
      case 'broadcasting':
        return _bleChipRow(
          icon: Icons.bluetooth_searching_rounded,
          label: 'BLE: Broadcasting classroom beacon',
          color: AppTheme.success,
          bg: AppTheme.successLight,
        );

      case 'bt_off':
        return _bleChipRow(
          icon: Icons.bluetooth_disabled_rounded,
          label: 'Bluetooth is off — proximity disabled',
          color: AppTheme.error,
          bg: AppTheme.errorLight,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Platform.isWindows)
                TextButton(
                  onPressed: () => _bleService.ensureBluetoothOn(),
                  child: const Text('Open Settings',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w700)),
                ),
              TextButton(
                onPressed: _retryBle,
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );


      case 'permission_denied':
        return _bleChipRow(
          icon: Icons.bluetooth_disabled_rounded,
          label: 'BLE permissions not granted',
          color: AppTheme.error,
          bg: AppTheme.errorLight,
          action: TextButton(
            onPressed: _retryBle,
            child: Text('Grant',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700)),
          ),
        );

      case 'unavailable':
        return _bleChipRow(
          icon: Icons.bluetooth_disabled_rounded,
          label: 'BLE not available — proximity disabled',
          color: AppTheme.textSecondary,
          bg: AppTheme.surface,
        );

      default: // 'idle'
        return _bleChipRow(
          icon: Icons.bluetooth_searching_rounded,
          label: 'Starting BLE…',
          color: AppTheme.textSecondary,
          bg: AppTheme.surface,
        );
    }
  }

  Widget _bleChipRow({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    Widget? action,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 5, action != null ? 4 : 10, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 2),
            action,
          ],
        ],
      ),
    );
  }


  Widget _buildExpiredState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.errorLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.timer_off_rounded, color: AppTheme.error, size: 40),
        ),
        const SizedBox(height: 20),
        const Text(
          'QR Code Expired',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This session is closed. View the attendance\nlist below.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}