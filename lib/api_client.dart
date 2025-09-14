import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _backendUrl = 'https://webhook.site/18509965-c5e2-4dca-a4ea-12cbc7f5c4b2';
  final bool _debugMode = true;

  Future<bool> sendFrame(Uint8List frameData) async {
    try {
      // Validate frame data
      if (frameData.isEmpty) {
        print('⚠️ Warning: Attempted to send empty frame');
        return false;
      }

      if (_debugMode) {
        print('📤 Sending frame (${frameData.length} bytes) to $_backendUrl');
      }

      // ACTUAL POST REQUEST
      final response = await http.post(
        Uri.parse(_backendUrl),
        body: frameData,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': frameData.length.toString(),
          'X-Frame-Index': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (_debugMode) {
        print('📥 Response: ${response.statusCode} - Body length: ${response.body.length} bytes');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Frame sent successfully - Size: ${frameData.length} bytes');
        return true;
      } else {
        print('❌ Failed to send frame: ${response.statusCode}');
        return false;
      }

    } catch (e) {
      if (_debugMode) {
        print('❌ Network error: $e');
      }
      return false;
    }
  }
}