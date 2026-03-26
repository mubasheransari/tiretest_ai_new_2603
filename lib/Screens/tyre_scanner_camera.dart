import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TyreScannerCameraScreen extends StatefulWidget {
  final String title;
  final String hint;

  const TyreScannerCameraScreen({
    super.key,
    required this.title,
    required this.hint,
  });

  @override
  State<TyreScannerCameraScreen> createState() => _TyreScannerCameraScreenState();
}

class _TyreScannerCameraScreenState extends State<TyreScannerCameraScreen> {
  CameraController? _controller;
  bool _loading = true;
  bool _capturing = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final c = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await c.initialize();

      if (!mounted) return;
      setState(() {
        _controller = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = "Camera init failed: $e";
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_capturing) return;

    setState(() => _capturing = true);

    try {
      final file = await _controller!.takePicture();

      // Save into app documents (stable path)
      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(
        dir.path,
        "tyre_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      await File(file.path).copy(outPath);

      if (!mounted) return;
      Navigator.pop(context, outPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _err = "Capture failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_err != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_err!, style: const TextStyle(color: Colors.white)),
          ),
        ),
      );
    }

    final c = _controller!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ Camera preview
          Positioned.fill(
            child: CameraPreview(c),
          ),

          // ✅ Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ Scanner overlay + hint
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: _ScannerOverlayPainter(),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.78,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                    ),
                    child: Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ Capture button
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_capturing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                        color: Colors.white.withOpacity(.15),
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// dark outside with a rounded rectangle “scan area”
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(.55);
    final scanW = size.width * 0.82;
    final scanH = size.height * 0.50;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanW,
      height: scanH,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(rrect);

    final overlay = Path.combine(PathOperation.difference, path, hole);
    canvas.drawPath(overlay, paint);

    // border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withOpacity(.75);
    canvas.drawRRect(rrect, border);

    // subtle guide line
    final linePaint = Paint()
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(.18);
    canvas.drawLine(
      Offset(rect.left + 20, rect.center.dy),
      Offset(rect.right - 20, rect.center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
