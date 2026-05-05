import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_toast.dart';
import 'camera_capture_screen.dart';

class NewTransactionScreen extends StatefulWidget {
  final String dateStr;
  final int? editId;
  final File? initialPhoto;
  final VoidCallback? onSaved;
  const NewTransactionScreen(
      {super.key, required this.dateStr, this.editId, this.initialPhoto, this.onSaved});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();

  String _expr = '';
  String _type = 'expense';
  String _source = 'wallet';
  String _category = 'Ăn uống';
  bool _isSubmitting = false;
  bool _showNumpad = false;
  late DateTime _selectedDate;

  late AnimationController _numpadAnim;
  late Animation<Offset> _numpadSlide;

  static const _bg = Color(0xFF0F0F13);
  static const _primary = Color(0xFF4F46E5);
  static const _red = Color(0xFFE57373);
  static const _green = Color(0xFF81C784);

  final List<String> _categories = [
    'Ăn uống', 'Mua sắm', 'Di chuyển', 'Sức khỏe', 'Khác'
  ];
  final Map<String, String> _catIcons = {
    'Ăn uống': '🍜',
    'Mua sắm': '🛒',
    'Di chuyển': '🚗',
    'Sức khỏe': '💊',
    'Khác': '💼',
  };

  bool get _isExpense => _type == 'expense';
  Color get _amountColor => _isExpense ? _red : _green;

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ăn uống': return Icons.shopping_cart_outlined;
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Di chuyển': return Icons.directions_car_outlined;
      case 'Sức khỏe': return Icons.favorite_border;
      default: return Icons.category_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.tryParse(widget.dateStr) ?? DateTime.now();
    _imageFile = widget.initialPhoto;

