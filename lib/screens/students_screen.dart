import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _authService = AuthService();

  List<AppUser> _allStudents = [];
  List<AppUser> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final students = await _authService.getAllStudents();
    setState(() {
      _allStudents = students;
      _filtered = students;
      _isLoading = false;
    });
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allStudents
          : _allStudents
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  (s.rollNumber?.toLowerCase().contains(q) ?? false))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final faceCount = _allStudents.where((s) => s.faceEmbedding != null).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Students')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary + search bar
                Container(
                  color: AppTheme.card,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Stats row
                      Row(
                        children: [
                          _SummaryChip(
                            icon: Icons.people_alt_rounded,
                            label: '${_allStudents.length} registered',
                            color: AppTheme.accent,
                            bg: AppTheme.accentLight,
                          ),
                          const SizedBox(width: 8),
                          _SummaryChip(
                            icon: Icons.face_rounded,
                            label: '$faceCount face set up',
                            color: AppTheme.success,
                            bg: AppTheme.successLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or roll number…',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: AppTheme.textSecondary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // List
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadStudents,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(indent: 76, endIndent: 16, height: 1),
                            itemBuilder: (context, index) =>
                                _StudentTile(student: _filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    final isSearching = _searchController.text.isNotEmpty;
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
            child: Icon(
              isSearching ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 36,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No students match your search' : 'No students yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'Try a different name or roll number'
                : 'Students will appear here once they sign up.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final AppUser student;

  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final initials = student.name.isNotEmpty
        ? student.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    final hasFace = student.faceEmbedding != null;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            initials.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      title: Text(
        student.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        student.rollNumber != null
            ? 'Roll No. ${student.rollNumber}'
            : 'No roll number',
        style:
            const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasFace ? AppTheme.successLight : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFace ? AppTheme.success : Colors.orange,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFace ? Icons.face_rounded : Icons.face_retouching_off_rounded,
              size: 13,
              color: hasFace ? AppTheme.success : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              hasFace ? 'Face set' : 'No face',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasFace ? AppTheme.success : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
