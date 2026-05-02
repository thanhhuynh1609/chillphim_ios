class TransactionModel {
  final int id;
  final double amount;
  final String transactionType; // 'expense', 'income', 'transfer'
  final String source; // 'wallet', 'bank'
  final String category;
  final String note;
  final String? imageUrl;
  final String transactionDate;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.source,
    required this.category,
    required this.note,
    this.imageUrl,
    required this.transactionDate,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      transactionType: json['transaction_type'] ?? 'expense',
      source: json['source'] ?? 'wallet',
      category: json['category'] ?? 'Khác',
      note: json['note'] ?? '',
      imageUrl: json['image_url'],
      transactionDate: json['transaction_date'] ?? DateTime.now().toIso8601String(),
    );
  }
}