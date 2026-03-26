import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';

class ScannerFrontTireScreenNew extends StatefulWidget {
  const ScannerFrontTireScreenNew({super.key});

  @override
  State<ScannerFrontTireScreenNew> createState() => _ScannerFrontTireScreenNewState();
}

class _ScannerFrontTireScreenNewState extends State<ScannerFrontTireScreenNew>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _ready = false;
  XFile? _front;
  XFile? _back;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final c = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await c.initialize();

      // 👇 focus/expose on tire area (a bit lower than center)
      try {
        await c.setFocusPoint(const Offset(0.5, 0.65));
        await c.setZoomLevel(1.4);
      } catch (_) {
        // some devices may not support it — ignore
      }

      if (!mounted) return;
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (!_ready || _controller == null) return;
    try {
      final shot = await _controller!.takePicture();

      // ----- CROP TO OVERLAY AREA -----
      final screen = MediaQuery.of(context).size;
      final bytes = await shot.readAsBytes();
      final original = img.decodeImage(bytes);

      // overlay rect params (must match _ScanPainter)
      const inset = 24.0;
      const headerOffset = 99.0;
      const bottomGap = 225.0;

      XFile finalFile = shot;

      if (original != null) {
        // map screen → image
        final scaleX = original.width / screen.width;
        final scaleY = original.height / screen.height;

        final cropLeft = inset * scaleX;
        final cropTop = (inset + headerOffset) * scaleY;
        final cropWidth = (screen.width - inset * 2) * scaleX;
        final cropHeight =
            (screen.height - inset * 2 - bottomGap) * scaleY;

        final cropped = img.copyCrop(
          original,
          x: cropLeft.round().clamp(0, original.width),
          y: cropTop.round().clamp(0, original.height),
          width: cropWidth.round().clamp(1, original.width),
          height: cropHeight.round().clamp(1, original.height),
        );

        final croppedBytes = img.encodeJpg(cropped, quality: 95);
        final f = await File(shot.path).writeAsBytes(croppedBytes);
        finalFile = XFile(f.path);
      }
      // ----- CROP END -----

      if (_front == null) {
        setState(() => _front = finalFile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Front tire captured. Capture back tire.'),
          ),
        );
      } else {
        setState(() => _back = finalFile);
        _goCountdownAndUpload();
      }
    } catch (_) {
      // ignore for now
    }
  }

  void _goCountdownAndUpload() {
    final auth = context.read<AuthBloc>().state;
    final token = auth.loginResponse?.token ?? '';
    final userId = ''; // fill from your model
    final vehicleId = 'vehicle-001';

    // Navigator.of(context)
    //     .push(
    //   MaterialPageRoute(
    //     builder: (_) => InspectionResultScreen(
    //       frontPath: _front!.path,
    //       backPath: _back!.path,
    //        userId: userId,
    //       vehicleId:vehicleId,
    //        token: token,
    //     ),
    //   ),
    // )
    //     .then((_) {
    //   setState(() {
    //     _front = null;
    //     _back = null;
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // camera
          if (_ready && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // top rounded white header like the mock
          SafeArea(
            child: Container(
              height: 62,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.95),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.black),
                  ),
                  const Spacer(),
                  const Text(
                    'Tire inspection Scanner',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
            ),
          ),

          // overlay corners
          const ScanOverlay(),

          // front / back badges (right)
          Positioned(
            top: 135,
            right: 35,
            child: Column(
              children: [
                _thumbBadge('Front', _front?.path),
                const SizedBox(height: 10),
                _thumbBadge('Back', _back?.path),
              ],
            ),
          ),

          // bottom bar
          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: _ready,
              onPickGallery: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pick from gallery (optional).')),
              ),
              // onPickDocs: () => ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Pick documents (optional).')),
              // ),
              onCapture: _capture,
              // galleryIconAsset: 'assets/gallery_icon.png',
              // captureIconAsset: 'assets/image_capture_icon.png',
            //  docsIconAsset: 'assets/document_icon.png',
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbBadge(String label, String? path) {
    final has = path != null;
    return Container(
      width: 70,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: has ? Colors.green : Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            has ? Icons.check_circle : Icons.radio_button_unchecked,
            color: has ? Colors.white : Colors.black,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: has ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- overlay ---------------- */

class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanPainter(),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final _paint = Paint()
    ..color = const Color(0xFF58A6FF)
    ..strokeWidth = 5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    // same numbers we used in crop
    const inset = 24.0;
    const header = 99.0;
    const bottomGap = 225.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset + header,
        size.width - inset * 2,
        size.height - inset * 2 - bottomGap,
      ),
      const Radius.circular(24),
    );

    const corner = 46.0;

    // TL
    canvas.drawPath(_cornerPath(rect.left, rect.top, true, true, corner), _paint);
    // TR
    canvas.drawPath(_cornerPath(rect.right, rect.top, false, true, corner), _paint);
    // BL
    canvas.drawPath(_cornerPath(rect.left, rect.bottom, true, false, corner), _paint);
    // BR
    canvas.drawPath(_cornerPath(rect.right, rect.bottom, false, false, corner), _paint);
  }

  Path _cornerPath(double x, double y, bool left, bool top, double len) {
    final p = Path();
    final dx = left ? 1 : -1;
    final dy = top ? 1 : -1;
    p.moveTo(x, y + 24 * dy);
    p.quadraticBezierTo(x, y, x + 24 * dx, y);
    p.moveTo(x + len * dx, y);
    p.lineTo(x + 24 * dx, y);
    p.moveTo(x, y + len * dy);
    p.lineTo(x, y + 24 * dy);
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
