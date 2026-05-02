import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/transaction_model.dart';
import '../auth/login_screen.dart';
import 'daily_spending_screen.dart';
import 'new_transaction_screen.dart';

class SpendingHomeScreen extends StatefulWidget {
  const SpendingHomeScreen({super.key});

  @override
  State<SpendingHomeScreen> createState() => _SpendingHomeScreenState();
}

class _SpendingHomeScreenState extends State<SpendingHomeScreen> {
  List<TransactionModel> allTransactions = [];
  DateTime currentDate = DateTime.now();
  bool isLoading = true;

  bool isCalendarView = true;
  String searchQuery = '';
  String filterCategory = 'Tất cả';
  String filterSource = 'all';

  final List<String> categories = ['Tất cả', 'Ăn uống', 'Mua sắm', 'Di chuyển', 'Sức khỏe', 'Khác'];
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _fetchAllTransactions();
  }

  Future<void> _fetchAllTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> listData = data is List ? data : (data['results'] ?? []);
        setState(() {
          allTransactions = listData.map((json) => TransactionModel.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<TransactionModel> get currentMonthTransactions {
    return allTransactions.where((t) {
      final d = DateTime.parse(t.transactionDate);
      return d.month == currentDate.month && d.year == currentDate.year;
    }).toList();
  }

  List<TransactionModel> get filteredTransactions {
    return currentMonthTransactions.where((t) {
      final matchSearch = t.note.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(searchQuery.toLowerCase());
      final matchCategory = filterCategory == 'Tất cả' ? true : t.category == filterCategory;
      final matchSource = filterSource == 'all' ? true : t.source == filterSource;
      return matchSearch && matchCategory && matchSource;
    }).toList();
  }

  double get totalExpense => filteredTransactions.where((t) => t.transactionType == 'expense').fold(0, (sum, t) => sum + t.amount);
  double get totalIncome => filteredTransactions.where((t) => t.transactionType == 'income').fold(0, (sum, t) => sum + t.amount);

  double get todayExpense {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return allTransactions.where((t) => t.transactionDate.startsWith(todayStr) && t.transactionType == 'expense').fold(0, (sum, t) => sum + t.amount);
  }

  double get todayIncome {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return allTransactions.where((t) => t.transactionDate.startsWith(todayStr) && t.transactionType == 'income').fold(0, (sum, t) => sum + t.amount);
  }

  double get walletBalance => allTransactions.where((t) => t.source == 'wallet').fold(0, (sum, t) => t.transactionType == 'income' ? sum + t.amount : sum - t.amount);
  double get bankBalance => allTransactions.where((t) => t.source == 'bank').fold(0, (sum, t) => t.transactionType == 'income' ? sum + t.amount : sum - t.amount);

  bool get isFiltering => filterCategory != 'Tất cả' || filterSource != 'all';

  Map<int, List<TransactionModel>> get transactionsByDay {
    Map<int, List<TransactionModel>> map = {};
    for (var tx in filteredTransactions) {
      final day = DateTime.parse(tx.transactionDate).day;
      if (!map.containsKey(day)) map[day] = [];
      map[day]!.add(tx);
    }
    return map;
  }

  void _handleDayClick(int day, bool hasPhotos) {
    final targetDate = DateFormat('yyyy-MM-dd').format(DateTime(currentDate.year, currentDate.month, day));
    if (hasPhotos) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DailySpendingScreen(dateStr: targetDate))).then((_) => _fetchAllTransactions());
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NewTransactionScreen(dateStr: targetDate))).then((_) => _fetchAllTransactions());
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bộ lọc chi tiêu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Danh mục', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = filterCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => filterCategory = cat);
                            setState(() => filterCategory = cat);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200),
                            ),
                            child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('Nguồn tiền', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSourceFilterBtn('all', 'Tất cả', setModalState),
                        const SizedBox(width: 8),
                        _buildSourceFilterBtn('wallet', 'Ví (Tiền mặt)', setModalState),
                        const SizedBox(width: 8),
                        _buildSourceFilterBtn('bank', 'Ngân hàng', setModalState),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                filterCategory = 'Tất cả';
                                filterSource = 'all';
                              });
                              setState(() {
                                filterCategory = 'Tất cả';
                                filterSource = 'all';
                                searchQuery = '';
                              });
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(backgroundColor: Colors.grey.shade100, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            child: const Text('Xóa lọc', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildSourceFilterBtn(String id, String label, Function setModalState) {
    final isSelected = filterSource == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() => filterSource = id);
          setState(() => filterSource = id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200),
          ),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Chào ngày mới', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(width: 4),
                          Icon(Icons.wb_sunny, color: Colors.orange.shade400, size: 14),
                        ],
                      ),
                      const Text('Đỗ Nghèo Khỉ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Hôm nay đã chi: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          Text(currencyFormat.format(todayExpense), style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                          const Text(', thu: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          Text(currencyFormat.format(todayIncome), style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => isCalendarView = true),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: isCalendarView ? const Color(0xFF4F46E5) : Colors.transparent, shape: BoxShape.circle),
                            child: Icon(Icons.calendar_month, size: 18, color: isCalendarView ? Colors.white : Colors.grey),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => isCalendarView = false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: !isCalendarView ? const Color(0xFF4F46E5) : Colors.transparent, shape: BoxShape.circle),
                            child: Icon(Icons.list_alt, size: 18, color: !isCalendarView ? Colors.white : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBalanceCard(Icons.account_balance_wallet, 'Wallet', walletBalance, Colors.green),
                    const SizedBox(width: 8),
                    _buildBalanceCard(Icons.account_balance, 'Bank', bankBalance, Colors.blue),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Tổng: ${currencyFormat.format(walletBalance + bankBalance)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm chi tiêu...',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          icon: const Icon(Icons.search, color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => searchQuery = '')) : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: isFiltering ? const Color(0xFF4F46E5) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isFiltering ? const Color(0xFF4F46E5) : Colors.grey.shade200),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.tune, color: isFiltering ? Colors.white : Colors.grey.shade600),
                          if (isFiltering)
                            Positioned(top: 10, right: 10, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4F46E5), width: 1.5)))),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(Icons.arrow_upward, 'Đã chi', totalExpense, Colors.red)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(Icons.arrow_downward, 'Đã thu', totalIncome, Colors.green)),
                ],
              ),
              const SizedBox(height: 24),
              isCalendarView ? _buildCalendarView() : _buildFeedView(),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          onPressed: () {
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            Navigator.push(context, MaterialPageRoute(builder: (_) => NewTransactionScreen(dateStr: todayStr))).then((_) => _fetchAllTransactions());
          },
          backgroundColor: const Color(0xFF4F46E5),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBalanceCard(IconData icon, String label, double amount, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text('$label: ${currencyFormat.format(amount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(currencyFormat.format(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(isFiltering || searchQuery.isNotEmpty ? '$label (lọc)' : '$label tháng này', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    int daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
    int firstDayWeekday = DateTime(currentDate.year, currentDate.month, 1).weekday;
    int startingEmptyDays = firstDayWeekday - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: Colors.grey), onPressed: () => setState(() => currentDate = DateTime(currentDate.year, currentDate.month - 1, 1))),
              Text('Tháng ${currentDate.month} năm ${currentDate.year}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              IconButton(icon: const Icon(Icons.chevron_right, color: Colors.grey), onPressed: () => setState(() => currentDate = DateTime(currentDate.year, currentDate.month + 1, 1))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((d) => Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))).toList(),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.55,
                crossAxisSpacing: 4,
                mainAxisSpacing: 8
            ),
            itemCount: daysInMonth + startingEmptyDays,
            itemBuilder: (context, index) {
              if (index < startingEmptyDays) return const SizedBox();

              int day = index - startingEmptyDays + 1;
              final dayTransactions = transactionsByDay[day] ?? [];
              final photos = dayTransactions.where((t) => t.imageUrl != null).map((t) => t.imageUrl!).toList();
              final hasPhotos = photos.isNotEmpty;

              return GestureDetector(
                onTap: () => _handleDayClick(day, hasPhotos),
                child: Column(
                  children: [
                    hasPhotos
                        ? SizedBox(
                      width: 36, height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (photos.length > 1) Positioned(left: 0, top: 4, child: Transform.rotate(angle: -0.2, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: photos[1], width: 28, height: 28, fit: BoxFit.cover)))),
                          Positioned(right: 0, top: 0, child: Transform.rotate(angle: 0.1, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(10)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: photos[0], width: 28, height: 28, fit: BoxFit.cover))))),
                          if (photos.length > 2) Positioned(bottom: 0, right: -4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle), child: Text('+${photos.length - 2}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)))),
                        ],
                      ),
                    )
                        : Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                      child: Icon(Icons.add, size: 16, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 4),
                    Text('$day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                    if (dayTransactions.isNotEmpty) Container(margin: const EdgeInsets.only(top: 2), width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedView() {
    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("Giao diện danh sách đang phát triển")));
  }
}