import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/transaction_model.dart';
import '../../widgets/app_toast.dart';
import 'new_transaction_screen.dart';
import 'camera_capture_screen.dart';

class DailySpendingScreen extends StatefulWidget {
  final String dateStr;
  const DailySpendingScreen({super.key, required this.dateStr});

  @override
  State<DailySpendingScreen> createState() => _DailySpendingScreenState();
}

class _DailySpendingScreenState extends State<DailySpendingScreen> {
  List<TransactionModel> transactions = [];
  bool isLoading = true;
  String? zoomedImage;

  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _fetchDailyTransactions();
  }

  Future<void> _fetchDailyTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final dateParts = widget.dateStr.split('-');
    final year = dateParts[0];
    final month = dateParts[1];

    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/?month=$month&year=$year'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> listData = data is List ? data : (data['results'] ?? []);

        final allData = listData.map((json) => TransactionModel.fromJson(json)).toList();
        setState(() {
          transactions = allData.where((t) => t.transactionDate.startsWith(widget.dateStr)).toList();
          transactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn xóa khoản chi tiêu này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      final res = await http.delete(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 204 || res.statusCode == 200) {
        setState(() => transactions.removeWhere((t) => t.id == id));
        if (mounted) AppToast.success(context, 'Đã xóa thành công!');
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalExpense = transactions.where((t) => t.transactionType == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = transactions.where((t) => t.transactionType == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final displayDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.dateStr));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiết ngày', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(displayDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)), child: Text('Chi: ${currencyFormat.format(totalExpense)}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade100)), child: Text('Thu: ${currencyFormat.format(totalIncome)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: transactions.isEmpty
                      ? const Center(child: Text('Chưa có chi tiêu nào trong ngày này.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return GestureDetector(
                        onTap: () {
                          if (tx.imageUrl != null) {
                            setState(() => zoomedImage = tx.imageUrl);
                          } else {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => NewTransactionScreen(
                                dateStr: widget.dateStr,
                                editId: tx.id,
                                onSaved: _fetchDailyTransactions,
                              ),
                            ));
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                          child: Row(
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                                child: tx.imageUrl != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: tx.imageUrl!, fit: BoxFit.cover))
                                    : const Icon(Icons.receipt, color: Colors.grey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tx.note.isNotEmpty ? tx.note : 'Không có ghi chú', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(tx.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(tx.source.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('HH:mm').format(
                                            (tx.createdAt != null
                                                    ? DateTime.parse(tx.createdAt!)
                                                    : DateTime.parse(tx.transactionDate))
                                                .toUtc()
                                                .add(const Duration(hours: 7)),
                                          ),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              Text(
                                '${tx.transactionType == 'expense' ? '-' : '+'}${currencyFormat.format(tx.amount)}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tx.transactionType == 'expense' ? Colors.red : Colors.green),
                              ),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _handleDelete(tx.id)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (zoomedImage != null)
            GestureDetector(
              onTap: () => setState(() => zoomedImage = null),
              child: Container(
                color: Colors.black87,
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    InteractiveViewer(child: CachedNetworkImage(imageUrl: zoomedImage!, width: double.infinity, height: double.infinity, fit: BoxFit.contain)),
                    Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => setState(() => zoomedImage = null))),
                  ],
                ),
              ),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CameraCaptureScreen(
                dateStr: widget.dateStr,
                onTransactionSaved: _fetchDailyTransactions,
              ),
            ));
          },
          backgroundColor: const Color(0xFF4F46E5),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}