import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'create_session_screen.dart';
import 'past_sessions_screen.dart';
import 'profile_screen.dart';
import 'students_screen.dart';
import 'flagged_attendance_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final _authService = AuthService();
  final _sessionService = SessionService();
  final _attendanceService = AttendanceService();

  String? _firstName;
  int? _monthSessionCount;
  int _flaggedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentAppUser();
    if (user == null || !mounted) return;

    final sessions = await _sessionService.getSessionsForTeacher(user.uid);
    final now = DateTime.now();
    final monthCount = sessions
        .where((s) =>
            s.createdAt.year == now.year && s.createdAt.month == now.month)
        .length;

    final flagged = await _attendanceService.getFlaggedAttendance();

    if (!mounted) return;
    setState(() {
      _firstName = user.name.trim().split(' ').first;
      _monthSessionCount = monthCount;
      _flaggedCount = flagged.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Smart Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${_firstName ?? 'Teacher'}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Create a session to start attendance',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          if (_monthSessionCount != null) ...[
                            const SizedBox(height: 10),
                            _StatChip(
                              icon: Icons.calendar_today_rounded,
                              label:
                                  '$_monthSessionCount ${_monthSessionCount == 1 ? 'session' : 'sessions'} this month',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 14),

              _ActionCard(
                icon: Icons.qr_code_2_rounded,
                title: 'Create Attendance Session',
                subtitle: 'Generate a timed QR code for your class',
                iconColor: AppTheme.accent,
                iconBg: AppTheme.accentLight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateSessionScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.history_rounded,
                title: 'Past Sessions',
                subtitle: 'View attendance records from previous classes',
                iconColor: AppTheme.primaryLight,
                iconBg: const Color(0xFFE8EEF5),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PastSessionsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.people_rounded,
                title: 'View Students',
                subtitle: 'See all registered students and face setup status',
                iconColor: const Color(0xFF7B5EA7),
                iconBg: const Color(0xFFF0EBF8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _FlaggedCard(
                flaggedCount: _flaggedCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FlaggedAttendanceScreen()),
                  );
                  // Refresh badge count when returning
                  _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flagged Verifications card — shows a badge with pending count
// ---------------------------------------------------------------------------
class _FlaggedCard extends StatelessWidget {
  final int flaggedCount;
  final VoidCallback onTap;

  const _FlaggedCard({required this.flaggedCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFlagged = flaggedCount > 0;

    return Material(
      color: hasFlagged ? AppTheme.errorLight : AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasFlagged
                  ? AppTheme.error.withValues(alpha: 0.4)
                  : AppTheme.divider,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: hasFlagged
                      ? AppTheme.error.withValues(alpha: 0.12)
                      : AppTheme.successLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  hasFlagged
                      ? Icons.face_retouching_off_rounded
                      : Icons.verified_user_rounded,
                  color: hasFlagged ? AppTheme.error : AppTheme.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flagged Verifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFlagged
                          ? 'Review face-failed attendance records'
                          : 'No pending records — all clear',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              // Badge or arrow
              if (hasFlagged)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$flaggedCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}