import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NewTransactionScreen extends StatefulWidget {
  final String dateStr;
  final int? editId;
  const NewTransactionScreen({super.key, required this.dateStr, this.editId});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'expense';
  String _source = 'wallet';
  String _category = 'Ăn uống';
  bool _isSubmitting = false;

  final List<String> _categories = ['Ăn uống', 'Mua sắm', 'Di chuyển', 'Sức khỏe', 'Khác'];

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _handleSubmit() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền!')));
      return;
    }

    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final apiUrl = widget.editId != null
        ? 'https://moodly-backend-6fk0.onrender.com/api/photos/transactions/${widget.editId}/'
        : 'https://moodly-backend-6fk0.onrender.com/api/photos/transactions/';

    var request = http.MultipartRequest(widget.editId != null ? 'PUT' : 'POST', Uri.parse(apiUrl));
    request.headers.addAll({'Authorization': 'Bearer $token'});

    request.fields['amount'] = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    request.fields['transaction_type'] = _type;
    request.fields['source'] = _source;
    request.fields['category'] = _category;
    request.fields['note'] = _noteController.text;

    if (widget.editId == null) {
      request.fields['transaction_date'] = '${widget.dateStr}T12:00:00Z';
    }

    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
    }

    try {
      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thành công!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi lưu dữ liệu'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111113),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Thêm chi tiêu', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(24),
                  image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                ),
                child: _imageFile == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.white54, size: 40), SizedBox(height: 8), Text('Chạm để thêm ảnh bill', style: TextStyle(color: Colors.white54))])
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _type == 'expense' ? Colors.red.shade400 : Colors.green.shade400),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Thêm ghi chú...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildDropdownBtn(_category, () => _showCategoryPicker())),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdownBtn(_source == 'wallet' ? 'Ví (Tiền mặt)' : 'Ngân hàng', () => setState(() => _source = _source == 'wallet' ? 'bank' : 'wallet'))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(onTap: () => setState(() => _type = 'expense'), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _type == 'expense' ? Colors.red.shade400 : Colors.white10, shape: BoxShape.circle), child: const Icon(Icons.arrow_upward, color: Colors.white))),
                const SizedBox(width: 20),
                GestureDetector(onTap: () => setState(() => _type = 'income'), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _type == 'income' ? Colors.green.shade400 : Colors.white10, shape: BoxShape.circle), child: const Icon(Icons.arrow_downward, color: Colors.white))),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Lưu chi tiêu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 4), const Icon(Icons.arrow_drop_down, color: Colors.white54)]),
      ),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Chụp ảnh mới'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Chọn từ thư viện'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map((cat) => ListTile(
            title: Text(cat, style: const TextStyle(color: Colors.white)),
            trailing: _category == cat ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () { setState(() => _category = cat); Navigator.pop(context); },
          )).toList(),
        ),
      ),
    );
  }
}