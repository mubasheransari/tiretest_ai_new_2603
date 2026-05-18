import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart' show BottomActionBar;
import 'package:ios_tiretest_ai/Screens/two_wheeler_report_result_screen.dart';



enum TwoTyrePos { front, frontSidewall, back, backSidewall }

class TwoWheelerGenerateReportScreen extends StatefulWidget {
  final String title;

  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

  const TwoWheelerGenerateReportScreen({
    super.key,
    this.title = "Bike Tyre Scanner",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
  });

  @override
  State<TwoWheelerGenerateReportScreen> createState() =>
      _TwoWheelerGenerateReportScreenState();
}

class _TwoWheelerGenerateReportScreenState extends State<TwoWheelerGenerateReportScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;

  bool _ready = false;
  bool _stopping = false;
  bool _flashOn = false;

  XFile? _front;
  XFile? _frontSidewall;
  XFile? _back;
  XFile? _backSidewall;

  TwoTyrePos _active = TwoTyrePos.front;

  String? _error;
  bool _navigated = false;

  final ImagePicker _picker = ImagePicker();

  Timer? _marchTimer;
  double _marchPhase = 0;

  bool get _bothCaptured =>
      _front != null &&
      _frontSidewall != null &&
      _back != null &&
      _backSidewall != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMarchingLines();
    _initCam();
  }

  void _startMarchingLines() {
    _marchTimer?.cancel();
    _marchTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      setState(() => _marchPhase = (_marchPhase + 1) % 10000);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCameraSafely();
    } else if (state == AppLifecycleState.resumed) {
      if (!_stopping && mounted) {
        _initCam();
      }
    }
  }

  Future<void> _initCam() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        if (mounted) setState(() => _ready = true);
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'No camera found on device.');
        return;
      }

      final backCam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final c = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await c.initialize();

      // Default flash OFF whenever camera starts.
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
        _ready = true;
        _flashOn = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera not available: $e';
        _ready = false;
        _flashOn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (!_ready || c == null || _stopping) {
      setState(() => _error = 'Camera not ready.');
      return;
    }

    try {
      final next = !_flashOn;
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() {
        _flashOn = next;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Flash is not available on this device.');
    }
  }

  Future<void> _stopCameraSafely() async {
    if (_stopping) return;
    _stopping = true;

    final c = _controller;
    if (c == null) {
      _stopping = false;
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _ready = false;
          _controller = null;
          _flashOn = false;
        });
      }

      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}

      try {
        await c.pausePreview();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 80));
      await c.dispose();
    } catch (_) {
      // ignore
    } finally {
      _stopping = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _marchTimer?.cancel();
    _stopCameraSafely();
    super.dispose();
  }

  void _setFileForNextSlot(XFile file) {
    setState(() {
      _error = null;

      if (_front == null) {
        _front = file;
        _active = TwoTyrePos.frontSidewall;
        return;
      }

      if (_frontSidewall == null) {
        _frontSidewall = file;
        _active = TwoTyrePos.back;
        return;
      }

      if (_back == null) {
        _back = file;
        _active = TwoTyrePos.backSidewall;
        return;
      }

      _backSidewall = file;
      _active = TwoTyrePos.backSidewall;
    });
  }

  Future<void> _capture() async {
    if (_stopping) return;

    if (!_ready || _controller == null) {
      setState(() => _error = 'Camera not ready. Use Gallery instead.');
      return;
    }

    try {
      final shot = await _controller!.takePicture();
      if (!mounted) return;

      _setFileForNextSlot(shot);

      if (_bothCaptured) {
        await _goGenerateReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_stopping) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (!mounted) return;
      if (picked == null) return;

      _setFileForNextSlot(picked);

      if (_bothCaptured) {
        await _goGenerateReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gallery pick failed: $e');
    }
  }

  Future<void> _goGenerateReport() async {
    if (_navigated) return;
    if (_front == null ||
        _frontSidewall == null ||
        _back == null ||
        _backSidewall == null) {
      return;
    }

    _navigated = true;

    await _stopCameraSafely();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TwoWheelerReportResultScreen(
          frontPath: _front!.path,
          frontSidewallPath: _frontSidewall!.path,
          backPath: _back!.path,
          backSidewallPath: _backSidewall!.path,
          userId: widget.userId,
          vehicleId: widget.vehicleId,
          token: widget.token,
          vin: widget.vin,
          vehicleType: widget.vehicleType,
          frontTyreId: widget.frontTyreId,
          backTyreId: widget.backTyreId,
        ),
      ),
    );

    _navigated = false;

    if (mounted) {
      setState(() {
        _front = null;
        _frontSidewall = null;
        _back = null;
        _backSidewall = null;
        _active = TwoTyrePos.front;
        _error = null;
      });
    }

    if (mounted) _initCam();
  }

  void _retake(TwoTyrePos pos) {
    setState(() {
      switch (pos) {
        case TwoTyrePos.front:
          _front = null;
          break;
        case TwoTyrePos.frontSidewall:
          _frontSidewall = null;
          break;
        case TwoTyrePos.back:
          _back = null;
          break;
        case TwoTyrePos.backSidewall:
          _backSidewall = null;
          break;
      }
      _active = pos;
      _error = null;
    });
  }

  String _stepText() {
    if (_bothCaptured) return 'All tyre images selected ✅';
    if (_front == null) return 'Select FRONT tyre tread image';
    if (_frontSidewall == null) return 'Select FRONT tyre sidewall image';
    if (_back == null) return 'Select BACK tyre tread image';
    return 'Select BACK tyre sidewall image';
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final canPreview = _ready && _controller != null && !_stopping;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Full camera preview background
            Positioned.fill(
              child: canPreview
                  ? _CameraPreviewCover(controller: _controller!)
                  : const ColoredBox(color: Colors.black),
            ),

            // ✅ Camera guide frame + moving scan line
            Positioned.fill(
              child: IgnorePointer(
                child: _TyreGuidelineOverlay(
                  s: s,
                  active: _active,
                  phase: _marchPhase,
                ),
              ),
            ),

            Positioned(
  top: 38 * s,
  left: 16 * s,
  right: 16 * s,
  child: Row(
    children: [
      Container(
        width: 48 * s,
        height: 48 * s,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.35),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
          ),
        ),
      ),

      Expanded(
        child: Center(
          child: Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              fontSize: 20 * s,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),

      Container(
        width: 48 * s,
        height: 48 * s,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.35),
          shape: BoxShape.circle,
        ),
        child: _FlashButton(
          s: s,
          enabled: canPreview,
          isOn: _flashOn,
          onTap: _toggleFlash,
        ),
      ),
    ],
  ),
),

            // SafeArea(
            //   child: Padding(
            //     padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
            //     child: Row(
            //       children: [
            //         IconButton(
            //           onPressed: () => Navigator.pop(context),
            //           icon: const Icon(
            //             Icons.chevron_left_rounded,
            //             color: Colors.white,
            //             size: 32,
            //           ),
            //         ),
            //         Expanded(
            //           child: Text(
            //             widget.title,
            //             textAlign: TextAlign.center,
            //             maxLines: 1,
            //             overflow: TextOverflow.ellipsis,
            //             style: TextStyle(
            //               fontFamily: 'ClashGrotesk',
            //               fontWeight: FontWeight.w800,
            //               fontSize: 20 * s,
            //               color: Colors.white,
            //               shadows: const [
            //                 Shadow(color: Colors.black54, blurRadius: 8),
            //               ],
            //             ),
            //           ),
            //         ),
            //         _FlashButton(
            //           s: s,
            //           enabled: canPreview,
            //           isOn: _flashOn,
            //           onTap: _toggleFlash,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            if (_error != null)
              Positioned(
                top: 92,
                left: 16 * s,
                right: 16 * s,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 86 * s,
              left: 16 * s,
              right: 16 * s,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * s,
                  vertical: 9 * s,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.32),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.12)),
                ),
                child: Text(
                  _stepText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.94),
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 13 * s,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 134 * s,
              left: 16 * s,
              right: 16 * s,
              child: _CapturedTwoThumbsRow(
                s: s,
                active: _active,
                front: _front,
                frontSidewall: _frontSidewall,
                back: _back,
                backSidewall: _backSidewall,
                onSelect: (pos) => setState(() => _active = pos),
                onDelete: _retake,
              ),
            ),

            Positioned(
              left: 16 * s,
              right: 16 * s,
              bottom: 10 * s,
              child: BottomActionBar(
                enabled: !_stopping,
                onPickGallery: _pickFromGallery,
                onCapture: _capture,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashButton extends StatelessWidget {
  const _FlashButton({
    required this.s,
    required this.enabled,
    required this.isOn,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.38),
            shape: BoxShape.circle,
            border: Border.all(
              color: isOn
                  ? const Color(0xFFFFD54F)
                  : Colors.white.withOpacity(.18),
            ),
          ),
          child: Icon(
            isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: isOn ? const Color(0xFFFFD54F) : Colors.white,
            size: 24 * s,
          ),
        ),
      ),
    );
  }
}

