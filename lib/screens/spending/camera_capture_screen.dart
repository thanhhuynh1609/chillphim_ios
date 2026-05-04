import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'new_transaction_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  final String dateStr;
  const CameraCaptureScreen({super.key, required this.dateStr});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTaking = false;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_cameras[_cameraIndex]);
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      // prefer back camera
      final backIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      _cameraIndex = backIndex >= 0 ? backIndex : 0;
      await _startCamera(_cameras[_cameraIndex]);
    } catch (e) {
      // camera unavailable
    }
  }

  Future<void> _startCamera(CameraDescription desc) async {
    final ctrl = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setFlashMode(_flashMode);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  Future<void> _takePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isTaking) return;
    setState(() => _isTaking = true);
    try {
      final XFile file = await ctrl.takePicture();
      if (mounted) _openForm(File(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi chụp ảnh'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitialized = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_cameraIndex]);
  }

  void _toggleFlash() {
    const cycle = [FlashMode.off, FlashMode.torch, FlashMode.auto];
    final next = cycle[(cycle.indexOf(_flashMode) + 1) % cycle.length];
    setState(() => _flashMode = next);
    _controller?.setFlashMode(next);
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (file != null && mounted) _openForm(File(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _skipPhoto() => _openForm(null);

  void _openForm(File? photo) {
    _controller?.dispose();
    _controller = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NewTransactionScreen(
          dateStr: widget.dateStr,
          initialPhoto: photo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _controller?.dispose();
                      Navigator.pop(context);
                    },
                    child: const Text('Hủy',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Camera preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Preview or loading
                      if (_isInitialized && _controller != null)
                        CameraPreview(_controller!)
                      else
                        Container(
                          color: const Color(0xFF0A0A0C),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white54),
                          ),
                        ),

                      // Flash toggle (top-left)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: _toggleFlash,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.black45, shape: BoxShape.circle),
                            child: Icon(_flashIcon(), color: Colors.white, size: 22),
                          ),
                        ),
                      ),

                      // Flip camera (top-right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _flipCamera,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.flip_camera_ios_outlined,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                children: [
                  // Shutter button
                  GestureDetector(
                    onTap: _isTaking ? null : _takePhoto,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: _isTaking
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const SizedBox(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Gallery
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Chọn từ thư viện',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Skip
                  TextButton(
                    onPressed: _skipPhoto,
                    child: const Text('Bỏ qua ảnh',
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      default:
        return Icons.flash_off;
    }
  }
}
