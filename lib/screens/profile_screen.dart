import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  AppUser? _user;
  bool _isLoading = true;
  bool _isSendingReset = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentAppUser();
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  Future<void> _sendPasswordReset() async {
    final email = _user?.email;
    if (email == null) return;

    setState(() => _isSendingReset = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showSnackbar(
        'Password reset email sent to $email',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Failed to send reset email. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
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

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Could not load profile.'))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar + name + role
                        _buildIdentityCard(),
                        const SizedBox(height: 24),

                        // Password section
                        _buildSection(
                          label: 'Security',
                          child: _buildPasswordTile(),
                        ),
                        const SizedBox(height: 16),

                        // Sign out section
                        _buildSection(
                          label: 'Account',
                          child: _buildSignOutTile(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildIdentityCard() {
    final initials = _user!.name.isNotEmpty
        ? _user!.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    final isTeacher = _user!.role == 'teacher';
    final isAdmin = _user!.role == 'admin';

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    if (isAdmin) {
      badgeBg = const Color(0xFFFFF8E1);
      badgeBorder = const Color(0xFFFFC107);
      badgeText = const Color(0xFF795548);
      badgeIcon = Icons.admin_panel_settings_rounded;
      badgeLabel = 'Admin';
    } else if (isTeacher) {
      badgeBg = AppTheme.accentLight;
      badgeBorder = AppTheme.accent;
      badgeText = AppTheme.primaryLight;
      badgeIcon = Icons.school_rounded;
      badgeLabel = 'Teacher';
    } else {
      badgeBg = AppTheme.successLight;
      badgeBorder = AppTheme.success;
      badgeText = AppTheme.success;
      badgeIcon = Icons.person_rounded;
      badgeLabel = 'Student';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            _user!.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            _user!.email,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: badgeBorder),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeText,
                  ),
                ),
              ],
            ),
          ),

          // Roll number (students only)
          if (_user!.role == 'student' && _user!.rollNumber != null) ...[
            const SizedBox(height: 10),
            Text(
              'Roll No. ${_user!.rollNumber}',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildPasswordTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.lock_reset_rounded,
            size: 20, color: AppTheme.accent),
      ),
      title: const Text(
        'Change Password',
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary),
      ),
      subtitle: const Text(
        'A reset link will be sent to your email',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: _isSendingReset
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.textSecondary),
      onTap: _isSendingReset ? null : _sendPasswordReset,
    );
  }

  Widget _buildSignOutTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.errorLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.logout_rounded,
            size: 20, color: AppTheme.error),
      ),
      title: const Text(
        'Sign Out',
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.error),
      ),
      onTap: _signOut,
    );
  }
}
