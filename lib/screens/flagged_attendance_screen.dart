import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../models/session.dart';
import '../services/attendance_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class FlaggedAttendanceScreen extends StatefulWidget {
  const FlaggedAttendanceScreen({super.key});

  @override
  State<FlaggedAttendanceScreen> createState() => _FlaggedAttendanceScreenState();
}

class _FlaggedAttendanceScreenState extends State<FlaggedAttendanceScreen> {
  final _attendanceService = AttendanceService();
  final _sessionService = SessionService();

  List<({AttendanceRecord record, AttendanceSession? session})> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlagged();
  }

  Future<void> _loadFlagged() async {
    setState(() => _isLoading = true);

    final records = await _attendanceService.getFlaggedAttendance();

    final sessionIds = records.map((r) => r.sessionId).toSet().toList();
    final sessionsMap = await _sessionService.getSessionsMapByIds(sessionIds);

    if (!mounted) return;
    setState(() {
      _entries = records
          .map((r) => (record: r, session: sessionsMap[r.sessionId]))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _approve(AttendanceRecord record) async {
    try {
      await _attendanceService.overrideAttendance(
          record.sessionId, record.studentId);
      if (!mounted) return;
      _showSnackbar(
          '${record.studentName}\'s attendance approved.', AppTheme.success);
      _loadFlagged();
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Error: $e', AppTheme.error);
    }
  }

  Future<void> _reject(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Attendance',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'This will permanently remove the attendance record for ${record.studentName}. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _attendanceService.rejectAttendance(
          record.sessionId, record.studentId);
      if (!mounted) return;
      _showSnackbar(
          '${record.studentName}\'s record rejected.', AppTheme.error);
      _loadFlagged();
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Error: $e', AppTheme.error);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Flagged Verifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadFlagged,
                  child: Column(
                    children: [
                      // Info banner
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF8E1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: Color(0xFFF9A825)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_entries.length} record${_entries.length == 1 ? '' : 's'} pending review. '
                                'Approve genuine students or reject false entries.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF795548),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return _FlaggedCard(
                              record: e.record,
                              session: e.session,
                              onApprove: () => _approve(e.record),
                              onReject: () => _reject(e.record),
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
              color: AppTheme.successLight,
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 36, color: AppTheme.success),
          ),
          const SizedBox(height: 16),
          const Text(
            'No flagged records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All face verifications are passing.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flagged record card
// ---------------------------------------------------------------------------
class _FlaggedCard extends StatelessWidget {
  final AttendanceRecord record;
  final AttendanceSession? session;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _FlaggedCard({
    required this.record,
    required this.session,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final subject = session?.subject ?? 'Unknown Subject';
    final dateStr = _formatDate(record.markedAt);
    final timeStr = _formatTime(record.markedAt);

    final initials = record.studentName.isNotEmpty
        ? record.studentName
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: const Color(0xFFF9A825).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name/roll + warning badge
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.errorLight,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.studentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (record.rollNumber != null)
                      Text(
                        record.rollNumber!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.face_retouching_off_rounded,
                        size: 12, color: AppTheme.error),
                    SizedBox(width: 4),
                    Text(
                      'Face Failed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Session details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.book_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$dateStr · $timeStr',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_rounded,
                      size: 16, color: AppTheme.error),
                  label: const Text('Reject',
                      style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: onApprove,
                ),
              ),
            ],
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
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
