import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart' show BottomActionBar;
import 'package:ios_tiretest_ai/Widgets/scan_overlay.dart';




class ScannerFrontTireScreen extends StatefulWidget {
  String vehicleID;
   ScannerFrontTireScreen({super.key,required this.vehicleID});

  @override
  State<ScannerFrontTireScreen> createState() => _ScannerFrontTireScreenState();
}

class _ScannerFrontTireScreenState extends State<ScannerFrontTireScreen>
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
      if (_front == null) {
        setState(() => _front = shot);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Front tire captured. Capture back tire.'),
          ),
        );
      } else {
        setState(() => _back = shot);
        _goCountdownAndUpload();
      }
    } catch (e) {
      // ignore for now
    }
  }

  void _goCountdownAndUpload() {
    final auth = context.read<AuthBloc>().state;
    final token = auth.loginResponse?.token ?? '';
  //  final userId = ''; // fill from your login model
   // final vehicleId = 'vehicle-001'; // pass real one

    // Navigator.of(context)
    //     .push(
    //   MaterialPageRoute(
    //     builder: (_) => GenerateReportScreen(
    //       frontPath: _front!.path,
    //       backPath: _back!.path,
    //       userId: context.read<AuthBloc>().state.profile!.userId.toString(),
    //       vehicleId: context.read<AuthBloc>().state.vehiclePreferencesModel!.vehicleIds.toString(),
    //       token: token,
    //     ),
    //   ),
   // )
//     Navigator.of(context).push(
//   MaterialPageRoute(
//     builder: (_) => InspectionResultScreen(
//       frontPath: _front!.path,
//       backPath: _back!.path,
//        userId: context.read<AuthBloc>().state.profile!.userId,
//       vehicleId: widget.vehicleID,
//        token: token,
//     ),
//   ),
// )

    //     .then((_) {
    //   // reset for new capture
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
      body: Stack(
        children: [
          // camera Testing@123 .com
          if (_ready && _controller != null)
            Positioned(
              top: 100,
              child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child:
                    const CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // header
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
                      widget.vehicleID,//'Tire inspection Scanner',
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

          // overlay
          const ScanOverlay(),

          // captured badges
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

          // bottom scan/gallery/docs bar
          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: _ready,
              onPickGallery: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Pick from gallery (optional).')),
              ),
              // onPickDocs: () => ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(
              //       content: Text('Pick documents (optional).')),
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
