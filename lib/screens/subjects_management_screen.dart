import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/subject_service.dart';
import '../theme/app_theme.dart';
import 'subject_detail_screen.dart';

class SubjectsManagementScreen extends StatefulWidget {
  const SubjectsManagementScreen({super.key});

  @override
  State<SubjectsManagementScreen> createState() =>
      _SubjectsManagementScreenState();
}

class _SubjectsManagementScreenState extends State<SubjectsManagementScreen> {
  final _subjectService = SubjectService();
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    final subjects = await _subjectService.getAllSubjects();
    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _isLoading = false;
    });
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    bool isCreating = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'New Subject',
            style:
                TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g. Data Structures',
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
                  hintText: 'e.g. CS301',
                  prefixIcon: Icon(Icons.tag_rounded,
                      size: 20, color: AppTheme.textSecondary),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style: const TextStyle(
                        color: AppTheme.error, fontSize: 13)),
              ],
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
                minimumSize: const Size(90, 44),
              ),
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final code = codeController.text.trim();
                      if (name.isEmpty || code.isEmpty) {
                        setDialogState(() =>
                            error = 'Both name and code are required.');
                        return;
                      }
                      setDialogState(() {
                        isCreating = true;
                        error = null;
                      });
                        try {
                        await _subjectService.createSubject(
                            name: name, code: code);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadSubjects();
                        _showSnackbar('Subject "$name" created!',
                            isError: false);
                      } catch (e) {
                        setDialogState(() {
                          isCreating = false;
                          error = 'Failed to create subject.';
                        });
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Subject',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete "${subject.name} (${subject.code})"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _subjectService.deleteSubject(subject.subjectId);
      _loadSubjects();
      if (mounted) {
        _showSnackbar('"${subject.name}" deleted.', isError: false);
      }
    }
  }

  void _showSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : const Color(0xFF6A1B9A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Manage Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF6A1B9A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Subject',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSubjects,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _subjects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SubjectTile(
                      subject: _subjects[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubjectDetailScreen(
                              subject: _subjects[i]),
                        ),
                      ).then((_) => _loadSubjects()),
                      onDelete: () => _confirmDelete(_subjects[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.book_outlined,
                size: 36, color: Color(0xFF7B1FA2)),
          ),
          const SizedBox(height: 16),
          const Text('No subjects yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('Tap "New Subject" to create one.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SubjectTile({
    required this.subject,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_rounded,
                    color: Color(0xFF7B1FA2), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subject.code,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6A1B9A)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${subject.teacherIds.length} teacher${subject.teacherIds.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
