import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart' show TextPainter, TextSpan, TextStyle;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:webrtc/api_client.dart' show ApiClient;

class WebRTCService {
  late RTCVideoRenderer localRenderer;
  MediaStream? _localStream;
  bool _isSendingFrames = false;
  int _frameCounter = 0;
  int _framesSent = 0;
  int _successfulFrames = 0;
  int _failedFrames = 0;
  int _frameSkip = 3; // Process every 3rd frame to reduce load
  Timer? _frameTimer;
  final List<String> _frameLogs = [];

  WebRTCService() {
    localRenderer = RTCVideoRenderer();
  }

  Future<void> initializeCamera() async {
    try {
      await localRenderer.initialize();

      // Get user media with video constraints
      final Map<String, dynamic> constraints = {
        "audio": false,
        "video": {
          "width": {"ideal": 640},
          "height": {"ideal": 480},
          "frameRate": {"ideal": 30},
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localStream!.getVideoTracks().isEmpty) {
        throw Exception('No video tracks found in stream');
      }

      localRenderer.srcObject = _localStream;

      // Wait for the video to start and first frame
      await Future.delayed(Duration(milliseconds: 1000));

      print("WebRTC camera initialized successfully");

    } catch (e) {
      print('Error in initializeCamera: $e');
      rethrow;
    }
  }

  void startSendingFrames(ApiClient apiClient) {
    if (_localStream == null) {
      print('Local stream is not initialized');
      return;
    }

    _isSendingFrames = true;
    _framesSent = 0;
    _successfulFrames = 0;
    _failedFrames = 0;
    _frameCounter = 0;
    _frameLogs.clear();

    // Capture frames at regular intervals
    _frameTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (_isSendingFrames) {
        _frameCounter++;
        if (_frameCounter % _frameSkip == 0) {
          await _captureAndSendFrame(apiClient);
        }
      }
    });
  }

  Future<int> stopSendingFrames() async {
    _isSendingFrames = false;
    _frameTimer?.cancel();
    _frameTimer = null;

    return _framesSent;
  }

  Future<void> _captureAndSendFrame(ApiClient apiClient) async {
    try {
      final frame = await _captureFrame();
      if (frame != null && frame.isNotEmpty) {
        final timestamp = DateTime.now();
        final success = await apiClient.sendFrame(frame);

        if (success) {
          _framesSent++;
          _successfulFrames++;
          _frameLogs.add('✅ ${timestamp.hour}:${timestamp.minute}:${timestamp.second}: Frame $_framesSent sent (${frame.length} bytes)');
        } else {
          _failedFrames++;
          _frameLogs.add('❌ ${timestamp.hour}:${timestamp.minute}:${timestamp.second}: Frame failed to send');
        }

        // Keep log manageable
        if (_frameLogs.length > 20) {
          _frameLogs.removeAt(0);
        }
      } else {
        _failedFrames++;
        _frameLogs.add('❌ ${DateTime.now()}: Failed to capture frame or empty frame');
      }
    } catch (e) {
      print('Error processing frame: $e');
      _failedFrames++;
      _frameLogs.add('❌ ${DateTime.now()}: Error: $e');
    }
  }

  Future<Uint8List?> _captureFrame() async {
    try {
      // Create a proper PNG image as frame data
      final width = 640;
      final height = 480;

      // Create a PNG image with proper header and data
      final completer = Completer<ui.Image>();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw a simple frame with timestamp
      final paint = ui.Paint()
        ..color = Color.fromARGB(255, _frameCounter % 256, (_frameCounter + 85) % 256, (_frameCounter + 170) % 256)
        ..style = ui.PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);

      // Add text with frame info
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Frame #$_frameCounter\n${DateTime.now().toString().substring(11, 19)}',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(20, 20));

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      completer.complete(image);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();

      if (byteData != null) {
        final frameData = byteData.buffer.asUint8List();
        print('Generated frame: ${frameData.length} bytes');
        return frameData;
      }

      return null;

    } catch (e) {
      print('Error capturing frame: $e');
      return null;
    }
  }

  // Getters for monitoring
  int get successfulFrames => _successfulFrames;
  int get failedFrames => _failedFrames;
  List<String> get frameLogs => List.from(_frameLogs);

  void clearFrameLogs() {
    _frameLogs.clear();
  }

  void dispose() {
    _frameTimer?.cancel();
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      localRenderer.srcObject = null;
    }
    localRenderer.dispose();
  }
}