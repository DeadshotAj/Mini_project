import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class PendingTeachersScreen extends StatefulWidget {
  const PendingTeachersScreen({super.key});

  @override
  State<PendingTeachersScreen> createState() => _PendingTeachersScreenState();
}

class _PendingTeachersScreenState extends State<PendingTeachersScreen> {
  final _authService = AuthService();
  List<AppUser> _pending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    final pending = await _authService.getPendingTeachers();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _isLoading = false;
    });
  }

  Future<void> _approve(AppUser teacher) async {
    await _authService.approveTeacher(teacher.uid);
    _loadPending();
    if (mounted) {
      _showSnackbar('${teacher.name} approved!', isError: false);
    }
  }

  Future<void> _reject(AppUser teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Teacher',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to reject "${teacher.name}"? They will see a rejection message when they try to log in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.rejectTeacher(teacher.uid);
      _loadPending();
      if (mounted) {
        _showSnackbar('${teacher.name} rejected.', isError: true);
      }
    }
  }

  void _showSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) => _PendingTile(
                      teacher: _pending[i],
                      onApprove: () => _approve(_pending[i]),
                      onReject: () => _reject(_pending[i]),
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
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 36, color: AppTheme.success),
          ),
          const SizedBox(height: 16),
          const Text('All caught up!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('No teachers waiting for approval.',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final AppUser teacher;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTile({
    required this.teacher,
    required this.onApprove,
    required this.onReject,
  });

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE3F0FC),
                child: Text(
                  initials,
                  style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teacher.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Pending badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF795548)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