    _numpadAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _numpadSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _numpadAnim, curve: Curves.easeOutCubic));

    _noteFocusNode.addListener(() {
      if (_noteFocusNode.hasFocus && _showNumpad) {
        _hideNumpad();
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    _numpadAnim.dispose();
    super.dispose();
  }

  // ─── Numpad keyboard control ──────────────────────────────────────
  void _openNumpad() {
    FocusScope.of(context).unfocus();
    if (!_showNumpad) {
      setState(() => _showNumpad = true);
      _numpadAnim.forward();
    }
  }

  void _hideNumpad() {
    _numpadAnim.reverse().then((_) {
      if (mounted) setState(() => _showNumpad = false);
    });
  }

  void _dismissAll() {
    if (_noteFocusNode.hasFocus) _noteFocusNode.unfocus();
    if (_showNumpad) _hideNumpad();
  }

  // ─── Expression evaluator ─────────────────────────────────────────
  double _evaluate(String expr) {
    if (expr.isEmpty) return 0;
    for (int i = expr.length - 1; i > 0; i--) {
      final ch = expr[i];
      if (ch == '+' || ch == '-') {
        final l = _evaluate(expr.substring(0, i));
        final r = double.tryParse(expr.substring(i + 1)) ?? 0;
        return ch == '+' ? l + r : l - r;
      }
    }
    for (int i = expr.length - 1; i > 0; i--) {
      final ch = expr[i];
      if (ch == '×' || ch == '÷') {
        final l = _evaluate(expr.substring(0, i));
        final r = double.tryParse(expr.substring(i + 1)) ?? 0;
        return ch == '×' ? l * r : (r == 0 ? l : l / r);
      }
    }
    return double.tryParse(expr) ?? 0;
  }

  bool _hasOp(String e) =>
      e.contains('+') || e.contains('-') || e.contains('×') || e.contains('÷');

  String get _displayAmount {
    if (_expr.isEmpty) return '0';
    if (_hasOp(_expr)) return _expr;
    final v = double.tryParse(_expr);
    return v == null ? _expr : NumberFormat('#,##0', 'vi_VN').format(v.toInt());
  }

  void _onNumpad(String key) {
    setState(() {
      const ops = ['+', '-', '×', '÷'];
      switch (key) {
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        case 'C':
          _expr = '';
        case 'OK':
          if (_hasOp(_expr)) {
            final v = _evaluate(_expr);
            _expr = v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(0);
          } else {
            _hideNumpad();
            _handleSubmit();
          }
        case '000':
          if (_expr.isNotEmpty && !ops.contains(_expr[_expr.length - 1])) {
            _expr += '000';
          }
        default:
          if (ops.contains(key)) {
            if (_expr.isNotEmpty && !ops.contains(_expr[_expr.length - 1])) {
              _expr += key;
            }
          } else {
            _expr += key;
          }
      }
    });
  }

  // ─── Image picker ─────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? f = await _picker.pickImage(source: source, imageQuality: 75);
      if (f != null && mounted) setState(() => _imageFile = File(f.path));
    } catch (e) {
      if (mounted) AppToast.error(context, 'Lỗi: $e');
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    final amount = _evaluate(_expr);
    if (amount <= 0) {
      AppToast.warning(context, 'Vui lòng nhập số tiền!');
      _openNumpad();
      return;
    }
    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final apiUrl = widget.editId != null
        ? 'https://moodly-backend-6fk0.onrender.com/api/photos/transactions/${widget.editId}/'
        : 'https://moodly-backend-6fk0.onrender.com/api/photos/transactions/';

    final req = http.MultipartRequest(
        widget.editId != null ? 'PUT' : 'POST', Uri.parse(apiUrl));
    req.headers.addAll({'Authorization': 'Bearer $token'});
    req.fields['amount'] = amount.toInt().toString();
    req.fields['transaction_type'] = _type;
    req.fields['source'] = _source;
    req.fields['category'] = _category;
    req.fields['note'] = _noteController.text;

    if (widget.editId == null) {
      final utcNow = DateTime.now().toUtc();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final t = '${utcNow.hour.toString().padLeft(2, '0')}:'
          '${utcNow.minute.toString().padLeft(2, '0')}:'
          '${utcNow.second.toString().padLeft(2, '0')}';
      req.fields['transaction_date'] = '${dateStr}T${t}Z';
    }

    if (_imageFile != null) {
      req.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
    }

    try {
      final res = await req.send();
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        AppToast.success(context, 'Đã lưu thành công!');
        widget.onSaved?.call();
        Navigator.pop(context);
      } else {
        if (mounted) AppToast.error(context, 'Lỗi khi lưu!');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Lỗi kết nối');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissAll,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildPhotoArea()),
                  _buildBottomControls(),
                ],
              ),
              if (_showNumpad)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: SlideTransition(
                    position: _numpadSlide,
                    child: _buildNumpad(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Photo area ───────────────────────────────────────────────────
  Widget _buildPhotoArea() {
    final overlayColor = _isExpense
        ? const Color(0xFFE57373).withOpacity(0.15)
        : const Color(0xFF81C784).withOpacity(0.15);
    final overlayBorder = _isExpense
        ? const Color(0xFFE57373).withOpacity(0.3)
        : const Color(0xFF81C784).withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: const Color(0xFF121214),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _imageFile != null
              ? Image.file(_imageFile!, fit: BoxFit.cover)
              : const Center(
                  child: Icon(Icons.photo_camera,
                      color: Color(0xFF2A2A2F), size: 56),
                ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),

          // Cancel button
          Positioned(
            top: 24, left: 16,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              child: const Text('Hủy',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w400)),
            ),
          ),

          // Gallery button
          Positioned(
            top: 24, right: 16,
            child: Row(children: [
              _iconBtn(Icons.photo_library_outlined,
                  () => _pickImage(ImageSource.gallery)),
              if (_imageFile != null) ...[
                const SizedBox(width: 8),
                _iconBtn(Icons.close,
                    () => setState(() => _imageFile = null)),
              ],
            ]),
          ),

          // Amount + note card
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: GestureDetector(
              onTap: _openNumpad,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                decoration: BoxDecoration(
                  color: overlayColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: overlayBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Amount row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _isExpense ? '−' : '+',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: _amountColor),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _displayAmount.isEmpty ? '0' : _displayAmount,
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('đ',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Note field — stop tap propagation so it doesn't trigger _openNumpad
                    GestureDetector(
                      onTap: () {
                        if (_showNumpad) _hideNumpad();
                        _noteFocusNode.requestFocus();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _noteController,
                          focusNode: _noteFocusNode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _noteFocusNode.unfocus(),
                          decoration: const InputDecoration(
                            hintText: 'Thêm chi tiết',
                            hintStyle:
                                TextStyle(color: Colors.white38, fontSize: 15),
                            prefixIcon: Icon(Icons.edit_outlined,
                                color: Colors.white38, size: 18),
                            prefixIconConstraints:
                                BoxConstraints(minWidth: 44, minHeight: 32),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  // ─── Bottom controls (no numpad here) ────────────────────────────
  Widget _buildBottomControls() {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      color: _bg,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),

          // Category & Source
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill(
                _getCategoryIcon(_category),
                _category,
                _showCategoryPicker,
                bgColor: const Color(0xFF1B2A1E),
                textColor: Colors.white,
              ),
              const SizedBox(width: 12),
              _pill(
                Icons.account_balance_wallet_outlined,
                _source == 'wallet' ? 'Wallet' : 'Bank',
                () => setState(() =>
                    _source = _source == 'wallet' ? 'bank' : 'wallet'),
                bgColor: const Color(0xFF1B2A1E),
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expense / Income toggle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C21),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggle(Icons.north_east, 'expense'),
                const SizedBox(width: 6),
                _toggle(Icons.south_west, 'income'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Date
          _pill(
            Icons.calendar_today_outlined,
            isToday
                ? 'Hôm nay'
                : DateFormat('dd/MM/yyyy').format(_selectedDate),
            _showDatePicker,
            bgColor: const Color(0xFF1C1C21),
            textColor: Colors.white70,
          ),
          const SizedBox(height: 20),

          // Action buttons: Camera | Save | Share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Chụp lại',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CameraCaptureScreen(dateStr: widget.dateStr),
                      ),
                    );
                  },
                ),
                _saveBtn(),
                _actionBtn(
                  icon: Icons.ios_share,
                  label: 'Share',
                  onTap: () =>
                      AppToast.show(context, 'Tính năng sắp ra mắt'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pill(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color bgColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                color: textColor.withOpacity(0.6), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _toggle(IconData icon, String type) {
    final active = _type == type;
    final activeColor = type == 'expense' ? _red : _green;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: active ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C21),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _saveBtn() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _handleSubmit,
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A30),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: _isSubmitting
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.check, color: Colors.white, size: 30),
      ),
    );
  }

  // ─── Custom numpad ────────────────────────────────────────────────
  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3', '÷'],
      ['4', '5', '6', '×'],
      ['7', '8', '9', '-'],
      ['.', '0', '000', '+'],
      ['⌫', 'C', 'OK'],
    ];

    const numBg = Color(0xFF1E1E24);
    const opBg = Color(0xFF2A1E20);
    const opText = Color(0xFFE57373);

    return GestureDetector(
      onTap: () {}, // absorb taps so _dismissAll doesn't trigger
      child: Container(
        color: const Color(0xFF0F0F13),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...rows.map((row) {
              return SizedBox(
                height: 60,
                child: Row(
                  children: row.map((key) {
                    final isOK = key == 'OK';
                    final isOp = '÷×-+'.contains(key);
                    final isDel = key == '⌫';
                    final isClear = key == 'C';

                    Color bg = numBg;
                    Color fg = Colors.white;

                    if (isOK) {
                      bg = _isSubmitting
                          ? Colors.grey.shade800
                          : const Color(0xFFDE6B6B);
                      fg = Colors.white;
                    } else if (isOp) {
                      bg = opBg;
                      fg = opText;
                    } else if (isClear) {
                      bg = numBg;
                      fg = opText;
                    } else if (isDel) {
                      bg = numBg;
                      fg = Colors.white60;
                    }

                    return Expanded(
                      flex: isOK && row.length == 3 ? 2 : 1,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: GestureDetector(
                          onTap: isOK && _isSubmitting
                              ? null
                              : () => _onNumpad(key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: isDel
                                ? Icon(Icons.backspace_outlined,
                                    color: fg, size: 22)
                                : isOK && _isSubmitting
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                    : Text(
                                        key,
                                        style: TextStyle(
                                          color: fg,
                                          fontSize: isOK ? 20 : 22,
                                          fontWeight: isOp || isOK
                                              ? FontWeight.w500
                                              : FontWeight.w500,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Pickers ──────────────────────────────────────────────────────
  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ..._categories.map((cat) => ListTile(
                  leading: Text(_catIcons[cat] ?? '💼',
                      style: const TextStyle(fontSize: 22)),
                  title: Text(cat,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  trailing: _category == cat
                      ? const Icon(Icons.check_circle, color: _green)
                      : null,
                  onTap: () {
                    setState(() => _category = cat);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }
}
