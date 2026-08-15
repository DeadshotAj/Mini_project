import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/face_service.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});
  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  final FaceService _faceService = FaceService();
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(frontCamera, ResolutionPreset.medium);
    await _controller!.initialize();
    await _faceService.loadModel();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || _isProcessing) return;
    setState(() { _isProcessing = true; _error = null; });
    try {
      final file = await _controller!.takePicture();
      final faceImage = await _faceService.detectAndCropFace(file.path);
      if (faceImage == null) {
        setState(() => _error = 'No face detected. Please try again.');
        return;
      }
      final embedding = _faceService.getEmbedding(faceImage);
      if (!mounted) return;
      Navigator.pop(context, embedding);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Capture')),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: CameraPreview(_controller!)),
                if (_error != null)
                  Padding(padding: const EdgeInsets.all(12.0), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isProcessing
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Face'),
                          onPressed: _captureAndProcess,
                        ),
                ),
              ],
            ),
    );
  }
}