import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'music/music_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  // Danh sách các màn hình tương ứng với các tab
  final List<Widget> _screens = [
    const HomePage(),
    const Center(child: Text('Màn hình Chi tiêu (Coming soon)')), // Tab Chi tiêu
    const MusicScreen(),
    const Center(child: Text('Màn hình Cá nhân (Coming soon)')), // Tab Cá nhân
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Cho phép body chìm xuống dưới thanh nav
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Custom Bottom Navigation Bar nổi lên như thiết kế
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_filled, 'Trang chủ'),
              _buildNavItem(1, Icons.account_balance_wallet, 'Chi tiêu'),

              // Nút Tạo (+) ở giữa
              GestureDetector(
                onTap: () {
                  // TODO: Xử lý sự kiện mở bottom sheet tạo mới
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6), // Màu tím đậm giống ảnh
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
              ),

              _buildNavItem(2, Icons.music_note, 'Nhạc'),
              _buildNavItem(3, Icons.person, 'Cá Nhân'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade500,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}