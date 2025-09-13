import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_client.dart';

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
          "mandatory": {
            "minWidth": '640',
            "minHeight": '480',
            "minFrameRate": '30',
          },
          "facingMode": "user",
          "optional": []
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localStream!.getVideoTracks().isEmpty) {
        throw Exception('No video tracks found in stream');
      }

      localRenderer.srcObject = _localStream;

      // Wait for the video to start
      await Future.delayed(Duration(milliseconds: 500));

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
      if (frame != null) {
        final timestamp = DateTime.now();
        final success = await apiClient.sendFrame(frame);

        if (success) {
          _framesSent++;
          _successfulFrames++;
          _frameLogs.add('✅ ${timestamp.hour}:${timestamp.minute}:${timestamp.second}: Frame $_framesSent sent successfully (${frame.length} bytes)');
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
        _frameLogs.add('❌ ${DateTime.now()}: Failed to capture frame');
      }
    } catch (e) {
      print('Error processing frame: $e');
      _failedFrames++;
      _frameLogs.add('❌ ${DateTime.now()}: Error: $e');
    }
  }

  Future<Uint8List?> _captureFrame() async {
    try {
      // Simulate frame capture with a placeholder
      await Future.delayed(Duration(milliseconds: 10));

      // Create a simple placeholder frame data
      final placeholder = Uint8List.fromList(List.generate(1000, (index) => index % 256));
      return placeholder;

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