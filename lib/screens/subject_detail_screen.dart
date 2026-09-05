import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/subject.dart';
import '../services/auth_service.dart';
import '../services/subject_service.dart';
import '../theme/app_theme.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final _authService = AuthService();
  final _subjectService = SubjectService();

  Subject? _subject;
  List<AppUser> _allTeachers = [];
  List<AppUser> _assignedTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subject = widget.subject;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allTeachers = await _authService.getAllTeachers();
    final subjects = await _subjectService.getAllSubjects();
    final updatedSubject = subjects.firstWhere(
      (s) => s.subjectId == widget.subject.subjectId,
      orElse: () => widget.subject,
    );

    final assigned = allTeachers
        .where((t) => updatedSubject.teacherIds.contains(t.uid))
        .toList();

    if (!mounted) return;
    setState(() {
      _subject = updatedSubject;
      _allTeachers = allTeachers;
      _assignedTeachers = assigned;
      _isLoading = false;
    });
  }

  Future<void> _removeTeacher(AppUser teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Teacher',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content:
            Text('Remove ${teacher.name} from ${_subject!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _subjectService.removeTeacher(
          _subject!.subjectId, teacher.uid);
      _loadData();
      if (mounted) _showSnackbar('${teacher.name} removed.');
    }
  }

  void _showAssignBottomSheet() {
    final unassigned = _allTeachers
        .where((t) => !_subject!.teacherIds.contains(t.uid))
        .toList();

    if (unassigned.isEmpty) {
      _showSnackbar('All teachers are already assigned to this subject.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignTeacherSheet(
        teachers: unassigned,
        onAssign: (teacher) async {
          await _subjectService.assignTeacher(
              _subject!.subjectId, teacher.uid);
          _loadData();
          if (mounted) _showSnackbar('${teacher.name} assigned!');
        },
      ),
    );
  }

  void _showEditDialog() {
    final nameController =
        TextEditingController(text: _subject!.name);
    final codeController =
        TextEditingController(text: _subject!.code);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Subject',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  prefixIcon: Icon(Icons.book_outlined,
                      size: 20, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Subject Code',
                  prefixIcon: Icon(Icons.tag_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  minimumSize: const Size(80, 44)),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final code = codeController.text.trim();
                      if (name.isEmpty || code.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      await _subjectService.updateSubject(
                          _subject!.subjectId, name, code);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _loadData();
                      _showSnackbar('Subject updated!');
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF6A1B9A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(_subject?.name ?? 'Subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: _showEditDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Subject info card
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
                          child: const Icon(Icons.book_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _subject!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _subject!.code,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Teachers section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ASSIGNED TEACHERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAssignBottomSheet,
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 16),
                        label: const Text('Assign'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7B1FA2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_assignedTeachers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        border: Border.all(color: AppTheme.divider),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'No teachers assigned yet.\nTap "Assign" to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        border: Border.all(color: AppTheme.divider),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: _assignedTeachers
                            .asMap()
                            .entries
                            .map(
                              (entry) => Column(
                                children: [
                                  _TeacherTile(
                                    teacher: entry.value,
                                    onRemove: () =>
                                        _removeTeacher(entry.value),
                                  ),
                                  if (entry.key <
                                      _assignedTeachers.length - 1)
                                    const Divider(
                                        height: 1,
                                        indent: 16,
                                        endIndent: 16),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final AppUser teacher;
  final VoidCallback onRemove;

  const _TeacherTile({required this.teacher, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE7F6),
        child: Text(
          initials,
          style: const TextStyle(
              color: Color(0xFF6A1B9A),
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
      ),
      title: Text(
        teacher.name,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        teacher.email,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline_rounded,
            color: AppTheme.error, size: 20),
        tooltip: 'Remove',
        onPressed: onRemove,
      ),
    );
  }
}

class _AssignTeacherSheet extends StatelessWidget {
  final List<AppUser> teachers;
  final void Function(AppUser) onAssign;

  const _AssignTeacherSheet(
      {required this.teachers, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assign a Teacher',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: teachers.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final t = teachers[i];
                final initials = t.name.isNotEmpty
                    ? t.name
                        .trim()
                        .split(' ')
                        .map((w) => w[0])
                        .take(2)
                        .join()
                        .toUpperCase()
                    : '?';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEDE7F6),
                    child: Text(
                      initials,
                      style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  title: Text(t.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  subtitle: Text(t.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFF6A1B9A)),
                  onTap: () {
                    Navigator.pop(context);
                    onAssign(t);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
