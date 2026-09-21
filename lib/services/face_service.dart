import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Liveness gestures the app can randomly challenge a student with.
///
/// Chosen for reliability across front cameras:
///  • smile    — smilingProbability, unaffected by orientation
///  • blink    — eye open probabilities, unaffected by mirroring
///  • tiltHead — headEulerAngleZ abs ≥ 20° — either direction, so the
///               front-camera mirror flip doesn't matter
enum LivenessGesture {
  smile,
  blink,
  tiltHead;

  String get instruction {
    switch (this) {
      case LivenessGesture.smile:
        return 'Give a big smile 😊';
      case LivenessGesture.blink:
        return 'Blink both eyes slowly 😑';
      case LivenessGesture.tiltHead:
        return 'Tilt your head to either side ↔';
    }
  }

  String get shortLabel {
    switch (this) {
      case LivenessGesture.smile:
        return 'Smile';
      case LivenessGesture.blink:
        return 'Blink';
      case LivenessGesture.tiltHead:
        return 'Tilt Head';
    }
  }

  static LivenessGesture random() {
    final values = LivenessGesture.values;
    return values[Random().nextInt(values.length)];
  }
}

class FaceService {
  late Interpreter _interpreter;
  bool _modelLoaded = false;

  /// Used for embedding extraction (accurate, no classification needed).
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  /// Used for live gesture detection.
  /// enableClassification provides smilingProbability + eye open probabilities.
  final FaceDetector _gestureDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Future<void> loadModel() async {
    if (_modelLoaded) return;
    _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
    _modelLoaded = true;
  }

  Future<img.Image?> detectAndCropFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) return null;

    final rawBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(rawBytes);
    if (originalImage == null) return null;

    final face = faces.first;
    final rect = face.boundingBox;
    final left = rect.left.clamp(0, originalImage.width).toInt();
    final top = rect.top.clamp(0, originalImage.height).toInt();
    final width = (rect.width).clamp(1, originalImage.width - left).toInt();
    final height = (rect.height).clamp(1, originalImage.height - top).toInt();

    final cropped = img.copyCrop(originalImage, x: left, y: top, width: width, height: height);
    return img.copyResize(cropped, width: 112, height: 112);
  }

  List<double> getEmbedding(img.Image faceImage) {
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = faceImage.getPixel(x, y);
            return [(pixel.r / 127.5) - 1.0, (pixel.g / 127.5) - 1.0, (pixel.b / 127.5) - 1.0];
          },
        ),
      ),
    );
    final output = List.generate(1, (_) => List.filled(192, 0.0));
    _interpreter.run(input, output);
    return output[0];
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Analyses a live camera [InputImage] and returns true if the [gesture]
  /// is currently being performed.
  ///
  /// Thresholds:
  ///  • smile    — smilingProbability ≥ 0.60 (looser than default; MLKit is
  ///               conservative so 0.6 still requires a genuine smile)
  ///  • blink    — BOTH eye open probabilities < 0.25 (deliberate slow blink)
  ///  • tiltLeft — headEulerAngleZ ≥ 20° (tilt/roll axis; + = left ear down,
  ///               which is the same direction regardless of camera mirroring)
  Future<bool> analyzeGesture(InputImage image, LivenessGesture gesture) async {
    final faces = await _gestureDetector.processImage(image);
    if (faces.isEmpty) return false;
    final face = faces.first;

    switch (gesture) {
      case LivenessGesture.smile:
        final prob = face.smilingProbability;
        return prob != null && prob >= 0.60;

      case LivenessGesture.blink:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        // Both eyes must be closed for a genuine blink (not just a squint)
        return left != null && right != null && left < 0.25 && right < 0.25;

      case LivenessGesture.tiltHead:
        // Accept either direction — front cameras mirror the image, making
        // the sign of headEulerAngleZ device-dependent. abs() removes ambiguity.
        final z = face.headEulerAngleZ;
        return z != null && z.abs() >= 20.0;
    }
  }

  void dispose() {
    _faceDetector.close();
    _gestureDetector.close();
    if (_modelLoaded) _interpreter.close();
  }
}