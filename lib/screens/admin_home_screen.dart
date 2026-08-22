import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/subject_service.dart';
import '../theme/app_theme.dart';
import 'pending_teachers_screen.dart';
import 'subjects_management_screen.dart';
import 'students_screen.dart';
import 'profile_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _authService = AuthService();
  final _subjectService = SubjectService();

  String? _firstName;
  int? _subjectCount;
  int? _teacherCount;
  int? _studentCount;
  int? _pendingCount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentAppUser();
    if (user == null || !mounted) return;

    final subjects = await _subjectService.getAllSubjects();
    final teachers = await _authService.getAllTeachers();
    final students = await _authService.getAllStudents();
    final pending = await _authService.getPendingTeachers();

    if (!mounted) return;
    setState(() {
      _firstName = user.name.trim().split(' ').first;
      _subjectCount = subjects.length;
      _teacherCount = teachers.length;
      _studentCount = students.length;
      _pendingCount = pending.length;
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
            ).then((_) => _loadData()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
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
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${_firstName ?? 'Admin'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Manage subjects, teachers & students',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 10),
                            // Stats row
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _StatChip(
                                  icon: Icons.book_rounded,
                                  label:
                                      '${_subjectCount ?? '-'} subjects',
                                ),
                                _StatChip(
                                  icon: Icons.person_rounded,
                                  label:
                                      '${_teacherCount ?? '-'} teachers',
                                ),
                                _StatChip(
                                  icon: Icons.school_rounded,
                                  label:
                                      '${_studentCount ?? '-'} students',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'ADMIN ACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),

                _ActionCard(
                  icon: Icons.pending_actions_rounded,
                  title: 'Pending Approvals',
                  subtitle: 'Review and approve teacher accounts',
                  iconColor: const Color(0xFFE65100),
                  iconBg: const Color(0xFFFFF3E0),
                  badgeCount: _pendingCount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PendingTeachersScreen()),
                  ).then((_) => _loadData()),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.book_rounded,
                  title: 'Manage Subjects',
                  subtitle: 'Create subjects and assign teachers',
                  iconColor: const Color(0xFF7B1FA2),
                  iconBg: const Color(0xFFF3E5F5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubjectsManagementScreen()),
                  ).then((_) => _loadData()),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.people_rounded,
                  title: 'View All Students',
                  subtitle: 'See registered students and face setup status',
                  iconColor: const Color(0xFF1565C0),
                  iconBg: const Color(0xFFE3F2FD),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentsScreen()),
                  ),
                ),
              ],
            ),
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
              fontSize: 11,
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
  final int? badgeCount;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
    this.badgeCount,
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
            border: Border.all(
              color: (badgeCount != null && badgeCount! > 0)
                  ? const Color(0xFFFFCC80)
                  : AppTheme.divider,
              width: (badgeCount != null && badgeCount! > 0) ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
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