class _TyreGuidelineOverlay extends StatelessWidget {
  const _TyreGuidelineOverlay({
    required this.s,
    required this.active,
    required this.phase,
  });

  final double s;
  final TwoTyrePos active;
  final double phase;

  bool get _isSidewall =>
      active == TwoTyrePos.frontSidewall || active == TwoTyrePos.backSidewall;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // ✅ Keep the guide aligned in the middle of the camera screen.
        // Tread needs a taller frame; sidewall needs a slightly shorter/wider frame.
        // final frameWidth = w * .82;
        // final frameHeight = _isSidewall ? h * .46 : h * .58;
        // final left = (w - frameWidth) / 2;
        // final top = _isSidewall ? h * .28 : h * .22;

        final frameWidth = w * .82;
final frameHeight = _isSidewall ? h * .54 : h * .52;
final left = (w - frameWidth) / 2;

// ✅ Move guide frame below the picture boxes
final top = _isSidewall ? h * .34 : h * .30;

        final rect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

        return CustomPaint(
          size: Size(w, h),
          painter: _MarchingFramePainter(
            rect: rect,
            phase: phase,
            isSidewall: _isSidewall,
          ),
        );
      },
    );
  }
}

class _MarchingFramePainter extends CustomPainter {
  const _MarchingFramePainter({
    required this.rect,
    required this.phase,
    required this.isSidewall,
  });

