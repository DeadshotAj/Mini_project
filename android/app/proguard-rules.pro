# Keep TensorFlow Lite classes (needed by tflite_flutter, stripped incorrectly by R8)
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep ML Kit face detection classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**