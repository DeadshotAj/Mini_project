import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_service.dart';
import '../theme/app_theme.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  final FaceService _faceService = FaceService();

  // ── Liveness state ───────────────────────────────────────────────────────
  late LivenessGesture _gesture;

  // Sliding window: tracks hit/miss for the last [_windowSize] processed frames.
  // Gesture passes when [_hitsNeeded] of the last [_windowSize] frames detect
  // the gesture. This is far more robust than strict "N consecutive" counting
  // because a single jitter frame won't reset progress.
  static const int _windowSize = 12;
  static const int _hitsNeeded = 7;
  final List<bool> _window = [];

  static const Duration _timeout = Duration(seconds: 30);

  bool _isStreaming = false;
  bool _isProcessingFrame = false; // guard: only one MLKit call at a time
  bool _isCapturing = false;
  bool _gestureComplete = false;
  String? _error;

  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _gesture = LivenessGesture.random();
    _initCamera();
  }

  // ── Camera init ──────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.low, // lower res = faster MLKit, sufficient for gesture
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21   // NV21 is well-supported by MLKit on Android
          : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();
    await _faceService.loadModel();
    if (!mounted) return;
    setState(() {});
    _startStream();
    _startTimeout();
  }

  // ── Image conversion ─────────────────────────────────────────────────────

  /// Converts a [CameraImage] from the image stream into an [InputImage]
  /// suitable for MLKit, correctly concatenating all YUV planes.
  InputImage? _toInputImage(CameraImage image) {
    final camera = _controller!.description;

    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    // Concatenate ALL planes — on Android (NV21/YUV420) this is essential.
    // Passing only planes[0] (Y channel) gives MLKit an incomplete image.
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21; // safe fallback for Android

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Liveness streaming ───────────────────────────────────────────────────

  void _startStream() {
    if (_isStreaming || _controller == null) return;
    _isStreaming = true;
    _controller!.startImageStream(_onCameraImage);
  }

  void _stopStream() {
    if (!_isStreaming || _controller == null) return;
    _isStreaming = false;
    _controller!.stopImageStream();
  }

  Future<void> _onCameraImage(CameraImage image) async {
    // Skip this frame if: gesture done, capture in progress, or still
    // processing the previous frame. Prevents concurrent MLKit calls.
    if (_gestureComplete || _isCapturing || _isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final detected =
          await _faceService.analyzeGesture(inputImage, _gesture);

      if (!mounted || _gestureComplete || _isCapturing) return;

      // Sliding window: push result, cap at windowSize
      _window.add(detected);
      if (_window.length > _windowSize) _window.removeAt(0);

      final hits = _window.where((v) => v).length;

      if (mounted) setState(() {}); // refresh progress bar

      if (_window.length >= _windowSize && hits >= _hitsNeeded) {
        _onGestureConfirmed();
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _onGestureConfirmed() async {
    if (_gestureComplete || _isCapturing) return;
    setState(() {
      _gestureComplete = true;
      _isCapturing = true;
    });

    _timeoutTimer?.cancel();
    _stopStream();

    try {
      final file = await _controller!.takePicture();
      final faceImage = await _faceService.detectAndCropFace(file.path);

      if (faceImage == null) {
        if (!mounted) return;
        _resetForRetry('No face detected in capture. Please try again.');
        return;
      }

      final embedding = _faceService.getEmbedding(faceImage);
      if (!mounted) return;
      Navigator.pop(context, embedding);
    } catch (_) {
      if (!mounted) return;
      _resetForRetry('Capture failed. Please try again.');
    }
  }

  void _resetForRetry(String errorMsg) {
    setState(() {
      _error = errorMsg;
      _isCapturing = false;
      _gestureComplete = false;
      _window.clear();
    });
    _startStream();
    _startTimeout();
  }

  // ── Timeout ──────────────────────────────────────────────────────────────

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, _onTimeout);
  }

  void _onTimeout() {
    if (!mounted || _gestureComplete) return;
    _stopStream();
    setState(() {
      _error = 'Gesture timed out. Tap below to try again.';
      _window.clear();
      _gestureComplete = false;
    });
  }

  void _retryGesture() {
    setState(() {
      _error = null;
      _window.clear();
      _gestureComplete = false;
      _isCapturing = false;
      _gesture = LivenessGesture.random();
    });
    _startStream();
    _startTimeout();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    if (_isStreaming) _controller?.stopImageStream();
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ready = _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Liveness Check'),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: !ready
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),

                // Dark gradient at bottom
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 240,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),

                // Oval face guide
                Center(
                  child: Container(
                    width: 200,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _gestureComplete
                            ? AppTheme.success
                            : Colors.white.withValues(alpha: 0.7),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(120),
                    ),
                  ),
                ),

                // Bottom panel
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _buildBottomPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomPanel() {
    if (_isCapturing) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text('Capturing…',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off_rounded,
                color: Colors.white54, size: 36),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _retryGesture,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final hits = _window.where((v) => v).length;
    final progress = _window.isEmpty
        ? 0.0
        : (hits / _hitsNeeded).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gesture chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_gestureIcon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _gesture.shortLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _gesture.instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.success),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress > 0.1
                ? 'Hold it…'
                : 'Perform the gesture above to verify you\'re live',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData get _gestureIcon {
    switch (_gesture) {
      case LivenessGesture.smile:
        return Icons.sentiment_very_satisfied_rounded;
      case LivenessGesture.blink:
        return Icons.remove_red_eye_rounded;
      case LivenessGesture.tiltHead:
        return Icons.swap_horiz_rounded;
    }
  }
}