  final Rect rect;
  final double phase;
  final bool isSidewall;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(.06);
    final frameRRect = RRect.fromRectAndRadius(rect, const Radius.circular(38));

    final fullPath = Path()..addRect(Offset.zero & size);
    final cutPath = Path()..addRRect(frameRRect);
    final shaded = Path.combine(PathOperation.difference, fullPath, cutPath);
    canvas.drawPath(shaded, overlay);

    final cornerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    _drawCornerFrame(canvas, rect, cornerPaint);

    // ✅ Moving horizontal scan line.
    // final topPadding = 54.0;
    // final bottomPadding = 54.0;
    // final usableHeight = math.max(1.0, rect.height - topPadding - bottomPadding);
    // final progress = (phase % 120) / 120.0;
    // final y = rect.top + topPadding + (usableHeight * progress);

    // ✅ Start scan line higher from top
final topPadding = 50.0;
final bottomPadding = 24.0;

// ✅ Faster and smoother movement
final usableHeight =
    math.max(1.0, rect.height - topPadding - bottomPadding);

final progress = (phase % 90) / 90.0;

// ✅ Move line inside frame from top area
final y = rect.top + topPadding + (usableHeight * progress);

    final scanPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(rect.left, y - 10, rect.width, 20))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(rect.left, y - 12, rect.width, 24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final start = Offset(rect.left + 52, y);
    final end = Offset(rect.right - 52, y);
    canvas.drawLine(start, end, glowPaint);
    canvas.drawLine(start, end, scanPaint);
  }

  void _drawCornerFrame(Canvas canvas, Rect r, Paint p) {
    final radius = math.min(38.0, math.min(r.width, r.height) / 4);
    final cornerLen = math.min(96.0, math.min(r.width, r.height) * .32);

    canvas.drawArc(
      Rect.fromLTWH(r.left, r.top, radius * 2, radius * 2),
      math.pi,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(Offset(r.left + radius, r.top), Offset(r.left + cornerLen, r.top), p);
    canvas.drawLine(Offset(r.left, r.top + radius), Offset(r.left, r.top + cornerLen), p);

    canvas.drawArc(
      Rect.fromLTWH(r.right - radius * 2, r.top, radius * 2, radius * 2),
      -math.pi / 2,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(Offset(r.right - radius, r.top), Offset(r.right - cornerLen, r.top), p);
    canvas.drawLine(Offset(r.right, r.top + radius), Offset(r.right, r.top + cornerLen), p);

    canvas.drawArc(
      Rect.fromLTWH(r.left, r.bottom - radius * 2, radius * 2, radius * 2),
      math.pi / 2,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(Offset(r.left + radius, r.bottom), Offset(r.left + cornerLen, r.bottom), p);
    canvas.drawLine(Offset(r.left, r.bottom - radius), Offset(r.left, r.bottom - cornerLen), p);

    canvas.drawArc(
      Rect.fromLTWH(r.right - radius * 2, r.bottom - radius * 2, radius * 2, radius * 2),
      0,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(Offset(r.right - radius, r.bottom), Offset(r.right - cornerLen, r.bottom), p);
    canvas.drawLine(Offset(r.right, r.bottom - radius), Offset(r.right, r.bottom - cornerLen), p);
  }

  @override
  bool shouldRepaint(covariant _MarchingFramePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.rect != rect ||
        oldDelegate.isSidewall != isSidewall;
  }
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        final previewSize = controller.value.previewSize;

        if (previewSize == null || screenSize.width <= 0 || screenSize.height <= 0) {
          return const ColoredBox(color: Colors.black);
        }

        // ✅ Cover the whole screen without the narrow centered preview issue.
        final screenRatio = screenSize.width / screenSize.height;
        final previewRatio = previewSize.height / previewSize.width;
        double scale = previewRatio / screenRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _CapturedTwoThumbsRow extends StatelessWidget {
  const _CapturedTwoThumbsRow({
    required this.s,
    required this.active,
    required this.front,
    required this.frontSidewall,
    required this.back,
    required this.backSidewall,
    required this.onSelect,
    required this.onDelete,
  });

  final double s;
  final TwoTyrePos active;
  final XFile? front;
  final XFile? frontSidewall;
  final XFile? back;
  final XFile? backSidewall;

  final ValueChanged<TwoTyrePos> onSelect;
  final ValueChanged<TwoTyrePos> onDelete;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.35),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Expanded(child: _thumb("FRONT", TwoTyrePos.front, front)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("FR-S", TwoTyrePos.frontSidewall, frontSidewall)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("BACK", TwoTyrePos.back, back)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("BK-S", TwoTyrePos.backSidewall, backSidewall)),
        ],
      ),
    );
  }

  Widget _thumb(String label, TwoTyrePos pos, XFile? file) {
    final selected = active == pos;

    return InkWell(
      onTap: () => onSelect(pos),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(2.2 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected ? _grad : null,
          color: selected ? null : Colors.white.withOpacity(.08),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withOpacity(.12),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null)
                  Image.file(File(file.path), fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white.withOpacity(.08),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          color: Colors.white.withOpacity(.9),
                          fontWeight: FontWeight.w800,
                          fontSize: 12 * s,
                        ),
                      ),
                    ),
                  ),
                if (file != null)
                  Positioned(
                    right: 6 * s,
                    top: 6 * s,
                    child: GestureDetector(
                      onTap: () => onDelete(pos),
                      child: Container(
                        width: 24 * s,
                        height: 24 * s,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(.12)),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16 * s,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}














// enum TwoTyrePos { front, frontSidewall, back, backSidewall }

// class TwoWheelerGenerateReportScreen extends StatefulWidget {
//   final String title;

//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

//   // ✅ REMOVE THESE (they don't exist yet in scanner)
//   // final String frontPath;
//   // final String backPath;

//   // ✅ KEEP THESE
//   final String frontTyreId;
//   final String backTyreId;

//   const TwoWheelerGenerateReportScreen({
//     super.key,
//     this.title = "Bike Tyre Scanner",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     this.vehicleType = "bike",
//     required this.frontTyreId,
//     required this.backTyreId,
//   });

//   @override
//   State<TwoWheelerGenerateReportScreen> createState() =>
//       _TwoWheelerGenerateReportScreenState();
// }



// class _TwoWheelerGenerateReportScreenState extends State<TwoWheelerGenerateReportScreen>
//     with WidgetsBindingObserver {
//   CameraController? _controller;

//   bool _ready = false;
//   bool _stopping = false;

//   XFile? _front;
//   XFile? _frontSidewall;
//   XFile? _back;
//   XFile? _backSidewall;

//   TwoTyrePos _active = TwoTyrePos.front;

//   String? _error;
//   bool _navigated = false;

//   final ImagePicker _picker = ImagePicker();

//   bool get _bothCaptured =>
//       _front != null &&
//       _frontSidewall != null &&
//       _back != null &&
//       _backSidewall != null;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initCam();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     final c = _controller;
//     if (c == null) return;

//     if (state == AppLifecycleState.inactive ||
//         state == AppLifecycleState.paused ||
//         state == AppLifecycleState.detached) {
//       _stopCameraSafely();
//     } else if (state == AppLifecycleState.resumed) {
//       if (!_stopping && mounted) {
//         _initCam();
//       }
//     }
//   }

//   Future<void> _initCam() async {
//     try {
//       // Already initialized
//       if (_controller != null && _controller!.value.isInitialized) {
//         if (mounted) setState(() => _ready = true);
//         return;
//       }

//       final cams = await availableCameras();
//       if (cams.isEmpty) {
//         if (!mounted) return;
//         setState(() => _error = 'No camera found on device.');
//         return;
//       }

//       final backCam = cams.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.back,
//         orElse: () => cams.first,
//       );

//       final c = CameraController(
//         backCam,
//         ResolutionPreset.high,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420, // stable on Android
//       );

//       await c.initialize();
//       if (!mounted) {
//         await c.dispose();
//         return;
//       }

//       setState(() {
//         _controller = c;
//         _ready = true;
//         _error = null;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _error = 'Camera not available: $e';
//         _ready = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Camera not available: $e')),
//       );
//     }
//   }

//   Future<void> _stopCameraSafely() async {
//     if (_stopping) return;
//     _stopping = true;

//     final c = _controller;
//     if (c == null) {
//       _stopping = false;
//       return;
//     }

//     try {
//       if (mounted) {
//         setState(() {
//           _ready = false;
//           _controller = null;
//         });
//       }

//       try {
//         await c.pausePreview();
//       } catch (_) {}

//       await Future.delayed(const Duration(milliseconds: 80));
//       await c.dispose();
//     } catch (_) {
//       // ignore
//     } finally {
//       _stopping = false;
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _stopCameraSafely();
//     super.dispose();
//   }

//   void _setFileForNextSlot(XFile file) {
//     setState(() {
//       _error = null;

//       if (_front == null) {
//         _front = file;
//         _active = TwoTyrePos.frontSidewall;
//         return;
//       }

//       if (_frontSidewall == null) {
//         _frontSidewall = file;
//         _active = TwoTyrePos.back;
//         return;
//       }

//       if (_back == null) {
//         _back = file;
//         _active = TwoTyrePos.backSidewall;
//         return;
//       }

//       _backSidewall = file;
//       _active = TwoTyrePos.backSidewall;
//     });
//   }

//   Future<void> _capture() async {
//     if (_stopping) return;

//     // ✅ Capture requires camera ready; gallery does not.
//     if (!_ready || _controller == null) {
//       setState(() => _error = 'Camera not ready. Use Gallery instead.');
//       return;
//     }

//     try {
//       final shot = await _controller!.takePicture();
//       if (!mounted) return;

//       _setFileForNextSlot(shot);

//       if (_bothCaptured) {
//         await _goGenerateReport();
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = 'Capture failed: $e');
//     }
//   }

