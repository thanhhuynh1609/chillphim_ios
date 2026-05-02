import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  bool isUserTab = true;
  List<dynamic> userMusic = [];
  bool isUploading = false;
  File? selectedFile;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? currentlyPlayingId;
  bool isPlaying = false;

  final List<Map<String, dynamic>> backgroundSounds = [
    {"id": "bg-4", "title": "Mưa trên bãi biển", "audio_url": "https://res.cloudinary.com/dn1viczd1/video/upload/v1777125936/moodly_music/c5nc64ypy7j2m5iiuqb5.mp3"},
    {"id": "bg-5", "title": "Mưa & Sấm Chớp", "audio_url": "https://res.cloudinary.com/dn1viczd1/video/upload/v1777125981/moodly_music/nvmufajwyr7golslqrei.mp3"},
    {"id": "bg-6", "title": "Mưa Nhẹ", "audio_url": "https://res.cloudinary.com/dn1viczd1/video/upload/v1777125994/moodly_music/nmaygf1umcaalcmshkjg.mp3"},
  ];

  @override
  void initState() {
    super.initState();
    _fetchMusicList();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchMusicList() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/music/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => userMusic = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {}
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() => selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _handleUpload() async {
    if (selectedFile == null) return;
    setState(() => isUploading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/music/'));
      request.headers.addAll({'Authorization': 'Bearer $token'});

      String rawFilename = selectedFile!.path.split(Platform.isWindows ? '\\' : '/').last;
      String title = rawFilename.split('.').first;

      request.fields['title'] = title;
      request.files.add(await http.MultipartFile.fromPath('audio', selectedFile!.path));

      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải nhạc lên thành công!'), backgroundColor: Colors.green));
        setState(() => selectedFile = null);
        _fetchMusicList();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi lưu nhạc'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối'), backgroundColor: Colors.red));
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _handlePlay(String id, String url) async {
    if (currentlyPlayingId == id) {
      if (isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => currentlyPlayingId = id);
    }
  }

  Future<void> _handleDelete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final res = await http.delete(
        Uri.parse('https://moodly-backend-6fk0.onrender.com/api/photos/music/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({"id": id}),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        if (currentlyPlayingId == id.toString()) {
          await _audioPlayer.stop();
          setState(() => currentlyPlayingId = null);
        }
        _fetchMusicList();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> currentList = isUserTab ? userMusic : backgroundSounds;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Moodly Playlist', style: GoogleFonts.dancingScript(fontSize: 32, color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isUserTab = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: isUserTab ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('Nhạc của bạn', style: TextStyle(fontWeight: FontWeight.bold, color: isUserTab ? const Color(0xFF4F46E5) : Colors.grey.shade600)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isUserTab = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: !isUserTab ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('Âm thanh nền', style: TextStyle(fontWeight: FontWeight.bold, color: !isUserTab ? Colors.blue : Colors.grey.shade600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isUserTab) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3), style: BorderStyle.solid, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile != null ? selectedFile!.path.split(Platform.isWindows ? '\\' : '/').last : 'Thêm bài hát mới (.mp3)',
                                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (selectedFile == null || isUploading) ? null : _handleUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
                child: currentList.isEmpty
                    ? const Center(child: Text('Playlist đang trống', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                  itemCount: currentList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final song = currentList[index];
                    final songId = song['id'].toString();
                    final isActive = currentlyPlayingId == songId;
                    final themeColor = isUserTab ? const Color(0xFF4F46E5) : Colors.blue;

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isActive ? themeColor.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _handlePlay(songId, song['audio_url']),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: isActive ? themeColor : Colors.grey.shade100, shape: BoxShape.circle),
                              child: Icon(isActive && isPlaying ? Icons.pause : Icons.play_arrow, color: isActive ? Colors.white : themeColor),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(song['title'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? themeColor : Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
                          if (isUserTab)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Xác nhận'),
                                    content: const Text('Xóa bài hát này khỏi Playlist?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _handleDelete(song['id']);
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
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}