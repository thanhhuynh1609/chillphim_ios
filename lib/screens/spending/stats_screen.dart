import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_toast.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<dynamic> transactions = [];
  DateTime currentDate = DateTime.now();
  bool isLoading = true;
  String activeTab = 'expense';

  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  final List<Color> expenseColors = const [
    Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFFF97316), Color(0xFF14B8A6), Color(0xFF64748B), Color(0xFF84CC16)
  ];
  final List<Color> incomeColors = const [
    Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFF0EA5E9), Color(0xFF6366F1),
    Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFFF43F5E), Color(0xFFEAB308)
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() => transactions = data is List ? data : (data['results'] ?? []));
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Lỗi tải dữ liệu');
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredTransactions {
    return transactions.where((t) {
      final d = DateTime.parse(t['transaction_date']);
      return t['transaction_type'] == activeTab &&
          d.month == currentDate.month &&
          d.year == currentDate.year;
    }).toList();
  }

  double get totalAmount {
    return filteredTransactions.fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  List<Map<String, dynamic>> get sortedCategories {
    Map<String, double> categoryData = {};
    for (var t in filteredTransactions) {
      String cat = t['category'] ?? 'Khác';
      categoryData[cat] = (categoryData[cat] ?? 0) + (t['amount'] as num).toDouble();
    }

    if (categoryData.isEmpty) return [];

    final currentColors = activeTab == 'expense' ? expenseColors : incomeColors;

    List<Map<String, dynamic>> result = categoryData.entries.map((e) {
      return {
        'name': e.key,
        'amount': e.value,
        'percent': totalAmount > 0 ? (e.value / totalAmount) * 100 : 0.0,
      };
    }).toList();

    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    for (int i = 0; i < result.length; i++) {
      result[i]['color'] = currentColors[i % currentColors.length];
    }

    return result;
  }

  void _prevMonth() => setState(() => currentDate = DateTime(currentDate.year, currentDate.month - 1, 1));
  void _nextMonth() => setState(() => currentDate = DateTime(currentDate.year, currentDate.month + 1, 1));

  @override
  Widget build(BuildContext context) {
    final categoriesList = sortedCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                          child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                        child: const Icon(Icons.pie_chart, color: Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thống kê', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                          Text('Phân tích dòng tiền của bạn', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade200.withOpacity(0.5), borderRadius: BorderRadius.circular(24)),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          alignment: activeTab == 'expense' ? Alignment.centerLeft : Alignment.centerRight,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))])),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => activeTab = 'expense'),
                                behavior: HitTestBehavior.opaque,
                                child: Center(child: Text('Khoản Chi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: activeTab == 'expense' ? Colors.red.shade500 : Colors.grey.shade500))),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => activeTab = 'income'),
                                behavior: HitTestBehavior.opaque,
                                child: Center(child: Text('Khoản Thu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: activeTab == 'income' ? Colors.green.shade500 : Colors.grey.shade500))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(onTap: _prevMonth, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(shape: BoxShape.circle), child: Icon(Icons.chevron_left, color: Colors.grey.shade400))),
                        Text('Tháng ${currentDate.month} / ${currentDate.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        GestureDetector(onTap: _nextMonth, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(shape: BoxShape.circle), child: Icon(Icons.chevron_right, color: Colors.grey.shade400))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
              onRefresh: _fetchTransactions,
              color: const Color(0xFF4F46E5),
              child: isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))))],
                    )
                  : (totalAmount == 0 || categoriesList.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 24),
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: Icon(Icons.receipt_long, color: Colors.grey.shade300, size: 32)),
                                const SizedBox(height: 16),
                                const Text('Chưa có dữ liệu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('Không có khoản ${activeTab == 'expense' ? 'chi' : 'thu'} nào trong tháng này.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Center(
                        child: SizedBox(
                          width: 200, height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return CustomPaint(
                                    size: const Size(200, 200),
                                    painter: DonutChartPainter(categories: categoriesList, animationValue: value),
                                  );
                                },
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(activeTab == 'expense' ? 'TỔNG CHI' : 'TỔNG THU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5)),
                                  const SizedBox(height: 4),
                                  Text(currencyFormat.format(totalAmount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: activeTab == 'expense' ? Colors.black87 : Colors.green.shade600)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(activeTab == 'expense' ? Icons.trending_down : Icons.trending_up, color: activeTab == 'expense' ? Colors.red.shade500 : Colors.green.shade500, size: 20),
                        const SizedBox(width: 8),
                        Text(activeTab == 'expense' ? 'Chi tiết khoản chi' : 'Nguồn thu nhập', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoriesList.length,
                      itemBuilder: (context, index) {
                        final cat = categoriesList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))]),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 16, height: 16, decoration: BoxDecoration(color: cat['color'], shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)])),
                                      const SizedBox(width: 12),
                                      Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                  Text(currencyFormat.format(cat['amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: Row(
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            tween: Tween<double>(begin: 0, end: cat['percent'] / 100),
                                            duration: const Duration(milliseconds: 1000),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, child) {
                                              return FractionallySizedBox(
                                                widthFactor: value,
                                                child: Container(decoration: BoxDecoration(color: cat['color'], borderRadius: BorderRadius.circular(4))),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(width: 40, child: Text('${(cat['percent'] as double).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500), textAlign: TextAlign.right)),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final double animationValue;

  DonutChartPainter({required this.categories, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    double currentStartAngle = -pi / 2;

    for (var cat in categories) {
      final sweepAngle = ((cat['percent'] / 100) * 2 * pi) * animationValue;

      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = cat['color']
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = cat['percent'] > 2 ? StrokeCap.round : StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          currentStartAngle,
          sweepAngle,
          false,
          paint,
        );
        currentStartAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.categories != categories;
  }
}