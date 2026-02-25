import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'haptics/haptics_controller.dart';

/// A single drawn stroke consisting of a sequence of [Offset] points.
class _Stroke {
  _Stroke({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;
  final List<Offset> points = [];
}

/// A full-screen drawing canvas that supports stylus/touch input.
///
/// On Windows, moving a pen stylus triggers haptic feedback through the
/// [HapticsController], giving the Surface Slim Pen a friction sensation
/// just like writing with ink on paper.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;

  /// Active haptics controller (platform-specific).
  HapticsController? _hapticsController;

  // Customisable pen settings.
  Color _penColor = Colors.black;
  double _penWidth = 3.0;

  @override
  void initState() {
    super.initState();
    _initHaptics();
  }

  Future<void> _initHaptics() async {
    final controller = HapticsController.create();
    await controller.initialize();
    if (mounted) {
      _hapticsController = controller;
    }
  }

  @override
  void dispose() {
    _hapticsController?.dispose();
    super.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Remove all strokes from the canvas.
  void clearCanvas() => setState(() => _strokes.clear());

  // ── Pointer event handlers ────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    final stroke = _Stroke(color: _penColor, strokeWidth: _penWidth)
      ..points.add(event.localPosition);
    setState(() {
      _currentStroke = stroke;
      _strokes.add(stroke);
    });

    // Start haptic feedback when the stylus touches the canvas.
    if (_isStylusEvent(event)) {
      _hapticsController?.startDrawingFeedback(
        pointerId: event.pointer,
        intensity: _pressureToIntensity(event.pressure),
      );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_currentStroke == null) return;
    setState(() => _currentStroke!.points.add(event.localPosition));

    // Update haptic intensity with stylus pressure while drawing.
    if (_isStylusEvent(event)) {
      _hapticsController?.updateIntensity(
        _pressureToIntensity(event.pressure),
      );
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _currentStroke = null;
    if (_isStylusEvent(event)) {
      _hapticsController?.stopFeedback();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _currentStroke = null;
    _hapticsController?.stopFeedback();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isStylusEvent(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus;

  /// Converts pressure [0.0, 1.0] to haptic intensity, clamped to [0.1, 1.0].
  static double _pressureToIntensity(double pressure) =>
      pressure.clamp(0.1, 1.0);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: CustomPaint(
            painter: _StrokePainter(_strokes),
            child: const SizedBox.expand(),
          ),
        ),
        // Toolbar for pen settings.
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: _PenToolbar(
            currentColor: _penColor,
            currentWidth: _penWidth,
            onColorChanged: (c) => setState(() => _penColor = c),
            onWidthChanged: (w) => setState(() => _penWidth = w),
          ),
        ),
      ],
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}

// ── Pen toolbar ────────────────────────────────────────────────────────────

class _PenToolbar extends StatelessWidget {
  const _PenToolbar({
    required this.currentColor,
    required this.currentWidth,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  final Color currentColor;
  final double currentWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  static const _colors = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in _colors)
                GestureDetector(
                  onTap: () => onColorChanged(color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: currentColor == color
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              const Icon(Icons.brush, size: 18),
              SizedBox(
                width: 100,
                child: Slider(
                  value: currentWidth,
                  min: 1,
                  max: 20,
                  onChanged: onWidthChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
