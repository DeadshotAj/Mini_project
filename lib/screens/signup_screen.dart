import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'teacher_home_screen.dart';
import 'student_home_screen.dart';
import 'face_capture_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _authService = AuthService();

  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  List<double>? _capturedEmbedding;

  Future<void> _captureFace() async {
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
    );
    if (result != null) {
      setState(() => _capturedEmbedding = result);
    }
  }

  Future<void> _handleSignup() async {
    if (_selectedRole == 'student') {
      if (_rollNumberController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Roll number is required for students.');
        return;
      }
      if (_capturedEmbedding == null) {
        setState(() => _errorMessage = 'Please capture your face before signing up.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        rollNumber: _rollNumberController.text.trim(),
        faceEmbedding: _capturedEmbedding,
      );

      if (user == null || !mounted) return;

      if (user.role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Join Smart Attendance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fill in your details to get started',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),

              // Full Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Role selector
              const Text(
                'I am a',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'student',
                    label: Text('Student'),
                    icon: Icon(Icons.school_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: 'teacher',
                    label: Text('Teacher'),
                    icon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (newSelection) {
                  setState(() => _selectedRole = newSelection.first);
                },
              ),

              // Student-specific fields
              if (_selectedRole == 'student') ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _rollNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Roll Number',
                    hintText: 'e.g. 23CS045',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                // Face Capture Card
                GestureDetector(
                  onTap: _captureFace,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _capturedEmbedding != null ? AppTheme.successLight : AppTheme.card,
                      border: Border.all(
                        color: _capturedEmbedding != null ? AppTheme.success : AppTheme.divider,
                        width: _capturedEmbedding != null ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _capturedEmbedding != null
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _capturedEmbedding != null ? Icons.check_circle_rounded : Icons.face_retouching_natural,
                            color: _capturedEmbedding != null ? AppTheme.success : AppTheme.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _capturedEmbedding != null ? 'Face Captured' : 'Capture Face',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _capturedEmbedding != null ? AppTheme.success : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _capturedEmbedding != null
                                    ? 'Tap to re-capture if needed'
                                    : 'Required for face verification',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _capturedEmbedding != null ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleSignup,
                      child: const Text('Create Account'),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}