//   Future<void> _pickFromGallery() async {
//     if (_stopping) return;

//     try {
//       final picked = await _picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 95,
//       );

//       if (!mounted) return;
//       if (picked == null) return;

//       _setFileForNextSlot(picked);

//       if (_bothCaptured) {
//         await _goGenerateReport();
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = 'Gallery pick failed: $e');
//     }
//   }

  
  
//   Future<void> _goGenerateReport() async {
//   if (_navigated) return;
//   if (_front == null || _frontSidewall == null || _back == null || _backSidewall == null) return;

//   _navigated = true;

//   await _stopCameraSafely();
//   if (!mounted) return;

//   await Navigator.of(context).push(
//     MaterialPageRoute(
//       builder: (_) => TwoWheelerReportResultScreen(
//         frontPath: _front!.path,
//         frontSidewallPath: _frontSidewall!.path,
//         backPath: _back!.path,
//         backSidewallPath: _backSidewall!.path,
//         userId: widget.userId,
//         vehicleId: widget.vehicleId,
//         token: widget.token,
//         vin: widget.vin,
//         vehicleType: widget.vehicleType,
//         frontTyreId: widget.frontTyreId,
//         backTyreId: widget.backTyreId,
//       ),
//     ),
//   );

//   // ✅ when coming back from report screen
//   _navigated = false;

