import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../models/session.dart';
import '../services/attendance_service.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _SubjectStat {
  final String subject;
  final int attended;
  final int total;

  const _SubjectStat({
    required this.subject,
    required this.attended,
    required this.total,
  });

  int get missed => total - attended;
  double get percentage => total == 0 ? 0 : attended / total;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _attendanceService = AttendanceService();
  final _sessionService = SessionService();
  final _authService = AuthService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<_SubjectStat> _stats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final uid = _authService.currentUser?.uid ?? '';
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    // 1) All sessions held this month
    final List<AttendanceSession> allSessions =
        await _sessionService.getSessionsForMonth(_selectedMonth);

    // 2) All attendance records for this student
    final List<AttendanceRecord> allRecords =
        await _attendanceService.getAttendanceForStudent(uid);

    // 3) Filter records to the selected month
    final Set<String> attendedSessionIds = allRecords
        .where((r) =>
            r.markedAt.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            r.markedAt.isBefore(monthEnd))
        .map((r) => r.sessionId)
        .toSet();

    // 4) Group sessions by subject -> total count
    final Map<String, int> totalPerSubject = {};
    for (final s in allSessions) {
      totalPerSubject[s.subject] = (totalPerSubject[s.subject] ?? 0) + 1;
    }

    // 5) Count attended per subject
    final Map<String, int> attendedPerSubject = {};
    for (final s in allSessions) {
      if (attendedSessionIds.contains(s.sessionId)) {
        attendedPerSubject[s.subject] =
            (attendedPerSubject[s.subject] ?? 0) + 1;
      }
    }

    // 6) Build stats list, sorted by subject name
    final stats = totalPerSubject.keys.map((subject) {
      return _SubjectStat(
        subject: subject,
        attended: attendedPerSubject[subject] ?? 0,
        total: totalPerSubject[subject]!,
      );
    }).toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  // ── Month navigation ──────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _selectedMonth = next;
    });
    _loadData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _monthLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  int get _totalAttended => _stats.fold(0, (s, e) => s + e.attended);
  int get _totalHeld => _stats.fold(0, (s, e) => s + e.total);
  double get _overallPercentage =>
      _totalHeld == 0 ? 0 : _totalAttended / _totalHeld;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Monthly Dashboard')),
      body: Column(
        children: [
          // Month navigator
          _MonthNavigator(
            label: _monthLabel,
            onPrev: _prevMonth,
            onNext: _isCurrentMonth ? null : _nextMonth,
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stats.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Overall summary card
                            _OverallSummaryCard(
                              attended: _totalAttended,
                              total: _totalHeld,
                              percentage: _overallPercentage,
                            ),
                            const SizedBox(height: 24),

                            // Section label
                            const Text(
                              'BY SUBJECT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Per-subject cards
                            ..._stats.map((stat) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _SubjectAttendanceCard(stat: stat),
                                )),
                          ],
                        ),
                      ),
          ),
        ],
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
            child: const Icon(Icons.bar_chart_rounded,
                size: 36, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sessions this month',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'There were no classes held in this period.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month navigator bar
// ---------------------------------------------------------------------------
class _MonthNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppTheme.primary,
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: onNext != null ? AppTheme.primary : AppTheme.divider,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall summary card (gradient)
// ---------------------------------------------------------------------------
class _OverallSummaryCard extends StatelessWidget {
  final int attended;
  final int total;
  final double percentage;

  const _OverallSummaryCard({
    required this.attended,
    required this.total,
    required this.percentage,
  });

  Color get _barColor {
    if (percentage >= 0.75) return AppTheme.success;
    if (percentage >= 0.5) return const Color(0xFFF9A825);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (percentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Attendance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$attended / $total classes',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          const SizedBox(height: 10),

          // Status chip
          _AttendanceStatusChip(percentage: percentage),
        ],
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  final double percentage;
  const _AttendanceStatusChip({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (percentage >= 0.75) {
      label = 'Good Standing';
      color = AppTheme.success;
      icon = Icons.check_circle_rounded;
    } else if (percentage >= 0.5) {
      label = 'Needs Improvement';
      color = const Color(0xFFF9A825);
      icon = Icons.warning_rounded;
    } else {
      label = 'At Risk';
      color = AppTheme.error;
      icon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-subject card
// ---------------------------------------------------------------------------
class _SubjectAttendanceCard extends StatelessWidget {
  final _SubjectStat stat;

  const _SubjectAttendanceCard({required this.stat});

  Color get _barColor {
    if (stat.percentage >= 0.75) return AppTheme.success;
    if (stat.percentage >= 0.5) return const Color(0xFFF9A825);
    return AppTheme.error;
  }

  Color get _barBg {
    if (stat.percentage >= 0.75) return AppTheme.successLight;
    if (stat.percentage >= 0.5) return const Color(0xFFFFF8E1);
    return AppTheme.errorLight;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (stat.percentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: subject name + percentage badge
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.subject,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _barBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stat.percentage,
              minHeight: 7,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom row: attended / total  +  missed badge
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${stat.attended} attended',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${stat.total} total',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (stat.missed > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_rounded,
                          size: 12, color: AppTheme.error),
                      const SizedBox(width: 4),
                      Text(
                        '${stat.missed} missed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 12, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text(
                        'Perfect!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
