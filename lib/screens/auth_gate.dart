import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Routes between login and the signed-in shop workspace.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.watchSession(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return const HomeShell();
        }

        // Initial auth check only. After sign-out the stream emits null and
        // must show LoginScreen even if a previous user was present.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
