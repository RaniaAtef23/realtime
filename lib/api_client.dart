import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _backendUrl = 'https://your-backend.com/process-frame';
  final bool _debugMode = true;

  Future<bool> sendFrame(Uint8List frameData) async {
    try {
      if (_debugMode) {
        print('📤 Sending frame (${frameData.length} bytes) to $_backendUrl');
        // Simulate network delay for testing
        await Future.delayed(Duration(milliseconds: 50));
        print('✅ Frame sent successfully (simulated)');
        return true;
      }

      // Real implementation (uncomment when backend is ready)
      /*
      final response = await http.post(
        Uri.parse(_backendUrl),
        body: frameData,
        headers: {'Content-Type': 'image/png'},
      );

      if (_debugMode) {
        print('📥 Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        print('✅ Frame sent successfully - Size: ${frameData.length} bytes');
        return true;
      } else {
        print('❌ Failed to send frame: ${response.statusCode}');
        return false;
      }
      */

      // Default return for the commented-out real implementation
      return false;

    } catch (e) {
      if (_debugMode) {
        print('❌ Network error: $e');
      }
      return false;
    }
  }
}

// Mock API client for testing
class MockApiClient extends ApiClient {
  @override
  Future<bool> sendFrame(Uint8List frameData) async {
    await Future.delayed(Duration(milliseconds: 50));
    print('Mock: Frame sent (${frameData.length} bytes)');

    // Simulate occasional failures for testing
    if (DateTime.now().millisecond % 10 == 0) {
      print('Mock: Frame failed (simulated network error)');
      return false;
    }

    return true;
  }
}