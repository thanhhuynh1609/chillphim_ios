import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/app_toast.dart';
import '../auth/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = "";
  String avatarUrl = "";
  bool isUploading = false;
  bool isAdmin = false;
  bool showPasswordModal = false;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/accounts/profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          username = data['username'] ?? "";
          avatarUrl = data['avatar_url'] ?? "";
          isAdmin = data['is_admin'] ?? false;
        });
      }
    } catch (e) {}
  }

  Future<void> _handleAvatarChange() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    setState(() => isUploading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      var request = http.MultipartRequest('PUT', Uri.parse('https://moodly-backend-6fk0.onrender.com/api/accounts/profile/avatar/'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(await http.MultipartFile.fromPath('avatar', result.files.single.path!));

      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        var response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);
        setState(() => avatarUrl = data['avatar_url']);
        if (mounted) AppToast.success(context, 'Cập nhật ảnh thành công!');
      } else {
        if (mounted) AppToast.error(context, 'Lỗi tải ảnh');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Lỗi kết nối');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      final res = await http.put(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/accounts/profile/change-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) AppToast.success(context, 'Đổi mật khẩu thành công!');
        setState(() {
          _oldPasswordController.clear();
          _newPasswordController.clear();
          showPasswordModal = false;
        });
      } else {
        final errorData = jsonDecode(res.body);
        if (mounted) AppToast.error(context, errorData['error'] ?? 'Đổi mật khẩu thất bại.');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Lỗi kết nối');
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _handleComingSoon() {
    AppToast.show(context, '🚧 Tính năng đang phát triển');
  }

  Widget _buildMenuRow(IconData icon, String label, {String value = "", required VoidCallback onClick, bool isLast = false, Color color = Colors.grey}) {
    return InkWell(
      onTap: onClick,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15)),
              ],
            ),
            Row(
              children: [
                if (value.isNotEmpty) Text(value, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _handleAvatarChange,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [Colors.pink, Colors.purple, Colors.indigo], begin: Alignment.topRight, end: Alignment.bottomLeft),
                                ),
                                child: Opacity(
                                  opacity: isUploading ? 0.5 : 1.0,
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.white,
                                    backgroundImage: NetworkImage(avatarUrl.isNotEmpty ? avatarUrl : "https://mautranhve.vn/wp-content/uploads/2025/10/avatar-hai-cute-25.jpg"),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(username.isNotEmpty ? username : "Người dùng", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade700),
                                  const SizedBox(width: 4),
                                  Text("thg ${DateTime.now().month} ${DateTime.now().year}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _handleComingSoon,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  children: [
                                    Icon(Icons.link, size: 12, color: Colors.amber.shade900),
                                    const SizedBox(width: 4),
                                    Text("Chia sẻ hồ sơ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isAdmin)
                    GestureDetector(
                      onTap: _handleComingSoon,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.security, color: Colors.indigo.shade600),
                                const SizedBox(width: 12),
                                Text("Trang Quản Trị Hệ Thống", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                              ],
                            ),
                            Icon(Icons.chevron_right, color: Colors.indigo.shade300),
                          ],
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Đăng xuất", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildMenuRow(Icons.lock_outline, "Đổi mật khẩu", color: Colors.red.shade400, onClick: () => setState(() => showPasswordModal = true)),
                        _buildMenuRow(Icons.people_outline, "Bạn bè", color: Colors.blue.shade500, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.groups, "Nhóm", color: Colors.indigo.shade500, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.repeat, "Định kỳ", color: Colors.teal.shade500, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.settings_outlined, "Cài đặt", color: Colors.grey.shade500, onClick: _handleComingSoon, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.workspace_premium, color: Colors.grey, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Nâng cấp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text("Mở khóa tất cả tính năng...", style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            )
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _handleComingSoon,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade400,
                            foregroundColor: Colors.amber.shade900,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 10,
                            shadowColor: Colors.amber.shade400.withOpacity(0.5),
                          ),
                          child: const Text("Nâng cấp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _handleComingSoon,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.security, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text("Email ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: Text("Đã liên kết", style: TextStyle(color: Colors.green.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  Text("${username.isEmpty ? 'user' : username}@moodly.app", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              )
                            ],
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildMenuRow(Icons.folder_open_outlined, "Danh mục", color: Colors.blue.shade400, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.language, "Ngôn ngữ", value: "🇻🇳 Tiếng Việt", color: Colors.orange.shade400, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.dark_mode_outlined, "Giao diện", value: "Sáng", color: Colors.indigo.shade400, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.attach_money, "Tiền tệ", value: "🇻🇳 VND", color: Colors.green.shade500, onClick: _handleComingSoon, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildMenuRow(Icons.star_border, "Đánh giá ứng dụng", color: Colors.amber.shade400, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.chat_bubble_outline, "Góp ý", color: Colors.blue.shade400, onClick: _handleComingSoon),
                        _buildMenuRow(Icons.ios_share, "Chia sẻ ứng dụng", color: Colors.green.shade400, onClick: _handleComingSoon, isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text("Moodly", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Phiên bản (Function) 1.0.0", style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          if (showPasswordModal)
            Container(
              color: Colors.black54,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline, color: Color(0xFF4F46E5)),
                            SizedBox(width: 8),
                            Text("Đổi mật khẩu", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => showPasswordModal = false),
                          style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Mật khẩu hiện tại",
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Mật khẩu mới",
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleChangePassword,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text("Cập nhật mật khẩu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}