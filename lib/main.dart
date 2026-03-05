import 'package:flutter/material.dart';
import 'drawing_canvas.dart';

void main() {
  runApp(const JustNoteApp());
}

class JustNoteApp extends StatelessWidget {
  const JustNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JustNote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DrawingPage(),
    );
  }
}

/// The main drawing page shell.
class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final _canvasKey = GlobalKey<DrawingCanvasState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JustNote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear canvas',
            onPressed: () => _canvasKey.currentState?.clearCanvas(),
          ),
        ],
      ),
      body: DrawingCanvas(key: _canvasKey),
    );
  }
}
