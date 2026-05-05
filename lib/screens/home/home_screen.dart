import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/photo_model.dart';
import '../../widgets/app_toast.dart';
import '../auth/login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Photo> photos = [];
  bool isSelectionMode = false;
  List<int> selectedIds = [];
  int page = 1;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isFetching = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPhotos(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (isFetching || !hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      setState(() => page++);
      _fetchPhotos(page);
    }
  }

  Future<void> _fetchPhotos(int pageNum) async {
    if (isFetching) return;
    setState(() {
      isFetching = true;
      isLoadingMore = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/my-photos/?page=$pageNum'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'];
        final List<Photo> newPhotos = results.map((json) => Photo.fromJson(json)).toList();

        setState(() {
          if (pageNum == 1) {
            photos = newPhotos;
          } else {
            final existingIds = photos.map((p) => p.id).toSet();
            final uniqueNewPhotos = newPhotos.where((p) => !existingIds.contains(p.id)).toList();
            photos.addAll(uniqueNewPhotos);
          }
          hasMore = data['has_next'] ?? false;
        });
      } else if (pageNum == 1 && response.statusCode == 401) {
        await prefs.remove('access_token');
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        }
      }
    } catch (e) {
      AppToast.error(context, 'Lỗi kết nối máy chủ!');
    } finally {
      setState(() {
        isLoadingMore = false;
        isFetching = false;
      });
    }
  }

  void _handlePhotoClick(Photo photo) {
    if (isSelectionMode) {
      setState(() {
        if (selectedIds.contains(photo.id)) {
          selectedIds.remove(photo.id);
          if (selectedIds.isEmpty) isSelectionMode = false;
        } else {
          selectedIds.add(photo.id);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoDetailScreen(photo: photo, onDelete: _handleDeleteSingle),
        ),
      );
    }
  }

  Future<void> _handleDeleteSingle(int id) async {
    await _deletePhotos([id]);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deletePhotos(List<int> idsToDelete) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      final response = await http.post(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/delete-multiple/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'photo_ids': idsToDelete}),
      );

      if (response.statusCode == 200) {
        setState(() {
          page = 1;
          isSelectionMode = false;
          selectedIds.clear();
        });
        _fetchPhotos(1);
      }
    } catch (e) {
      AppToast.error(context, 'Lỗi khi xóa ảnh!');
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (selectedIds.length == photos.length) {
        selectedIds.clear();
      } else {
        selectedIds = photos.map((p) => p.id).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: isSelectionMode ? 1 : 0,
        titleSpacing: 16,
        title: isSelectionMode
            ? Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => setState(() {
                isSelectionMode = false;
                selectedIds.clear();
              }),
            ),
            Text('Đã chọn ${selectedIds.length}', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        )
            : const Text(
          'Moodly',
          style: TextStyle(fontSize: 28, color: Color(0xFF4F46E5), fontFamily: 'cursive', fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isSelectionMode)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                selectedIds.length == photos.length ? 'Bỏ chọn' : 'Chọn tất cả',
                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            )
          else if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                onPressed: () => setState(() => isSelectionMode = true),
                icon: const Icon(Icons.check_box_outlined, size: 18, color: Colors.black87),
                label: const Text('Chọn', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (photos.isEmpty && !isLoadingMore)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                    child: const Icon(Icons.layers_outlined, size: 32, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text('Không gian đang trống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  const Text('Hãy nhấn biểu tượng Tạo (+) bên dưới nhé!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: MasonryGridView.count(
                controller: _scrollController,
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: photos.length + (isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == photos.length) {
                    return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
                  }

                  final photo = photos[index];
                  final isSelected = selectedIds.contains(photo.id);

                  return GestureDetector(
                    onTap: () => _handlePhotoClick(photo),
                    onLongPress: () {
                      if (!isSelectionMode) {
                        setState(() {
                          isSelectionMode = true;
                          selectedIds.add(photo.id);
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: isSelected ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Hero(
                              tag: 'photo-${photo.id}',
                              child: CachedNetworkImage(
                                imageUrl: photo.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey.shade200, height: 150),
                                errorWidget: (context, url, error) => Container(color: Colors.grey.shade200, height: 150, child: const Icon(Icons.error)),
                              ),
                            ),
                          ),
                          if (isSelectionMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                child: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.black, size: 24)
                                    : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (isSelectionMode && selectedIds.isNotEmpty)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black87,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Xác nhận'),
                          content: Text('Bạn có chắc muốn xóa ${selectedIds.length} ảnh này?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deletePhotos(selectedIds);
                              },
                              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Xóa ${selectedIds.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PhotoDetailScreen extends StatelessWidget {
  final Photo photo;
  final Function(int) onDelete;

  const PhotoDetailScreen({super.key, required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(photo.imageUrl),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Xác nhận'),
                  content: const Text('Bạn có chắc muốn xóa ảnh này?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete(photo.id);
                      },
                      child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'photo-${photo.id}',
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: photo.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}