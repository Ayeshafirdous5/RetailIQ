import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(RetailIqApp(authService: AuthService()));
}

class RetailIqApp extends StatelessWidget {
  const RetailIqApp({this.authService, super.key});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetailIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(authService: authService ?? AuthService()),
    );
  }
}