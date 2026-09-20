import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../models/session.dart';
import '../services/attendance_service.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  const StudentAttendanceHistoryScreen({super.key});

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  final _attendanceService = AttendanceService();
  final _sessionService = SessionService();
  final _authService = AuthService();

  // Each entry pairs an attendance record with its session details
  List<({AttendanceRecord record, AttendanceSession? session})> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final studentId = _authService.currentUser?.uid ?? '';

    // Fetch all attendance records for this student
    final records =
        await _attendanceService.getAttendanceForStudent(studentId);

    // Sort newest first
    records.sort((a, b) => b.markedAt.compareTo(a.markedAt));

    // Batch-fetch the corresponding sessions to get subject names
    final sessionIds = records.map((r) => r.sessionId).toList();
    final sessionsMap =
        await _sessionService.getSessionsMapByIds(sessionIds);

    setState(() {
      _entries = records
          .map((r) => (record: r, session: sessionsMap[r.sessionId]))
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('My Attendance')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: Column(
                    children: [
                      // Summary banner
                      Container(
                        color: AppTheme.card,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppTheme.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_entries.length} ${_entries.length == 1 ? 'class' : 'classes'} attended',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          itemCount: _entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return _HistoryCard(
                              record: e.record,
                              session: e.session,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 36, color: AppTheme.textSecondary),
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
            'Classes you attend will show up here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AttendanceRecord record;
  final AttendanceSession? session;

  const _HistoryCard({required this.record, required this.session});

  @override
  Widget build(BuildContext context) {
    final subject = session?.subject ?? 'Unknown Subject';
    final dateStr = _formatDate(record.markedAt);
    final timeStr = _formatTime(record.markedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 22, color: AppTheme.success),
          ),
          const SizedBox(width: 14),

          // Subject + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateStr · $timeStr',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Face verified badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  size: 13,
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
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
