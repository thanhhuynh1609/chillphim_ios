import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<dynamic> habits = [];
  bool isLoading = true;
  String activeTab = 'today';
  DateTime currentDate = DateTime.now();
  Map<String, dynamic> monthlyStats = {};
  bool isLoadingStats = false;

  bool isModalOpen = false;
  int? editingHabitId;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String selectedIcon = 'Target';
  final _targetMinutesController = TextEditingController();
  bool isSubmitting = false;

  int? activeMenuId;

  Map<String, dynamic>? timerHabit;
  int timeLeft = 0;
  bool isTimerRunning = false;
  Timer? _timer;

  final Map<String, IconData> iconMap = {
    'Target': Icons.track_changes, 'BookOpen': Icons.menu_book,
    'Dumbbell': Icons.fitness_center, 'Code': Icons.code,
    'Droplets': Icons.water_drop, 'HeartPulse': Icons.monitor_heart,
    'Moon': Icons.dark_mode, 'Coffee': Icons.coffee, 'Briefcase': Icons.work
  };

  @override
  void initState() {
    super.initState();
    _fetchHabits();
  }

  Future<void> _fetchHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    try {
      final res = await http.get(Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() {
          habits = jsonDecode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMonthlyStats(int year, int month) async {
    setState(() => isLoadingStats = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final res = await http.get(Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/monthly_stats/?year=$year&month=$month'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() => monthlyStats = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {} finally {
      setState(() => isLoadingStats = false);
    }
  }

  void _startTimer(Map<String, dynamic> habit) {
    setState(() {
      timerHabit = habit;
      timeLeft = (habit['target_minutes'] as int) * 60;
      isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isTimerRunning) return;
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          isTimerRunning = false;
          _timer?.cancel();
          _handleTimerComplete();
        }
      });
    });
  }

  void _handleTimerComplete() async {
    if (timerHabit != null && !timerHabit!['is_done_today']) {
      await _executeToggleAction(timerHabit!['id'], 'toggle', timerHabit!['is_done_today'], timerHabit!['is_skipped_today']);
    }
    setState(() => timerHabit = null);
  }

  Future<void> _executeToggleAction(int id, String action, bool currentDone, bool currentSkipped) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final res = await http.post(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/$id/toggle_today/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );
      if (res.statusCode == 200) {
        _fetchHabits();
        if (action == 'toggle' && !currentDone) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔥 +1 Kỷ luật!'), backgroundColor: Colors.orange));
      }
    } catch (e) {}
  }

  Future<void> _handleSaveHabit() async {
    if (_nameController.text.isEmpty) return;
    setState(() => isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = editingHabitId != null ? 'https://moodly-backend-6fk0.onrender.com/api/habit/$editingHabitId/' : 'https://moodly-backend-6fk0.onrender.com/api/habit/';

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'description': _descController.text,
          'icon': selectedIcon,
          'target_minutes': int.tryParse(_targetMinutesController.text) ?? 0,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchHabits();
        setState(() => isModalOpen = false);
      }
    } catch (e) {} finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> _handleDelete(int id) async {
    final confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận'), content: const Text('Xóa thói quen này?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
          ],
        )
    );

    if (confirm != true) return;
    final token = (await SharedPreferences.getInstance()).getString('access_token');
    await http.delete(Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/$id/'), headers: {'Authorization': 'Bearer $token'});
    _fetchHabits();
  }

  @override
  Widget build(BuildContext context) {
    int totalHabits = habits.length;
    int doneHabits = habits.where((h) => h['is_done_today']).length;
    int progressPercent = totalHabits == 0 ? 0 : ((doneHabits / totalHabits) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔥 Kỷ luật', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const Text('Chào ngày mới! Cố gắng lên nhé.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tiến độ hôm nay', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$progressPercent%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(width: 8),
                            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('($doneHabits/$totalHabits)', style: const TextStyle(color: Colors.white70))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(value: progressPercent / 100, backgroundColor: Colors.black26, valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent), minHeight: 12),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: habits.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = habits.removeAt(oldIndex);
                      habits.insert(newIndex, item);
                      // Code gọi API lưu thứ tự
                    },
                    itemBuilder: (context, index) {
                      final h = habits[index];
                      final isDone = h['is_done_today'];
                      final isSkipped = h['is_skipped_today'];
                      final IconData icon = iconMap[h['icon']] ?? Icons.track_changes;

                      return Container(
                        key: ValueKey(h['id']),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: isSkipped ? Colors.grey.shade100 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: GestureDetector(
                            onTap: () => _executeToggleAction(h['id'], 'toggle', isDone, isSkipped),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: isSkipped ? Colors.grey.shade200 : (isDone ? Colors.green.shade100 : Colors.indigo.shade50), borderRadius: BorderRadius.circular(16)),
                              child: Icon(isSkipped ? Icons.coffee : (isDone ? Icons.check_circle : icon), color: isSkipped ? Colors.grey : (isDone ? Colors.green : const Color(0xFF4F46E5))),
                            ),
                          ),
                          title: Text(h['name'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone || isSkipped ? TextDecoration.lineThrough : null, color: isDone || isSkipped ? Colors.grey : Colors.black87)),
                          subtitle: Row(
                            children: [
                              if (h['target_minutes'] > 0 && !isDone && !isSkipped)
                                Container(margin: const EdgeInsets.only(top: 4, right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Text('⏱ ${h['target_minutes']}p', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold))),
                              if (h['current_streak'] > 0)
                                Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Text('🔥 ${h['current_streak']} ngày', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (h['target_minutes'] > 0 && !isDone && !isSkipped)
                                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.blue), onPressed: () => _startTimer(h)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'skip') _executeToggleAction(h['id'], 'skip', isDone, isSkipped);
                                  if (val == 'edit') {
                                    setState(() {
                                      editingHabitId = h['id'];
                                      _nameController.text = h['name'];
                                      _descController.text = h['description'];
                                      selectedIcon = h['icon'];
                                      _targetMinutesController.text = h['target_minutes'].toString();
                                      isModalOpen = true;
                                    });
                                  }
                                  if (val == 'delete') _handleDelete(h['id']);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'skip', child: Text('☕ Bỏ qua (Skip)')),
                                  const PopupMenuItem(value: 'edit', child: Text('✏️ Sửa')),
                                  const PopupMenuItem(value: 'delete', child: Text('🗑 Xóa', style: TextStyle(color: Colors.red))),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Padding cho FAB
                ],
              ),
            ),

            // Timer Overlay
            if (timerHabit != null)
              Container(
                color: Colors.black.withOpacity(0.95),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(timerHabit!['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 40),
                      Text('${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w100)),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: Icon(isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 64, color: Colors.white), onPressed: () => setState(() => isTimerRunning = !isTimerRunning)),
                          const SizedBox(width: 20),
                          IconButton(icon: const Icon(Icons.stop_circle, size: 64, color: Colors.redAccent), onPressed: () { _timer?.cancel(); setState(() => timerHabit = null); }),
                        ],
                      )
                    ],
                  ),
                ),
              ),

            // Edit Modal Overlay
            if (isModalOpen)
              Container(
                color: Colors.black54,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(editingHabitId != null ? 'Sửa thói quen' : 'Thêm thói quen', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => isModalOpen = false)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: _nameController, decoration: InputDecoration(hintText: 'Tên thói quen', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        TextField(controller: _descController, decoration: InputDecoration(hintText: 'Mô tả (Tùy chọn)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        TextField(controller: _targetMinutesController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Hẹn giờ (Phút) - Nhập 0 để tắt', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                        const SizedBox(height: 24),
                        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: isSubmitting ? null : _handleSaveHabit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Lưu thói quen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            editingHabitId = null;
            _nameController.clear();
            _descController.clear();
            _targetMinutesController.text = '0';
            isModalOpen = true;
          });
        },
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}