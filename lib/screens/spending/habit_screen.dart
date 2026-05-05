import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_toast.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<dynamic> habits = [];
  bool isLoading = true;
  DateTime currentDate = DateTime.now();
  Map<String, dynamic> monthlyStats = {};
  bool isLoadingStats = false;

  // Debounce: prevent double-tap on toggle
  final Set<int> _togglingIds = {};

  bool isModalOpen = false;
  int? editingHabitId;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String selectedIcon = 'Target';
  final _targetMinutesController = TextEditingController();
  bool isSubmitting = false;

  Map<String, dynamic>? timerHabit;
  int timeLeft = 0;
  bool isTimerRunning = false;
  Timer? _timer;

  final Map<String, IconData> iconMap = {
    'Target': Icons.track_changes,
    'BookOpen': Icons.menu_book,
    'Dumbbell': Icons.fitness_center,
    'Code': Icons.code,
    'Droplets': Icons.water_drop,
    'HeartPulse': Icons.monitor_heart,
    'Moon': Icons.dark_mode,
    'Coffee': Icons.coffee,
    'Briefcase': Icons.work,
  };

  @override
  void initState() {
    super.initState();
    _fetchHabits();
    _fetchMonthlyStats(currentDate.year, currentDate.month);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _descController.dispose();
    _targetMinutesController.dispose();
    super.dispose();
  }

  Future<void> _fetchHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          habits = jsonDecode(utf8.decode(res.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMonthlyStats(int year, int month) async {
    if (mounted) setState(() => isLoadingStats = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/monthly_stats/?year=$year&month=$month'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => monthlyStats = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      // silently fail
    } finally {
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  void _startTimer(Map<String, dynamic> habit) {
    setState(() {
      timerHabit = habit;
      timeLeft = (habit['target_minutes'] as int) * 60;
      isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!isTimerRunning) return;
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          isTimerRunning = false;
          timer.cancel();
          _handleTimerComplete();
        }
      });
    });
  }

  void _handleTimerComplete() async {
    if (timerHabit != null && timerHabit!['is_done_today'] == false) {
      await _executeToggleAction(
          timerHabit!['id'], 'toggle', timerHabit!['is_done_today'], timerHabit!['is_skipped_today']);
    }
    if (mounted) setState(() => timerHabit = null);
  }

  Future<void> _executeToggleAction(int id, String action, bool currentDone, bool currentSkipped) async {
    // Prevent double-tap
    if (_togglingIds.contains(id)) return;
    if (mounted) setState(() => _togglingIds.add(id));

    // Optimistic UI update
    final idx = habits.indexWhere((h) => h['id'] == id);
    if (idx != -1 && mounted) {
      setState(() {
        if (action == 'toggle') {
          habits[idx] = Map<String, dynamic>.from(habits[idx])
            ..['is_done_today'] = !currentDone
            ..['is_skipped_today'] = false;
        } else if (action == 'skip') {
          habits[idx] = Map<String, dynamic>.from(habits[idx])
            ..['is_skipped_today'] = !currentSkipped
            ..['is_done_today'] = false;
        }
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final res = await http.post(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/$id/toggle_today/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );
      if (res.statusCode == 200) {
        if (action == 'toggle' && !currentDone && mounted) {
          AppToast.show(context, '🔥 +1 Kỷ luật!', type: ToastType.warning);
        }
        // Sync with server to get accurate state (streak, etc.)
        await _fetchHabits();
        // Refresh calendar stats for today's month
        await _fetchMonthlyStats(currentDate.year, currentDate.month);
      } else {
        // Revert optimistic update on failure
        if (idx != -1 && mounted) {
          setState(() {
            habits[idx] = Map<String, dynamic>.from(habits[idx])
              ..['is_done_today'] = currentDone
              ..['is_skipped_today'] = currentSkipped;
          });
        }
      }
    } catch (e) {
      // Revert on network error
      if (idx != -1 && mounted) {
        setState(() {
          habits[idx] = Map<String, dynamic>.from(habits[idx])
            ..['is_done_today'] = currentDone
            ..['is_skipped_today'] = currentSkipped;
        });
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
    }
  }

  Future<void> _handleSaveHabit() async {
    if (_nameController.text.isEmpty) return;
    setState(() => isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = editingHabitId != null
        ? 'https://moodly-backend-6fk0.onrender.com/api/habit/$editingHabitId/'
        : 'https://moodly-backend-6fk0.onrender.com/api/habit/';

    try {
      final res = editingHabitId != null
          ? await http.put(
              Uri.parse(url),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': _nameController.text,
                'description': _descController.text,
                'icon': selectedIcon,
                'target_minutes': int.tryParse(_targetMinutesController.text) ?? 0,
              }),
            )
          : await http.post(
              Uri.parse(url),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': _nameController.text,
                'description': _descController.text,
                'icon': selectedIcon,
                'target_minutes': int.tryParse(_targetMinutesController.text) ?? 0,
              }),
            );
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        _fetchHabits();
        setState(() => isModalOpen = false);
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _handleDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Xóa thói quen này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final token = (await SharedPreferences.getInstance()).getString('access_token');
    await http.delete(
      Uri.parse('https://moodly-backend-6fk0.onrender.com/api/habit/$id/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _fetchHabits();
  }

  // ─────────────────────────── CALENDAR ───────────────────────────

  Widget _buildMonthlyCalendar() {
    final today = DateTime.now();
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
    final firstWeekday = DateTime(currentDate.year, currentDate.month, 1).weekday;
    final emptyPrefix = firstWeekday - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.grey),
                onPressed: () {
                  final d = DateTime(currentDate.year, currentDate.month - 1, 1);
                  setState(() => currentDate = d);
                  _fetchMonthlyStats(d.year, d.month);
                },
              ),
              Text(
                'Tháng ${currentDate.month} năm ${currentDate.year}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
                onPressed: () {
                  final d = DateTime(currentDate.year, currentDate.month + 1, 1);
                  setState(() => currentDate = d);
                  _fetchMonthlyStats(d.year, d.month);
                },
              ),
            ],
          ),
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map((d) => SizedBox(
                      width: 36,
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          isLoadingStats
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: daysInMonth + emptyPrefix,
                  itemBuilder: (context, index) {
                    if (index < emptyPrefix) return const SizedBox();
                    final day = index - emptyPrefix + 1;
                    final dateStr =
                        '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final stat = monthlyStats[dateStr];
                    final isToday = today.year == currentDate.year &&
                        today.month == currentDate.month &&
                        today.day == day;
                    final isFuture =
                        DateTime(currentDate.year, currentDate.month, day).isAfter(today);

                    Color bgColor;
                    Color textColor;

                    if (isFuture) {
                      bgColor = Colors.transparent;
                      textColor = Colors.grey.shade300;
                    } else if (stat != null) {
                      final percent = stat['percent'] as int;
                      final isPerfect = stat['is_perfect'] as bool;
                      if (isPerfect) {
                        bgColor = const Color(0xFF4F46E5);
                        textColor = Colors.white;
                      } else if (percent >= 50) {
                        bgColor = Colors.green.shade100;
                        textColor = Colors.green.shade700;
                      } else if (percent > 0) {
                        bgColor = Colors.orange.shade100;
                        textColor = Colors.orange.shade800;
                      } else {
                        bgColor = Colors.red.shade50;
                        textColor = Colors.grey.shade500;
                      }
                    } else {
                      bgColor = Colors.grey.shade100;
                      textColor = Colors.grey.shade400;
                    }

                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: const Color(0xFF4F46E5), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday && bgColor == Colors.transparent
                                ? const Color(0xFF4F46E5)
                                : textColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF4F46E5), 'Hoàn hảo'),
              const SizedBox(width: 10),
              _legendDot(Colors.green.shade100, 'Tốt (≥50%)'),
              const SizedBox(width: 10),
              _legendDot(Colors.orange.shade100, 'Một phần'),
              const SizedBox(width: 10),
              _legendDot(Colors.red.shade50, 'Chưa làm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalHabits = habits.length;
    final doneHabits = habits.where((h) => h['is_done_today'] == true).length;
    final progressPercent = totalHabits == 0 ? 0 : ((doneHabits / totalHabits) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text('🔥 Kỷ luật',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const Text('Chào ngày mới! Cố gắng lên nhé.',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Progress card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tiến độ hôm nay',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$progressPercent%',
                                style: const TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('($doneHabits/$totalHabits)',
                                  style: const TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: totalHabits == 0 ? 0 : progressPercent / 100,
                            backgroundColor: Colors.black26,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            minHeight: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Monthly calendar history
                  _buildMonthlyCalendar(),
                  const SizedBox(height: 20),

                  // Habit list
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
                          },
                          itemBuilder: (context, index) {
                            final h = habits[index];
                            final isDone = h['is_done_today'] == true;
                            final isSkipped = h['is_skipped_today'] == true;
                            final isToggling = _togglingIds.contains(h['id']);
                            final IconData icon = iconMap[h['icon']] ?? Icons.track_changes;

                            return Container(
                              key: ValueKey(h['id']),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSkipped ? Colors.grey.shade100 : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                onTap: isToggling
                                    ? null
                                    : () => _executeToggleAction(h['id'], 'toggle', isDone, isSkipped),
                                contentPadding: const EdgeInsets.all(12),
                                leading: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isToggling
                                        ? Colors.grey.shade100
                                        : isSkipped
                                            ? Colors.grey.shade200
                                            : isDone
                                                ? Colors.green.shade100
                                                : Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: isToggling
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Color(0xFF4F46E5)),
                                        )
                                      : Icon(
                                          isSkipped
                                              ? Icons.coffee
                                              : isDone
                                                  ? Icons.check_circle
                                                  : icon,
                                          color: isSkipped
                                              ? Colors.grey
                                              : isDone
                                                  ? Colors.green
                                                  : const Color(0xFF4F46E5),
                                        ),
                                ),
                                title: Text(
                                  h['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDone || isSkipped ? TextDecoration.lineThrough : null,
                                    color: isDone || isSkipped ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    if (h['target_minutes'] > 0 && !isDone && !isSkipped)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4, right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(10)),
                                        child: Text('⏱ ${h['target_minutes']}p',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    if (h['current_streak'] > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(10)),
                                        child: Text('🔥 ${h['current_streak']} ngày',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (h['target_minutes'] > 0 && !isDone && !isSkipped)
                                      IconButton(
                                          icon: const Icon(Icons.play_arrow, color: Colors.blue),
                                          onPressed: () => _startTimer(h)),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onSelected: (val) {
                                        if (val == 'skip')
                                          _executeToggleAction(h['id'], 'skip', isDone, isSkipped);
                                        if (val == 'edit') {
                                          setState(() {
                                            editingHabitId = h['id'];
                                            _nameController.text = h['name'];
                                            _descController.text = h['description'] ?? '';
                                            selectedIcon = h['icon'];
                                            _targetMinutesController.text =
                                                h['target_minutes'].toString();
                                            isModalOpen = true;
                                          });
                                        }
                                        if (val == 'delete') _handleDelete(h['id']);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'skip', child: Text('☕ Bỏ qua (Skip)')),
                                        const PopupMenuItem(value: 'edit', child: Text('✏️ Sửa')),
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('🗑 Xóa', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                      Text(timerHabit!['name'],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 40),
                      Text(
                        '${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 72, fontWeight: FontWeight.w100),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              size: 64,
                              color: Colors.white,
                            ),
                            onPressed: () => setState(() => isTimerRunning = !isTimerRunning),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.stop_circle, size: 64, color: Colors.redAccent),
                            onPressed: () {
                              _timer?.cancel();
                              setState(() => timerHabit = null);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Add / Edit Modal
            if (isModalOpen)
              Container(
                color: Colors.black54,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              editingHabitId != null ? 'Sửa thói quen' : 'Thêm thói quen',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => isModalOpen = false)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Tên thói quen',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descController,
                          decoration: InputDecoration(
                            hintText: 'Mô tả (Tùy chọn)',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _targetMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Hẹn giờ (Phút) - Nhập 0 để tắt',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _handleSaveHabit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20))),
                            child: isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Lưu thói quen',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 100),
        child: FloatingActionButton(
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
      ),
    );
  }
}
