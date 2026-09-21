import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/attendance.dart';
import '../services/attendance_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import 'dart:io';

class SessionAttendanceScreen extends StatefulWidget {
  final AttendanceSession session;

  const SessionAttendanceScreen({super.key, required this.session});

  @override
  State<SessionAttendanceScreen> createState() => _SessionAttendanceScreenState();
}

class _SessionAttendanceScreenState extends State<SessionAttendanceScreen> {
  final _attendanceService = AttendanceService();
  final _exportService = ExportService();

  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records =
        await _attendanceService.getAttendanceForSession(widget.session.sessionId);
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final filePath = await _exportService.exportAttendanceToExcel(
        subject: widget.session.subject,
        records: _records,
      );

      if (!mounted) return;

      await _exportService.shareFile(filePath, widget.session.subject);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          content: Text(
            Platform.isWindows ? 'Saved to: $filePath' : 'Excel file exported successfully!',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          content: Text('Export failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.session.subject),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary header
                Container(
                  color: AppTheme.card,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Count chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 18, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            Text(
                              '${_records.length} present',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Export button
                      _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Export'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                backgroundColor: AppTheme.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _records.isEmpty ? null : _exportToExcel,
                            ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // List
                Expanded(
                  child: _records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  border: Border.all(color: AppTheme.divider),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.people_outline_rounded,
                                    size: 34, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No attendance yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Students will appear here as they scan the QR.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _records.length,
                          separatorBuilder: (_, _) =>
                              const Divider(indent: 76, endIndent: 20, height: 1),
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            final timeStr = _formatTime(record.markedAt);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    (record.studentName.isNotEmpty)
                                        ? record.studentName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryLight,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                record.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${record.rollNumber ?? "No roll number"} · $timeStr',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: record.faceVerified
                                      ? AppTheme.successLight
                                      : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: record.faceVerified
                                        ? AppTheme.success
                                        : AppTheme.divider,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      record.faceVerified
                                          ? Icons.verified_rounded
                                          : Icons.help_outline_rounded,
                                      size: 14,
                                      color: record.faceVerified
                                          ? AppTheme.success
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      record.faceVerified ? 'Verified' : 'Unverified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: record.faceVerified
                                            ? AppTheme.success
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}