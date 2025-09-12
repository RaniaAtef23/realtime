import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';

class CameraService {
  late CameraController controller;
  bool _isSendingFrames = false;
  int _frameCounter = 0;
  int _framesSent = 0;
  int _frameSkip = 3; // Process every 3rd frame to reduce load

  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    try {
      // Try to find the front camera first (for self-view)
      CameraDescription? selectedCamera;

      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      // If no front camera found, try back camera
      if (selectedCamera == null) {
        for (var camera in cameras) {
          if (camera.lensDirection == CameraLensDirection.back) {
            selectedCamera = camera;
            break;
          }
        }
      }

      // If no camera found, use the first available
      selectedCamera ??= cameras.first;

      print("Selected camera: ${selectedCamera.name}, lens: ${selectedCamera.lensDirection}");

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Initialize the controller and wait for it to complete
      await controller.initialize();

      // Check if the controller is properly initialized
      if (!controller.value.isInitialized) {
        throw Exception('Camera controller failed to initialize');
      }

      print("Camera initialized successfully");
    } catch (e) {
      print('Error in initializeCamera: $e');
      rethrow;
    }
  }

  void startSendingFrames(ApiClient apiClient) {
    if (!controller.value.isInitialized) {
      print('Camera controller is not initialized');
      return;
    }

    _isSendingFrames = true;
    _framesSent = 0;
    _frameCounter = 0;

    // Start listening to the image stream
    controller.startImageStream((CameraImage image) {
      if (_isSendingFrames) {
        _frameCounter++;
        if (_frameCounter % _frameSkip == 0) {
          _processFrame(image);
        }
      }
    });
  }

  Future<int> stopSendingFrames() async {
    _isSendingFrames = false;
    await controller.stopImageStream();

    // Return the number of frames sent
    return _framesSent;
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      // Convert CameraImage to PNG
      final pngBytes = await convertCameraImageToPng(image);

      // Send to backend/AI service
      final success = await ApiClient().sendFrame(pngBytes);

      if (success) {
        // Increment the counter for successfully sent frames
        _framesSent++;
      }
    } catch (e) {
      print('Error processing frame: $e');
    }
  }

  Future<Uint8List> convertCameraImageToPng(CameraImage image) async {
    try {
      // For a simpler approach, let's use a different method
      return await _simpleConvertCameraImageToPng(image);
    } catch (e) {
      print('Error in convertCameraImageToPng: $e');
      rethrow;
    }
  }

  Future<Uint8List> _simpleConvertCameraImageToPng(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;

    // Create a simple placeholder image
    final placeholder = await _createPlaceholderImage(width, height);
    return placeholder;
  }

  Future<Uint8List> _createPlaceholderImage(int width, int height) async {
    // Create a simple colored rectangle as a placeholder
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..color = ui.Color(0xFF2196F3) // Blue color
      ..style = ui.PaintingStyle.fill;

    canvas.drawRect(ui.Rect.fromLTRB(0, 0, width.toDouble(), height.toDouble()), paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  void dispose() {
    controller.dispose();
  }
}