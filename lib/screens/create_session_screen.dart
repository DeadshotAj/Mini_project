import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../services/subject_service.dart';
import '../theme/app_theme.dart';
import 'qr_display_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _subjectController = TextEditingController();
  final _sessionService = SessionService();
  final _authService = AuthService();
  final _subjectService = SubjectService();

  int _durationMinutes = 10;
  bool _isLoading = false;
  bool _isLoadingSubjects = true;

  List<Subject> _assignedSubjects = [];
  Subject? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
  }

  Future<void> _loadAssignedSubjects() async {
    final teacherId = _authService.currentUser?.uid ?? '';
    if (teacherId.isEmpty) {
      setState(() => _isLoadingSubjects = false);
      return;
    }
    final subjects = await _subjectService.getSubjectsForTeacher(teacherId);
    if (!mounted) return;
    setState(() {
      _assignedSubjects = subjects;
      _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      _isLoadingSubjects = false;
    });
  }

  Future<void> _createSession() async {
    // Determine subject name: from dropdown or free-text fallback
    final subjectName = _assignedSubjects.isNotEmpty
        ? (_selectedSubject?.name ?? '')
        : _subjectController.text.trim();

    if (subjectName.isEmpty) return;

    setState(() => _isLoading = true);

    final teacherId = _authService.currentUser?.uid ?? '';

    // Prevent creating duplicate session for same subject before previous class ends
    final activeSession = await _sessionService.getActiveSessionForSubject(
      teacherId: teacherId,
      subject: subjectName,
    );

    if (activeSession != null) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final remaining = activeSession.expiresAt.difference(DateTime.now());
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds.remainder(60);
      final timeStr = mins > 0 ? '$mins min $secs sec' : '$secs sec';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.error),
              SizedBox(width: 10),
              Text('Session Active', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            'An active session for "$subjectName" is currently running ($timeStr remaining).\n\nYou cannot start a new class for this subject until the previous session ends.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              icon: const Icon(Icons.qr_code_rounded, size: 18),
              label: const Text('View Active QR'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrDisplayScreen(session: activeSession),
                  ),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    final session = await _sessionService.createSession(
      teacherId: teacherId,
      subject: subjectName,
      durationMinutes: _durationMinutes,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QrDisplayScreen(session: session)),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('New Session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Session Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a subject and set the QR validity window.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),

              // Subject selector
              if (_isLoadingSubjects)
                const Center(child: CircularProgressIndicator())
              else if (_assignedSubjects.isNotEmpty)
                _buildSubjectDropdown()
              else
                _buildFreeTextField(),

              const SizedBox(height: 24),

              // Duration picker card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  border: Border.all(color: AppTheme.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 20, color: AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'QR valid for',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                    DropdownButton<int>(
                      value: _durationMinutes,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      items: const [5, 10, 15, 20]
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('$m minutes'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _durationMinutes = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppTheme.accent, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Students have until the QR expires to scan and mark their attendance.',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Generate button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Generate QR Code'),
                      onPressed: _createSession,
                    ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.book_outlined,
              size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<Subject>(
              value: _selectedSubject,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              hint: const Text('Select subject',
                  style: TextStyle(color: AppTheme.textSecondary)),
              items: _assignedSubjects
                  .map((s) => DropdownMenuItem<Subject>(
                        value: s,
                        child: Text('${s.name} (${s.code})'),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSubject = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(
            labelText: 'Subject / Class Name',
            hintText: 'e.g. Data Structures — Period 3',
            prefixIcon: Icon(Icons.book_outlined,
                size: 20, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFFFFC107), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No subjects assigned yet. Ask your admin to assign subjects to you.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF795548)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
