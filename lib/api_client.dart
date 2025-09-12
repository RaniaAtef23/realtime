import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _backendUrl = 'https://your-backend.com/process-frame';

  Future<bool> sendFrame(Uint8List frameData) async {
    try {
      // For demonstration purposes, we'll simulate network request
      // In a real app, you'd make an actual HTTP request
      await Future.delayed(Duration(milliseconds: 100)); // Simulate network delay

      print('Frame sent successfully (simulated)');
      return true;

      // Uncomment below for actual HTTP request
      /*
      final response = await http.post(
        Uri.parse(_backendUrl),
        body: frameData,
        headers: {'Content-Type': 'image/png'},
      );

      if (response.statusCode == 200) {
        print('Frame sent successfully');
        return true;
      } else {
        print('Failed to send frame: ${response.statusCode}');
        return false;
      }
      */
    } catch (e) {
      print('Error sending frame: $e');
      return false;
    }
  }
}