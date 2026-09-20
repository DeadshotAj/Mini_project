import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'session_attendance_screen.dart';

class PastSessionsScreen extends StatefulWidget {
  const PastSessionsScreen({super.key});

  @override
  State<PastSessionsScreen> createState() => _PastSessionsScreenState();
}

class _PastSessionsScreenState extends State<PastSessionsScreen> {
  final _sessionService = SessionService();
  final _authService = AuthService();

  List<AttendanceSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final teacherId = _authService.currentUser?.uid ?? '';
    final sessions = await _sessionService.getSessionsForTeacher(teacherId);
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Past Sessions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _SessionCard(session: _sessions[index]),
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
            child: const Icon(Icons.history_rounded,
                size: 36, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sessions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sessions you create will appear here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final expired = session.isExpired;
    final dateStr = _formatDate(session.createdAt);
    final timeStr = _formatTime(session.createdAt);

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionAttendanceScreen(session: session),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 22, color: AppTheme.accent),
              ),
              const SizedBox(width: 14),

              // Subject + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
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

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: expired ? AppTheme.surface : AppTheme.successLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: expired ? AppTheme.divider : AppTheme.success,
                  ),
                ),
                child: Text(
                  expired ? 'Ended' : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: expired ? AppTheme.textSecondary : AppTheme.success,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.textSecondary),
            ],
          ),
        ),
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
