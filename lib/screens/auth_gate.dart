import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_home_screen.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';
import 'teacher_home_screen.dart';
import 'student_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return FutureBuilder(
      future: authService.getCurrentAppUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final appUser = snapshot.data;

        if (appUser == null) {
          return const LoginScreen();
        } else if (appUser.role == 'admin') {
          return const AdminHomeScreen();
        } else if (appUser.role == 'teacher') {
          if (appUser.status == 'approved') {
            return const TeacherHomeScreen();
          } else {
            return PendingApprovalScreen(user: appUser);
          }
        } else {
          return const StudentHomeScreen();
        }
      },
    );
  }
}