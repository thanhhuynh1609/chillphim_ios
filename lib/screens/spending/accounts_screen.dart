import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  double walletBalance = 0;
  double bankBalance = 0;
  bool isLoading = true;

  bool isModalOpen = false;
  String editingSource = 'wallet';
  final _balanceController = TextEditingController();
  bool isSubmitting = false;

  bool isTransferModalOpen = false;
  String transferDirection = 'bank_to_wallet';
  final _transferAmountController = TextEditingController();
  bool isTransferring = false;

  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
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
        final transactions = data is List ? data : (data['results'] ?? []);

        double wallet = 0;
        double bank = 0;

        for (var t in transactions) {
          double amount = (t['amount'] as num).toDouble();
          if (t['source'] == 'wallet') {
            t['transaction_type'] == 'income' ? wallet += amount : wallet -= amount;
          } else if (t['source'] == 'bank') {
            t['transaction_type'] == 'income' ? bank += amount : bank -= amount;
          }
        }

        setState(() {
          walletBalance = wallet;
          bankBalance = bank;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _openEditModal(String source) {
    setState(() {
      editingSource = source;
      _balanceController.text = (source == 'wallet' ? walletBalance : bankBalance).toInt().toString();
      isModalOpen = true;
    });
  }

  Future<void> _handleSaveBalance() async {
    if (_balanceController.text.isEmpty) return;

    final targetBalance = double.tryParse(_balanceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final currentBalance = editingSource == 'wallet' ? walletBalance : bankBalance;
    final difference = targetBalance - currentBalance;

    if (difference == 0) {
      setState(() => isModalOpen = false);
      return;
    }

    setState(() => isSubmitting = true);
    final token = (await SharedPreferences.getInstance()).getString('access_token');

    final type = difference > 0 ? 'income' : 'expense';
    final amount = difference.abs();

    try {
      final res = await http.post(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'transaction_type': type,
          'source': editingSource,
          'category': 'Điều chỉnh số dư',
          'note': 'Thiết lập số dư thực tế',
          'transaction_date': '2000-01-01T12:00:00Z'
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
        _fetchBalances();
        setState(() => isModalOpen = false);
      }
    } catch (e) {} finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> _handleTransferSubmit() async {
    final amount = double.tryParse(_transferAmountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;

    final sourceAcc = transferDirection == 'bank_to_wallet' ? 'bank' : 'wallet';
    final destAcc = transferDirection == 'bank_to_wallet' ? 'wallet' : 'bank';
    final currentSourceBalance = sourceAcc == 'bank' ? bankBalance : walletBalance;

    if (amount > currentSourceBalance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số dư nguồn không đủ!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => isTransferring = true);
    final token = (await SharedPreferences.getInstance()).getString('access_token');

    Future<http.Response> createTx(String type, String source, String note) {
      return http.post(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/transactions/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'transaction_type': type,
          'source': source,
          'category': 'Chuyển tiền nội bộ',
          'note': note,
          'transaction_date': DateTime.now().toIso8601String()
        }),
      );
    }

    try {
      final res1 = await createTx('expense', sourceAcc, 'Chuyển sang ${destAcc == 'wallet' ? 'Tiền mặt' : 'Ngân hàng'}');
      final res2 = await createTx('income', destAcc, 'Nhận từ ${sourceAcc == 'wallet' ? 'Tiền mặt' : 'Ngân hàng'}');

      if (res1.statusCode == 201 && res2.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chuyển tiền thành công!'), backgroundColor: Colors.green));
        _fetchBalances();
        setState(() {
          isTransferModalOpen = false;
          _transferAmountController.clear();
        });
      }
    } catch (e) {} finally {
      setState(() => isTransferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 10),
                  const Text('Tài Khoản', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const Text('Quản lý nguồn tiền và thiết lập số dư', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 10))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng tài sản hiện có', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        isLoading
                            ? const SizedBox(height: 40, child: CircularProgressIndicator(color: Colors.white))
                            : Text('${currencyFormat.format(walletBalance + bankBalance)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('Danh sách nguồn tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => _openEditModal('bank'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.account_balance, color: Colors.blue.shade600)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ngân hàng (Bank)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Thẻ ATM / Chuyển khoản', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currencyFormat.format(bankBalance), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              const Text('CHỈNH SỬA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _openEditModal('wallet'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(Icons.account_balance_wallet, color: Colors.green.shade600)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tiền mặt (Wallet)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Tiền lẻ trong ví', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currencyFormat.format(walletBalance), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              const Text('CHỈNH SỬA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => isTransferModalOpen = true),
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFF4F46E5)),
                      label: const Text('Chuyển tiền nội bộ', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.3))),
                    ),
                  )
                ],
              ),
            ),

            if (isModalOpen) _buildEditBalanceModal(),
            if (isTransferModalOpen) _buildTransferModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditBalanceModal() {
    return Container(
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
                  Row(
                    children: [
                      Icon(editingSource == 'bank' ? Icons.account_balance : Icons.account_balance_wallet, color: editingSource == 'bank' ? Colors.blue : Colors.green),
                      const SizedBox(width: 8),
                      const Text('Thiết lập số dư', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => isModalOpen = false)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  suffixText: 'đ',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _handleSaveBalance,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Lưu số dư', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferModal() {
    return Container(
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
                  const Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Color(0xFF4F46E5)),
                      SizedBox(width: 8),
                      Text('Chuyển tiền', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => isTransferModalOpen = false)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Expanded(child: Column(children: [Icon(transferDirection == 'bank_to_wallet' ? Icons.account_balance : Icons.account_balance_wallet, color: transferDirection == 'bank_to_wallet' ? Colors.blue : Colors.green), Text(transferDirection == 'bank_to_wallet' ? 'Từ Ngân hàng' : 'Đến Ngân hàng', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])),
                    IconButton(icon: const Icon(Icons.compare_arrows), onPressed: () => setState(() => transferDirection = transferDirection == 'bank_to_wallet' ? 'wallet_to_bank' : 'bank_to_wallet')),
                    Expanded(child: Column(children: [Icon(transferDirection == 'wallet_to_bank' ? Icons.account_balance_wallet : Icons.account_balance, color: transferDirection == 'wallet_to_bank' ? Colors.green : Colors.blue), Text(transferDirection == 'wallet_to_bank' ? 'Từ Tiền mặt' : 'Đến Tiền mặt', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), suffixText: 'đ'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: isTransferring ? null : _handleTransferSubmit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: isTransferring ? const CircularProgressIndicator(color: Colors.white) : const Text('Xác nhận chuyển', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}