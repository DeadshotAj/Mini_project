# Keep only the TFLite entry-points needed by tflite_flutter
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.InterpreterApi { *; }
-keep class org.tensorflow.lite.InterpreterFactory { *; }
-keep class org.tensorflow.lite.NativeInterpreterWrapper { *; }
-keep class org.tensorflow.lite.TensorFlowLite { *; }
-keep class org.tensorflow.lite.Tensor { *; }
-dontwarn org.tensorflow.lite.**

# Keep only the ML Kit face detection entry-points used by google_mlkit_face_detection
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-dontwarn com.google.mlkit.**