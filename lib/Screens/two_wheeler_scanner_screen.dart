import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart' show BottomActionBar;
import 'package:ios_tiretest_ai/Screens/two_wheeler_report_result_screen.dart';



enum TwoTyrePos { front, back }

class TwoWheelerGenerateReportScreen extends StatefulWidget {
  final String title;

  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  // ✅ REMOVE THESE (they don't exist yet in scanner)
  // final String frontPath;
  // final String backPath;

  // ✅ KEEP THESE
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

  XFile? _front;
  XFile? _back;

  TwoTyrePos _active = TwoTyrePos.front;

  String? _error;
  bool _navigated = false;

  final ImagePicker _picker = ImagePicker();

  bool get _bothCaptured => _front != null && _back != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCam();
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
      // Already initialized
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
        imageFormatGroup: ImageFormatGroup.yuv420, // stable on Android
      );

      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
        _ready = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera not available: $e';
        _ready = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
      );
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
        });
      }

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
    _stopCameraSafely();
    super.dispose();
  }

  // ✅ Bulletproof assignment:
  // First image ALWAYS goes to FRONT, second ALWAYS goes to BACK.
  void _setFileForNextSlot(XFile file) {
    setState(() {
      _error = null;

      if (_front == null) {
        _front = file;
        _active = TwoTyrePos.back;
        return;
      }

      _back = file;
      _active = TwoTyrePos.back;
    });
  }

  Future<void> _capture() async {
    if (_stopping) return;

    // ✅ Capture requires camera ready; gallery does not.
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
  if (_front == null || _back == null) return;

  _navigated = true;

  await _stopCameraSafely();
  if (!mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TwoWheelerReportResultScreen(
        frontPath: _front!.path,
        backPath: _back!.path,
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

  // ✅ when coming back from report screen
  _navigated = false;

  // optional reset
  if (mounted) {
    setState(() {
      _front = null;
      _back = null;
      _active = TwoTyrePos.front;
      _error = null;
    });
  }

  if (mounted) _initCam();
}


//   Future<void> _goGenerateReport() async {
//     if (_navigated) return;
//     if (_front == null || _back == null) return;

//     _navigated = true;

//     await _stopCameraSafely();
//     if (!mounted) return;

//  await Navigator.of(context).push(
//   MaterialPageRoute(
//     builder: (_) => TwoWheelerGenerateReportScreen(

//       userId: widget.userId,
//       vehicleId: widget.vehicleId,
//       token: widget.token,
//       vin: widget.vin ?? '',
//       vehicleType: widget.vehicleType,

//       // ✅ ADD THESE (FIX)
//       frontTyreId: widget.frontTyreId,
//       backTyreId: widget.backTyreId,
//     ),
//   ),
// );

//   }

  void _retake(TwoTyrePos pos) {
    setState(() {
      if (pos == TwoTyrePos.front) {
        _front = null;
        // If you remove front, back becomes invalid logically—optional choice:
        // Keep back or clear it; usually clear it to avoid mismatched pair.
        _back = null;
        _active = TwoTyrePos.front;
      } else {
        _back = null;
        // If front exists, we want to capture back again
        _active = TwoTyrePos.back;
      }
      _error = null;
    });
  }

  String _stepText() {
    if (_bothCaptured) return 'Both tyres selected ✅';
    if (_front == null) return 'Select FRONT tyre image';
    return 'Now select BACK tyre image';
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final canPreview = _ready && _controller != null && !_stopping;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ ALWAYS BOUNDED PREVIEW (no AspectRatio crash)
          Positioned.fill(
            child: canPreview
                ? _CameraPreviewCover(controller: _controller!)
                : const ColoredBox(color: Colors.black),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 20 * s,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),

          // ✅ If ScanOverlay exists in your project, keep it. Otherwise remove this line.
          const ScanOverlay(),

          // ✅ Error banner
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

          // ✅ Step hint (Front/Back)
          Positioned(
            top: 120,
            left: 16 * s,
            right: 16 * s,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Text(
                _stepText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 13 * s,
                ),
              ),
            ),
          ),

          // Thumbs row
          Positioned(
            top: 175,
            left: 16 * s,
            right: 16 * s,
            child: _CapturedTwoThumbsRow(
              s: s,
              active: _active,
              front: _front,
              back: _back,
              onSelect: (pos) => setState(() => _active = pos),
              onDelete: _retake,
            ),
          ),

          // Bottom actions
          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              // ✅ IMPORTANT FIX:
              // keep actions enabled even if camera isn't ready
              enabled: !_stopping,

              // gallery always works
              onPickGallery: _pickFromGallery,

              // capture only works when camera ready (guard is inside _capture too)
              onCapture: _capture,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Most stable preview wrapper:
/// Forces tight constraints AND uses BoxFit.cover behavior
class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height, // swapped for correct orientation
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CapturedTwoThumbsRow extends StatelessWidget {
  const _CapturedTwoThumbsRow({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
    required this.onSelect,
    required this.onDelete,
  });

  final double s;
  final TwoTyrePos active;
  final XFile? front;
  final XFile? back;

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
          Expanded(child: _thumb("BACK", TwoTyrePos.back, back)),
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

