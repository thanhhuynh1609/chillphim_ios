import 'dart:ui';
import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'music/music_screen.dart';
import 'profile/profile_screen.dart';
import 'spending/spending_home_screen.dart';
import 'spending/stats_screen.dart';
import 'spending/accounts_screen.dart';
import 'spending/habit_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  int _spendingIndex = 0; // Index cho menu con của phần Chi tiêu

  // Danh sách màn hình chính
  final List<Widget> _mainScreens = [
    const HomePage(),
    const SizedBox(), // Placeholder cho Chi tiêu (sẽ xử lý riêng bên dưới)
    const Scaffold(), // Placeholder cho nút [+]
    const MusicScreen(),
    const ProfilePage(),
  ];

  // Danh sách màn hình con của phần Chi tiêu
  final List<Widget> _spendingScreens = [
    const SpendingHomeScreen(),
    const StatsScreen(),
    const AccountsScreen(),
    const HabitScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Kiểm tra xem có đang ở chế độ Chi tiêu không
    final isSpendingMode = _currentIndex == 1;

    return Scaffold(
      extendBody: true,
      // Đổi body tùy theo chế độ
      body: isSpendingMode
          ? IndexedStack(
        index: _spendingIndex,
        children: _spendingScreens,
      )
          : IndexedStack(
        index: _currentIndex,
        children: _mainScreens,
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          // Chuyển đổi giữa 2 thanh Nav
          child: isSpendingMode ? _buildSpendingNav() : _buildMainNav(),
        ),
      ),
    );
  }

  // ==========================================
  // THANH ĐIỀU HƯỚNG CHÍNH
  // ==========================================
  Widget _buildMainNav() {
    return Container(
      key: const ValueKey('MainNav'),
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMainNavItem(0, Icons.home_outlined, Icons.home_filled, 'Trang chủ'),
                _buildMainNavBadgeItem(1, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Chi tiêu'),
                const SizedBox(width: 60),
                _buildMainNavItem(3, Icons.music_note_outlined, Icons.music_note, 'Nhạc'),
                _buildMainNavItem(4, Icons.person_outline, Icons.person, 'Cá Nhân'),
              ],
            ),
          ),
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF4F46E5) : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? iconFilled : iconOutlined, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainNavBadgeItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF4F46E5) : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isSelected ? iconFilled : iconOutlined, color: color, size: 26),
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.priority_high, color: Colors.white, size: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // THANH ĐIỀU HƯỚNG PHẦN CHI TIÊU (SUB-NAV)
  // ==========================================
  Widget _buildSpendingNav() {
    return Container(
      key: const ValueKey('SpendingNav'),
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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nút Quay lại
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 0), // Trở về màn Trang chủ
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 55,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
                        ),
                        const SizedBox(height: 2),
                        const Text('Quay lại', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 7),
                      ],
                    ),
                  ),
                ),
                _buildSpendingTabItem(0, Icons.calendar_today_outlined, Icons.calendar_month, 'Lịch'),
                _buildSpendingTabItem(1, Icons.pie_chart_outline, Icons.pie_chart, 'Thống kê'),
                _buildSpendingTabItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Tài khoản'),
                _buildSpendingTabItem(3, Icons.local_fire_department_outlined, Icons.local_fire_department, 'Giữ lửa'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendingTabItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _spendingIndex == index;
    final color = isSelected ? const Color(0xFF4F46E5) : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _spendingIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(isSelected ? iconFilled : iconOutlined, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 16 : 0,
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }
}