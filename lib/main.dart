import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const MoodlyApp());
}

class MoodlyApp extends StatelessWidget {
  const MoodlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moodly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        primaryColor: const Color(0xFF4F46E5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(), // Mặc định vào thẳng Login
    );
  }
}