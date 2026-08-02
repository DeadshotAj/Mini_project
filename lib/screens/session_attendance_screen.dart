import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/attendance.dart';
import '../services/attendance_service.dart';
import '../services/export_service.dart';
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
    final records = await _attendanceService.getAttendanceForSession(widget.session.sessionId);
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
          content: Text(
            Platform.isWindows
                ? 'Saved to: $filePath'
                : 'Excel file exported successfully!',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.subject} — Attendance'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_records.length} student(s) marked present',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.file_download),
                              label: const Text('Export to Excel'),
                              onPressed: _records.isEmpty ? null : _exportToExcel,
                            ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _records.isEmpty
                      ? const Center(child: Text('No attendance marked yet.'))
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text('${record.rollNumber ?? "N/A"} — ${record.studentName}'),
                              subtitle: Text('Marked at: ${record.markedAt}'),
                              trailing: Icon(
                                record.faceVerified ? Icons.verified_user : Icons.help_outline,
                                color: record.faceVerified ? Colors.green : Colors.grey,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}