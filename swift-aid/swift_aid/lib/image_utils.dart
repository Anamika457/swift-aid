// lib/image_utils.dart

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img_lib;
import 'package:flutter/foundation.dart';

// --- Isolate Argument Definition ---
// This is the data structure passed to the isolate function.
class IsolateConversionData {
  final CameraImage image;
  final SendPort sendPort;

  IsolateConversionData(this.image, this.sendPort);
}


// --- 1. The Isolate Entry Point ---
// This top-level function runs in a separate Isolate.
// It must be a top-level function or a static method.
void convertImageInIsolate(IsolateConversionData data) async {
  try {
    // Convert YUV to an image object
    final img_lib.Image? convertedImage = _convertYUV420ToImage(data.image);

    if (convertedImage != null) {
      // Encode the image object to JPEG bytes
      final Uint8List jpegBytes = Uint8List.fromList(
        img_lib.encodeJpg(convertedImage, quality: 75)
      );
      
      // Send the JPEG bytes back to the main thread
      data.sendPort.send(jpegBytes);
    } else {
      data.sendPort.send(null);
    }
  } catch (e) {
    // Send error message back
    data.sendPort.send('Error in isolate: $e');
  }
}


// --- 2. YUV420 to RGB/Image Conversion Logic ---
// This is the complex logic required for Android's common camera format.
img_lib.Image? _convertYUV420ToImage(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  
  // Y plane (Grayscale luminance)
  final img_lib.Image newImage = img_lib.Image(width: width, height: height);
  final y = image.planes[0].bytes;
  final u = image.planes[1].bytes;
  final v = image.planes[2].bytes;

  final yRowStride = image.planes[0].bytesPerRow;
  final uRowStride = image.planes[1].bytesPerRow;
  final vRowStride = image.planes[2].bytesPerRow;
  final uPixelStride = image.planes[1].bytesPerPixel ?? 1;
  final vPixelStride = image.planes[2].bytesPerPixel ?? 1;
  
  // YUV420 conversion (slow, but necessary for compatibility)
  for (int j = 0; j < height; j++) {
    for (int i = 0; i < width; i++) {
      final int uvX = (i / 2).floor();
      final int uvY = (j / 2).floor();

      final int yIndex = j * yRowStride + i;
      final int uIndex = uvY * uRowStride + uvX * uPixelStride;
      final int vIndex = uvY * vRowStride + uvX * vPixelStride;
      
      final double Y = y[yIndex] / 255.0;
      final double U = (u[uIndex] - 128) / 255.0;
      final double V = (v[vIndex] - 128) / 255.0;

      // YUV to RGB conversion factors
      int R = ((Y + 1.403 * V) * 255) as int;
      int G = ((Y - 0.344 * U - 0.714 * V) * 255) as int;
      int B = ((Y + 1.770 * U) * 255) as int;

      // Clamp values to [0, 255]
      R = R.clamp(0, 255);
      G = G.clamp(0, 255);
      B = B.clamp(0, 255);

      newImage.setPixelRgb(i, j, R, G, B);
    }
  }
  
  return newImage;
}


// --- 3. Public Isolate Runner ---
// This is the function called from the main thread.
Future<Uint8List?> convertCameraImageToJpeg(CameraImage image) async {
  final receivePort = ReceivePort();
  
  // Spawn a new Isolate to perform the heavy conversion
  await Isolate.spawn(
    convertImageInIsolate,
    IsolateConversionData(image, receivePort.sendPort),
  );

  // Wait for the result from the Isolate
  final response = await receivePort.first;

  if (response is Uint8List) {
    return response;
  } else if (response is String) {
    debugPrint('Isolate Error: $response');
    return null;
  }
  return null;
}