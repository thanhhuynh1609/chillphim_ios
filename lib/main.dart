import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigator.dart';

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
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
      home: const AuthCheckScreen(),
    );
  }
}

// ==========================================
// TRẠM KIỂM SOÁT ĐĂNG NHẬP (SPLASH SCREEN)
// ==========================================
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedToken();
  }

  Future<void> _checkSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    // Tạo độ trễ nhỏ (0.5s) để hiển thị mượt mà màn hình chờ
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Nếu token tồn tại và không rỗng -> Chuyển thẳng vào App
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator())
      );
    } else {
      // Nếu không có token -> Bắt đăng nhập
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Màn hình loading khi app vừa bật lên
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}