//   // optional reset
//   if (mounted) {
//     setState(() {
//       _front = null;
//       _frontSidewall = null;
//       _back = null;
//       _backSidewall = null;
//       _active = TwoTyrePos.front;
//       _error = null;
//     });
//   }

//   if (mounted) _initCam();
// }


// //   Future<void> _goGenerateReport() async {
// //     if (_navigated) return;
// //     if (_front == null || _frontSidewall == null || _back == null || _backSidewall == null) return;

// //     _navigated = true;

// //     await _stopCameraSafely();
// //     if (!mounted) return;

// //  await Navigator.of(context).push(
// //   MaterialPageRoute(
// //     builder: (_) => TwoWheelerGenerateReportScreen(

// //       userId: widget.userId,
// //       vehicleId: widget.vehicleId,
// //       token: widget.token,
// //       vin: widget.vin ?? '',
// //       vehicleType: widget.vehicleType,

// //       // ✅ ADD THESE (FIX)
// //       frontTyreId: widget.frontTyreId,
// //       backTyreId: widget.backTyreId,
// //     ),
// //   ),
// // );

// //   }

//   void _retake(TwoTyrePos pos) {
//     setState(() {
//       switch (pos) {
//         case TwoTyrePos.front:
//           _front = null;
//           break;
//         case TwoTyrePos.frontSidewall:
//           _frontSidewall = null;
//           break;
//         case TwoTyrePos.back:
//           _back = null;
//           break;
//         case TwoTyrePos.backSidewall:
//           _backSidewall = null;
//           break;
//       }
//       _active = pos;
//       _error = null;
//     });
//   }

