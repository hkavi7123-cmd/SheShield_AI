import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize central Settings & Preferences Service
  await SettingsService.instance.init();

  runApp(const SheShieldAI());
}

class SheShieldAI extends StatelessWidget {
  const SheShieldAI({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "SheShield AI",
          themeMode: SettingsService.instance.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepPurple,
            scaffoldBackgroundColor: const Color(0xFFF5F3FF),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepPurple,
            scaffoldBackgroundColor: const Color(0xFF121212),
            brightness: Brightness.dark,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}