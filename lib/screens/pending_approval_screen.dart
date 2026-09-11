import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'teacher_home_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  final AppUser user;
  const PendingApprovalScreen({super.key, required this.user});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final _authService = AuthService();
  bool _isChecking = false;

  bool get _isRejected => widget.user.status == 'rejected';

  // Lets the teacher manually re-check their status without re-logging in
  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    final updated = await _authService.getCurrentAppUser();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (updated == null) return;
    if (updated.status == 'approved') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated.status == 'rejected'
            ? 'Your account has been rejected. Contact the admin.'
            : 'Still waiting for approval. Try again later.'),
        backgroundColor:
            updated.status == 'rejected' ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _isRejected
                      ? AppTheme.errorLight
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  _isRejected
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
                  size: 52,
                  color: _isRejected
                      ? AppTheme.error
                      : const Color(0xFFFFC107),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                _isRejected ? 'Account Rejected' : 'Awaiting Approval',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                _isRejected
                    ? 'Your teacher account has been rejected by the admin. Please contact your institution administrator for more information.'
                    : 'Your teacher account is pending admin approval. You will be able to access the app once an admin approves your account.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // User info chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  border: Border.all(color: AppTheme.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      widget.user.email,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Check status button (only for pending)
              if (!_isRejected)
                _isChecking
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check Status'),
                        onPressed: _checkStatus,
                      ),

              if (!_isRejected) const SizedBox(height: 14),

              // Sign out
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
