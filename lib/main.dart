import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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

  // Socket.IO and chat related variables
  late IO.Socket socket;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _showCamera = false;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _initializeCamera();
  }

  void _initializeSocket() {
    // Connect to your Socket.IO server
    socket = IO.io('http://your-socket-server.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.on('connect', (_) {
      setState(() => _isConnected = true);
      print('Connected to server');
    });

    socket.on('disconnect', (_) {
      setState(() => _isConnected = false);
      print('Disconnected from server');
    });

    socket.on('message', (data) {
      // Handle incoming messages
      setState(() {
        _messages.add(ChatMessage(
          text: data['text'],
          isMe: false,
          sender: data['sender'] ?? 'Other',
        ));
      });
    });

    socket.on('error', (error) {
      print('Socket error: $error');
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final message = _messageController.text;
      setState(() {
        _messages.add(ChatMessage(
          text: message,
          isMe: true,
          sender: 'You',
        ));
        _messageController.clear();
      });

      // Send message via Socket.IO
      socket.emit('message', {
        'text': message,
        'sender': 'User',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
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
      });
    } else {
      setState(() {
        _isSending = true;
        _framesSent = 0;
      });
      _cameraService.startSendingFrames(_apiClient);
    }
  }

  void _toggleCameraView() {
    setState(() {
      _showCamera = !_showCamera;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: _showCamera
              ? const Text('Camera View')
              : const Text('Chat & Camera'),
          backgroundColor: _showCamera ? Colors.blue : Colors.green,
          actions: [
            IconButton(
              icon: Icon(_showCamera ? Icons.chat : Icons.camera_alt),
              onPressed: _toggleCameraView,
            ),
          ],
        ),
        body: _showCamera ? _buildCameraView() : _buildChatView(),
      ),
    );
  }

  Widget _buildCameraView() {
    return _errorMessage.isNotEmpty
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FloatingActionButton(
            onPressed: _toggleSending,
            backgroundColor: _isSending ? Colors.red : Colors.green,
            child: Icon(_isSending ? Icons.stop : Icons.play_arrow),
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
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8.0),
            reverse: false,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _messages[index];
            },
          ),
        ),
        Divider(height: 1.0),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: _buildInputField(),
        ),
      ],
    );
  }

  Widget _buildInputField() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration.collapsed(
                hintText: 'Type a message',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    socket.disconnect();
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;

  const ChatMessage({
    Key? key,
    required this.text,
    required this.isMe,
    required this.sender,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isMe
            ? _buildMyMessageLayout(context)
            : _buildOtherMessageLayout(context),
      ),
    );
  }

  List<Widget> _buildMyMessageLayout(BuildContext context) {
    return [
      Expanded(
        child: SizedBox(),
      ),
      Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(sender, style: TextStyle(fontWeight: FontWeight.bold)),
            Material(
              borderRadius: BorderRadius.circular(10.0),
              elevation: 6.0,
              color: Colors.lightBlueAccent,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildOtherMessageLayout(BuildContext context) {
    return [
      Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender, style: TextStyle(fontWeight: FontWeight.bold)),
            Material(
              borderRadius: BorderRadius.circular(10.0),
              elevation: 6.0,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: SizedBox(),
      ),
    ];
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