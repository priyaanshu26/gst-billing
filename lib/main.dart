import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseService.initialize();
  runApp(GstBillingApp(firebaseReady: firebaseReady));
}

class GstBillingApp extends StatelessWidget {
  const GstBillingApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GST Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: firebaseReady
          ? const AuthGate()
          : const _FirebaseUnavailableScreen(),
    );
  }
}

class _FirebaseUnavailableScreen extends StatelessWidget {
  const _FirebaseUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Billing')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppTheme.danger),
              const SizedBox(height: 16),
              Text(
                'Firebase not connected',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                FirebaseService.initError ??
                    'Check firebase_options.dart and your network.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
