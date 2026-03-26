import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'dart:async';
import 'generate_report_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';



enum TyrePos { frontLeft, frontRight, backLeft, backRight }

class CarTyresScannerScreen extends StatefulWidget {
  final String title;

  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;
  final String vehicleType;

  const CarTyresScannerScreen({
    super.key,
    this.title = "Car Tyre Scanner",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = "car",
  });

  @override
  State<CarTyresScannerScreen> createState() => _CarTyresScannerScreenState();
}

class _CarTyresScannerScreenState extends State<CarTyresScannerScreen> {
  CameraController? _controller;

  bool _ready = false;
  bool _stopping = false;

  XFile? _frontLeft;
  XFile? _frontRight;
  XFile? _backLeft;
  XFile? _backRight;

  TyrePos _active = TyrePos.frontLeft;
  String? _error;
  bool _navigated = false;
  final ImagePicker _picker = ImagePicker();

  bool get _allCaptured =>
      _frontLeft != null &&
      _frontRight != null &&
      _backLeft != null &&
      _backRight != null;

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
      if (!mounted) return;

      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera not available: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
      );
    }
  }

  Future<void> _stopCameraSafely() async {
    if (_stopping) return;
    _stopping = true;

    final c = _controller;
    if (c == null) return;

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
    _stopCameraSafely();
    super.dispose();
  }

  XFile? _getFileForPos(TyrePos pos) {
    switch (pos) {
      case TyrePos.frontLeft:
        return _frontLeft;
      case TyrePos.frontRight:
        return _frontRight;
      case TyrePos.backLeft:
        return _backLeft;
      case TyrePos.backRight:
        return _backRight;
    }
  }

  void _setFileForActive(XFile file) {
    setState(() {
      _error = null;
      switch (_active) {
        case TyrePos.frontLeft:
          _frontLeft = file;
          _active = TyrePos.frontRight;
          break;
        case TyrePos.frontRight:
          _frontRight = file;
          _active = TyrePos.backLeft;
          break;
        case TyrePos.backLeft:
          _backLeft = file;
          _active = TyrePos.backRight;
          break;
        case TyrePos.backRight:
          _backRight = file;
          break;
      }
    });
  }

  Future<void> _capture() async {
    if (!_ready || _controller == null || _stopping) return;

    try {
      final shot = await _controller!.takePicture();
      if (!mounted) return;

      _setFileForActive(shot);

      if (_allCaptured) {
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

      _setFileForActive(picked);

      if (_allCaptured) {
        await _goGenerateReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gallery pick failed: $e');
    }
  }

  Future<void> _goGenerateReport() async {
    if (_navigated) return;
    _navigated = true;

    await _stopCameraSafely();
    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenerateReportScreen(
          frontLeftPath: _frontLeft!.path,
          frontRightPath: _frontRight!.path,
          backLeftPath: _backLeft!.path,
          backRightPath: _backRight!.path,
          userId: widget.userId,
          vehicleId: widget.vehicleId,
          token: widget.token,
          vin: widget.vin,
          vehicleType: widget.vehicleType,
          frontLeftTyreId: widget.frontLeftTyreId,
          frontRightTyreId: widget.frontRightTyreId,
          backLeftTyreId: widget.backLeftTyreId,
          backRightTyreId: widget.backRightTyreId,
        ),
      ),
    );

    // ✅ allow navigation again
    _navigated = false;

    // ✅ If user tapped "Retake Images" on report screen, clear selections and restart camera
    if (mounted && result == 'retake') {
      setState(() {
        _frontLeft = null;
        _frontRight = null;
        _backLeft = null;
        _backRight = null;
        _active = TyrePos.frontLeft;
        _error = null;
      });
    }

    // ✅ ensure camera preview is back when returning
    if (mounted) {
      await _initCam();
    }
}

  void _retake(TyrePos pos) {
    setState(() {
      switch (pos) {
        case TyrePos.frontLeft:
          _frontLeft = null;
          break;
        case TyrePos.frontRight:
          _frontRight = null;
          break;
        case TyrePos.backLeft:
          _backLeft = null;
          break;
        case TyrePos.backRight:
          _backRight = null;
          break;
      }
      _active = pos;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    final activeFile = _getFileForPos(_active);

    return Scaffold(
      body: Stack(
        children: [
          if (_ready && _controller != null && !_stopping)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(child: Container(color: Colors.black)),

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

          const ScanOverlay(),

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
            top: 125,
            left: 16 * s,
            right: 16 * s,
            child: Column(
              children: [
               /* _TyreSelectorBar(
                  s: s,
                  active: _active,
                  frontLeft: _frontLeft != null,
                  frontRight: _frontRight != null,
                  backLeft: _backLeft != null,
                  backRight: _backRight != null,
                  disabled: false,
                  onSelect: (pos) => setState(() => _active = pos),
                  onRetake: _retake,
                ),
                */
                SizedBox(height: 10 * s),

              /*  _ActiveTyrePreview(
                  s: s,
                  label: _labelForPos(_active),
                  file: activeFile,
                ),

                // ✅ NEW UI: thumbnails row with delete
                SizedBox(height: 10 * s),*/
                _CapturedThumbsRow(
                  s: s,
                  active: _active,
                  frontLeft: _frontLeft,
                  frontRight: _frontRight,
                  backLeft: _backLeft,
                  backRight: _backRight,
                  onSelect: (pos) => setState(() => _active = pos),
                  onDelete: _retake,
                ),
              ],
            ),
          ),

          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: _ready && !_stopping,
              onPickGallery: _pickFromGallery,
            //  onPickDocs: () {},
              onCapture: _capture,
              // galleryIconAsset: 'assets/gallery_icon.png',
              // captureIconAsset: 'assets/image_capture_icon.png',
             // docsIconAsset: 'assets/document_icon.png',
            ),
          ),
        ],
      ),
    );
  }

  String _labelForPos(TyrePos pos) {
    switch (pos) {
      case TyrePos.frontLeft:
        return "Front Left";
      case TyrePos.frontRight:
        return "Front Right";
      case TyrePos.backLeft:
        return "Back Left";
      case TyrePos.backRight:
        return "Back Right";
    }
  }
}


class _CapturedThumbsRow extends StatelessWidget {
  const _CapturedThumbsRow({
    required this.s,
    required this.active,
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
    required this.onSelect,
    required this.onDelete,
  });

  final double s;
  final TyrePos active;
  final XFile? frontLeft;
  final XFile? frontRight;
  final XFile? backLeft;
  final XFile? backRight;

  final ValueChanged<TyrePos> onSelect;
  final ValueChanged<TyrePos> onDelete;

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
          Expanded(child: _thumb("FL", TyrePos.frontLeft, frontLeft)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("FR", TyrePos.frontRight, frontRight)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("BL", TyrePos.backLeft, backLeft)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("BR", TyrePos.backRight, backRight)),
        ],
      ),
    );
  }

  Widget _thumb(String short, TyrePos pos, XFile? file) {
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined,
                              color: Colors.white.withOpacity(.85),
                              size: 18 * s),
                          SizedBox(height: 4 * s),
                          Text(
                            short,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: Colors.white.withOpacity(.9),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5 * s,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 6 * s,
                  bottom: 6 * s,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 7 * s, vertical: 4 * s),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.10)),
                    ),
                    child: Text(
                      short,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11 * s,
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
                          border:
                              Border.all(color: Colors.white.withOpacity(.12)),
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

