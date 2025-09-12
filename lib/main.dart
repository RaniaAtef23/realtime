import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera_service.dart';
import 'api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if platform is supported
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        runApp(PlatformErrorApp(error: 'No cameras found on this device'));
      } else {
        runApp(MyApp(cameras: cameras));
      }
    } catch (e) {
      runApp(PlatformErrorApp(error: 'Camera initialization failed: $e'));
    }
  } else {
    runApp(PlatformErrorApp(
      error: 'Camera is only supported on Android and iOS devices',
    ));
  }
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final CameraService _cameraService = CameraService();
  final ApiClient _apiClient = ApiClient();
  bool _isSending = false;
  bool _isCameraInitialized = false;
  int _framesSent = 0;
  String _errorMessage = '';
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera(widget.cameras);
      setState(() {
        _isCameraInitialized = true;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error initializing camera: $e";
      });
      print("Error initializing camera: $e");
    }
  }

  void _toggleSending() {
    if (_isSending) {
      _cameraService.stopSendingFrames().then((framesSent) {
        setState(() {
          _isSending = false;
          _framesSent = framesSent;
        });

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Successfully sent $framesSent frames to backend!'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      });
    } else {
      setState(() {
        _isSending = true;
        _framesSent = 0;
      });
      _cameraService.startSendingFrames(_apiClient);

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Started sending frames to backend...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Video to AI Service'),
            backgroundColor: Colors.blue,
          ),
          body: _errorMessage.isNotEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                _errorMessage,
                style: TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          )
              : _isCameraInitialized && _cameraService.controller.value.isInitialized
              ? Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _cameraService.controller.value.aspectRatio,
                      child: CameraPreview(_cameraService.controller),
                    ),
                  ),
                ),
              ),
              if (_isSending)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Sending frames to backend...',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
              if (_framesSent > 0 && !_isSending)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Successfully sent $_framesSent frames!',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
            ],
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Initializing camera...'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _isCameraInitialized ? _toggleSending : null,
            backgroundColor: _isSending ? Colors.red : Colors.green,
            child: Icon(_isSending ? Icons.stop : Icons.play_arrow),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}

class PlatformErrorApp extends StatelessWidget {
  final String error;

  const PlatformErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              error,
              style: TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}