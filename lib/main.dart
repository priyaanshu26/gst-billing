import 'package:flutter/material.dart';

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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('GST Billing'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  firebaseReady
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 56,
                  color: firebaseReady
                      ? AppTheme.success
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'GST Billing MVP',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  firebaseReady
                      ? 'Firebase initialized. Screens coming next.'
                      : 'App is running. Replace firebase_options.dart '
                          '(or run flutterfire configure) to connect Firebase.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (!firebaseReady && FirebaseService.initError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    FirebaseService.initError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.danger,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