//   String _stepText() {
//     if (_bothCaptured) return 'All tyre images selected ✅';
//     if (_front == null) return 'Select FRONT tyre tread image';
//     if (_frontSidewall == null) return 'Select FRONT tyre sidewall image';
//     if (_back == null) return 'Select BACK tyre tread image';
//     return 'Select BACK tyre sidewall image';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;
//     final canPreview = _ready && _controller != null && !_stopping;

//     return Scaffold(
//       body: Stack(
//         children: [
//           // ✅ ALWAYS BOUNDED PREVIEW (no AspectRatio crash)
//           Positioned.fill(
//             child: canPreview
//                 ? _CameraPreviewCover(controller: _controller!)
//                 : const ColoredBox(color: Colors.black),
//           ),

//           SafeArea(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
//               child: Row(
//                 children: [
//                   IconButton(
//                     onPressed: () => Navigator.pop(context),
//                     icon: const Icon(
//                       Icons.chevron_left_rounded,
//                       color: Colors.white,
//                       size: 32,
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       widget.title,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                         fontSize: 20 * s,
//                         color: Colors.white,
//                         shadows: const [
//                           Shadow(color: Colors.black54, blurRadius: 8),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 46),
//                 ],
//               ),
//             ),
//           ),

//           // ✅ If ScanOverlay exists in your project, keep it. Otherwise remove this line.
//           const ScanOverlay(),

//           // ✅ Error banner
//           if (_error != null)
//             Positioned(
//               top: 92,
//               left: 16 * s,
//               right: 16 * s,
//               child: Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(.85),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ),

//           // ✅ Step hint (Front/Back)
//           Positioned(
//             top: 120,
//             left: 16 * s,
//             right: 16 * s,
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(.35),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.white.withOpacity(.10)),
//               ),
//               child: Text(
//                 _stepText(),
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(.92),
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w800,
//                   fontSize: 13 * s,
//                 ),
//               ),
//             ),
//           ),

