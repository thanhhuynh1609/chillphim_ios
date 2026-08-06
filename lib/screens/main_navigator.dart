import 'dart:ui';
import 'package:flutter/material.dart';
import 'spending/spending_home_screen.dart';
import 'spending/stats_screen.dart';
import 'spending/accounts_screen.dart';
import 'spending/habit_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SpendingHomeScreen(),
    const StatsScreen(),
    const AccountsScreen(),
    const ProfilePage(),
    const HabitScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.calendar_month_outlined, Icons.calendar_month, 'Lịch'),
                _buildNavItem(1, Icons.pie_chart_outline, Icons.pie_chart, 'Thống kê'),
                _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Tài khoản'),
                // _buildNavItem(3, Icons.local_fire_department_outlined, Icons.local_fire_department, 'Giữ lửa'),
                _buildNavItem(3, Icons.person_outline, Icons.person, 'Cá nhân'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF4F46E5) : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? iconFilled : iconOutlined,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 16 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
