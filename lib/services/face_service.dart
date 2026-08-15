import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceService {
  late Interpreter _interpreter;
  bool _modelLoaded = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
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

  void dispose() {
    _faceDetector.close();
    if (_modelLoaded) _interpreter.close();
  }
}