//           // Thumbs row
//           Positioned(
//             top: 175,
//             left: 16 * s,
//             right: 16 * s,
//             child: _CapturedTwoThumbsRow(
//               s: s,
//               active: _active,
//               front: _front,
//               frontSidewall: _frontSidewall,
//               back: _back,
//               backSidewall: _backSidewall,
//               onSelect: (pos) => setState(() => _active = pos),
//               onDelete: _retake,
//             ),
//           ),

//           // Bottom actions
//           Positioned(
//             left: 16 * s,
//             right: 16 * s,
//             bottom: 14 * s,
//             child: BottomActionBar(
//               // ✅ IMPORTANT FIX:
//               // keep actions enabled even if camera isn't ready
//               enabled: !_stopping,

//               // gallery always works
//               onPickGallery: _pickFromGallery,

//               // capture only works when camera ready (guard is inside _capture too)
//               onCapture: _capture,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// ✅ Most stable preview wrapper:
// /// Forces tight constraints AND uses BoxFit.cover behavior
// class _CameraPreviewCover extends StatelessWidget {
//   const _CameraPreviewCover({required this.controller});

//   final CameraController controller;

//   @override
//   Widget build(BuildContext context) {
//     if (!controller.value.isInitialized) {
//       return const ColoredBox(color: Colors.black);
//     }

//     final previewSize = controller.value.previewSize;
//     if (previewSize == null) {
//       return const ColoredBox(color: Colors.black);
//     }

//     return SizedBox.expand(
//       child: FittedBox(
//         fit: BoxFit.cover,
//         child: SizedBox(
//           width: previewSize.height, // swapped for correct orientation
//           height: previewSize.width,
//           child: CameraPreview(controller),
//         ),
//       ),
//     );
//   }
// }

// class _CapturedTwoThumbsRow extends StatelessWidget {
//   const _CapturedTwoThumbsRow({
//     required this.s,
//     required this.active,
//     required this.front,
//     required this.frontSidewall,
//     required this.back,
//     required this.backSidewall,
//     required this.onSelect,
//     required this.onDelete,
//   });

//   final double s;
//   final TwoTyrePos active;
//   final XFile? front;
//   final XFile? frontSidewall;
//   final XFile? back;
//   final XFile? backSidewall;

//   final ValueChanged<TwoTyrePos> onSelect;
//   final ValueChanged<TwoTyrePos> onDelete;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(10 * s),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(.35),
//         borderRadius: BorderRadius.circular(14 * s),
//         border: Border.all(color: Colors.white.withOpacity(.10)),
//       ),
//       child: Row(
//         children: [
//           Expanded(child: _thumb("FRONT", TwoTyrePos.front, front)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _thumb("FR-S", TwoTyrePos.frontSidewall, frontSidewall)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _thumb("BACK", TwoTyrePos.back, back)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _thumb("BK-S", TwoTyrePos.backSidewall, backSidewall)),
//         ],
//       ),
//     );
//   }

//   Widget _thumb(String label, TwoTyrePos pos, XFile? file) {
//     final selected = active == pos;

//     return InkWell(
//       onTap: () => onSelect(pos),
//       borderRadius: BorderRadius.circular(12),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         padding: EdgeInsets.all(2.2 * s),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           gradient: selected ? _grad : null,
//           color: selected ? null : Colors.white.withOpacity(.08),
//           border: Border.all(
//             color: selected ? Colors.transparent : Colors.white.withOpacity(.12),
//           ),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: AspectRatio(
//             aspectRatio: 1,
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 if (file != null)
//                   Image.file(File(file.path), fit: BoxFit.cover)
//                 else
//                   Container(
//                     color: Colors.white.withOpacity(.08),
//                     child: Center(
//                       child: Text(
//                         label,
//                         style: TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           color: Colors.white.withOpacity(.9),
//                           fontWeight: FontWeight.w800,
//                           fontSize: 12 * s,
//                         ),
//                       ),
//                     ),
//                   ),
//                 if (file != null)
//                   Positioned(
//                     right: 6 * s,
//                     top: 6 * s,
//                     child: GestureDetector(
//                       onTap: () => onDelete(pos),
//                       child: Container(
//                         width: 24 * s,
//                         height: 24 * s,
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(.55),
//                           shape: BoxShape.circle,
//                           border: Border.all(color: Colors.white.withOpacity(.12)),
//                         ),
//                         child: Icon(
//                           Icons.close_rounded,
//                           size: 16 * s,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

