import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';
import 'dart:convert';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;



class _JsonValue {
  static dynamic read(dynamic obj, String key) {
    if (obj == null) return null;

    if (obj is Map) return obj[key];

    try {
      final json = (obj as dynamic).toJson();
      if (json is Map) return json[key];
    } catch (_) {}

    try {
      switch (key) {
        case 'data':
          return (obj as dynamic).data;
        case 'message':
          return (obj as dynamic).message;
        case 'record_id':
          return (obj as dynamic).recordId;
        case 'vehicle_id':
          return (obj as dynamic).vehicleId;
        case 'vin':
          return (obj as dynamic).vin;
        case 'vehicle_type':
          return (obj as dynamic).vehicleType;
        case 'front':
          return (obj as dynamic).front;
        case 'back':
          return (obj as dynamic).back;
      }
    } catch (_) {}

    return null;
  }

  static String string(dynamic v, {String fallback = 'N/A'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
    return s;
  }
}

enum _BikeReportTab {
  frontTread,
  frontSidewall,
  backTread,
  backSidewall,
}

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Inspection Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState
    extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;
  bool _navigated = false;

  _BikeReportTab _active = _BikeReportTab.frontTread;

  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(
          AdsFetchRequested(token: widget.token, silent: true),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;

    if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tyre ids. Save preferences again.')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          UploadTwoWheelerRequested(
            userId: widget.userId,
            vehicleId: widget.vehicleId,
            token: widget.token,
            vin: widget.vin,
            vehicleType: widget.vehicleType,
            frontPath: widget.frontPath,
            frontSidewallPath: widget.frontSidewallPath,
            backPath: widget.backPath,
            backSidewallPath: widget.backSidewallPath,
            frontTyreId: widget.frontTyreId,
            backTyreId: widget.backTyreId,
          ),
        );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentVideoUrl == u && _videoCtrl != null) return;

    _currentVideoUrl = u;

    try {
      final old = _videoCtrl;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));

      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() => _videoCtrl = ctrl);
      await old?.dispose();
    } catch (_) {}
  }

  void _stopVideo() {
  final vc = _videoCtrl;
  _videoCtrl = null;
  _currentVideoUrl = '';
  _adPlayStarted = false;
  vc?.dispose();
}

String _safePdfName() {
  final vin = widget.vin.trim().isEmpty ? 'bike_report' : widget.vin.trim();
  final safeVin = vin.replaceAll(RegExp(r'[^\w\-]+'), '_');
  final time = DateTime.now().millisecondsSinceEpoch;
  return 'Bike_Tyre_Report_${safeVin}_$time.pdf';
}

// String _safePdfName() {
//   final vin = widget.vin.trim().isEmpty ? 'bike_report' : widget.vin.trim();
//   final safeVin = vin.replaceAll(RegExp(r'[^\w\-]+'), '_');
//   return 'Bike_Tyre_Report_$safeVin.pdf';
// }

Future<File> _createReportPdfFile({required bool temporary}) async {
  final state = context.read<AuthBloc>().state;
  final data = state.twoWheelerResponse?.data;

  final baseDir = temporary
      ? await getTemporaryDirectory()
      : await getApplicationDocumentsDirectory();

  final reportDir = Directory('${baseDir.path}/Reports');
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }

  final file = File('${reportDir.path}/${_safePdfName()}');

  final bytes = await _TwoWheelerPdfReport.build(
    title: widget.title,
    vehicleId: widget.vehicleId,
    vin: widget.vin,
    vehicleType: widget.vehicleType,
    frontTyreId: widget.frontTyreId,
    backTyreId: widget.backTyreId,
    frontPath: widget.frontPath,
    frontSidewallPath: widget.frontSidewallPath,
    backPath: widget.backPath,
    backSidewallPath: widget.backSidewallPath,
    data: data,
    message: _JsonValue.string(
      _JsonValue.read(state.twoWheelerResponse, 'message'),
      fallback: 'successful',
    ),
    front: data?.front,
    back: data?.back,
  );

  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> _saveReportPdf() async {
  try {
    final file = await _createReportPdfFile(temporary: false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved: ${file.path.split('/').last}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF save failed: $e')),
    );
  }
}

Future<void> _shareReportPdf() async {
  try {
    final file = await _createReportPdfFile(temporary: true);
    if (!mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bike Tire Inspection Report',
      subject: 'Bike Tire Inspection Report',
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF share failed: $e')),
    );
  }
}

Future<void> _shareReport() async {
  final s = MediaQuery.sizeOf(context).width / 390.0;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: _PdfActionDialog(
          s: s,
          onSave: () async {
            Navigator.of(context).pop();
            await _saveReportPdf();
          },
          onShare: () async {
            Navigator.of(context).pop();
            await _shareReportPdf();
          },
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

  // void _stopVideo() {
  //   final vc = _videoCtrl;
  //   _videoCtrl = null;
  //   _currentVideoUrl = '';
  //   _adPlayStarted = false;
  //   vc?.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F8FC), Color(0xFFF3F4F7)],
            ),
          ),
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (p, c) =>
                    p.selectedAd?.media != c.selectedAd?.media ||
                    p.adsStatus != c.adsStatus ||
                    p.twoWheelerStatus != c.twoWheelerStatus,
                listener: (context, state) {
                  final isLoading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
  final media = state.selectedAd?.media.trim() ?? '';

  if (isLoading && media.isNotEmpty && !_adPlayStarted) {
    _adPlayStarted = true;
    _playVideo(media);
  }

  // ✅ IMPORTANT FIX: stop ad video/audio as soon as report is ready or failed
  if (state.twoWheelerStatus == TwoWheelerStatus.success ||
      state.twoWheelerStatus == TwoWheelerStatus.failure) {
    _stopVideo();
  }

  if (state.twoWheelerStatus == TwoWheelerStatus.success) {
    context.read<AuthBloc>().add(
      FetchTyreHistoryRequested(
        userId: widget.userId,
        vehicleId: "ALL",
      ),
    );
  }
                  // if (state.twoWheelerStatus == TwoWheelerStatus.success) {
                  //   context.read<AuthBloc>().add(
                  //         FetchTyreHistoryRequested(
                  //           userId: widget.userId,
                  //           vehicleId: "ALL",
                  //         ),
                  //       );
                  // }

                  // final isLoading =
                  //     state.twoWheelerStatus == TwoWheelerStatus.uploading;
                  // final media = state.selectedAd?.media.trim() ?? '';

                  // if (isLoading && media.isNotEmpty && !_adPlayStarted) {
                  //   _adPlayStarted = true;
                  //   _playVideo(media);
                  // }

                  // if (!isLoading) {
                  //   _stopVideo();
                  // }
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (p, c) =>
                  p.twoWheelerStatus != c.twoWheelerStatus ||
                  p.twoWheelerResponse != c.twoWheelerResponse,
              builder: (context, state) {
                final st = state.twoWheelerStatus;
                final loading = st == TwoWheelerStatus.uploading;

                if (st == TwoWheelerStatus.failure) {
                  final msg = state.twoWheelerError.trim().isEmpty
                      ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                      : state.twoWheelerError.trim();

                  return _ThemedScanFailedView(
                    s: s,
                    message: msg,
                    gradient: _Ui.brandGrad,
                    onRetake: () {
                      if (_navigated) return;
                      _navigated = true;
                      Navigator.of(context).pop('retake');
                    },
                    onRetry: () {
                      if (_navigated) return;
                      setState(() => _dispatched = false);
                      _upload();
                    },
                  );
                }

                if (loading) {
                  return Stack(
                    children: [
                      _FullscreenVideoOnly(controller: _videoCtrl),
                      Positioned(
                        left: 16 * s,
                        right: 16 * s,
                        bottom: 22 * s,
                        child: _GeneratingOverlayModern(s: s),
                      ),
                    ],
                  );
                }

                final resp = state.twoWheelerResponse;
                final data = resp?.data;
                final front = data?.front;
                final back = data?.back;
                final hasAny = front != null || back != null;

                return Column(
                  children: [
                    _TopBarModern(
                      s: s,
                      title: widget.title,
                      onBack: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false,
                        );
                      },
                      onShare: _shareReport,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16 * s,
                          10 * s,
                          16 * s,
                          20 * s,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!loading && resp == null)
                              _EmptyStateCardModern(
                                s: s,
                                title: "No report yet",
                                subtitle:
                                    "Tap retry to generate the bike report again.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),

                            if (!loading && resp != null && !hasAny)
                              _EmptyStateCardModern(
                                s: s,
                                title: "No data found",
                                subtitle:
                                    "Upload succeeded but front/back data is missing.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),

                            if (hasAny) ...[
                              _ReportOverviewCard(
                                s: s,
                                responseData: data,
                                responseMessage: _JsonValue.string(
                                  _JsonValue.read(resp, 'message'),
                                  fallback: 'successful',
                                ),
                                vehicleId: widget.vehicleId,
                                vin: widget.vin,
                                vehicleType: widget.vehicleType,
                                frontTyreId: widget.frontTyreId,
                                backTyreId: widget.backTyreId,
                              ),
                              SizedBox(height: 12 * s),
                              _FourImagePreviewRow(
                                s: s,
                                active: _active,
                                frontPath: widget.frontPath,
                                frontSidewallPath: widget.frontSidewallPath,
                                backPath: widget.backPath,
                                backSidewallPath: widget.backSidewallPath,
                                onSelect: (tab) => setState(() => _active = tab),
                              ),
                              SizedBox(height: 12 * s),
                              _TabChips(
                                s: s,
                                active: _active,
                                onSelect: (tab) => setState(() => _active = tab),
                              ),
                              SizedBox(height: 12 * s),
                              _TyreReportSection(
                                s: s,
                                active: _active,
                                front: front,
                                back: back,
                                frontPath: widget.frontPath,
                                frontSidewallPath: widget.frontSidewallPath,
                                backPath: widget.backPath,
                                backSidewallPath: widget.backSidewallPath,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


class _TwoWheelerPdfReport {
  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _softBg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _blue = PdfColor.fromInt(0xFF4F7BFF);

  static String _str(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.toLowerCase() == 'null') return '';
    return s;
  }

  static dynamic _read(dynamic obj, String key) {
    if (obj == null) return null;

    if (obj is Map) return obj[key];

    try {
      final json = (obj as dynamic).toJson();
      if (json is Map) return json[key];
    } catch (_) {}

    try {
      switch (key) {
        case 'record_id':
          return (obj as dynamic).recordId;
        case 'vehicle_id':
          return (obj as dynamic).vehicleId;
        case 'vin':
          return (obj as dynamic).vin;
        case 'vehicle_type':
          return (obj as dynamic).vehicleType;
        case 'is_tire':
          return (obj as dynamic).isTire;
        case 'status':
          return (obj as dynamic).status;
        case 'condition':
          return (obj as dynamic).condition;
        case 'tread_depth':
          return (obj as dynamic).treadDepth;
        case 'wear_patterns':
          return (obj as dynamic).wearPatterns;
        case 'tire_pressure':
          return (obj as dynamic).tirePressure;
        case 'pressure':
          return (obj as dynamic).pressure;
        case 'pressure_advisory':
          return (obj as dynamic).pressureAdvisory;
        case 'summary':
          return (obj as dynamic).summary;
        case 'sidewall':
          return (obj as dynamic).sidewall;
        case 'brand':
          return (obj as dynamic).brand;
        case 'model':
          return (obj as dynamic).model;
        case 'size':
          return (obj as dynamic).size;
        case 'width':
          return (obj as dynamic).width;
        case 'aspect_ratio':
          return (obj as dynamic).aspectRatio;
        case 'rim_diameter':
          return (obj as dynamic).rimDiameter;
        case 'load_index':
          return (obj as dynamic).loadIndex;
        case 'speed_rating':
          return (obj as dynamic).speedRating;
        case 'manufacturing_date':
          return (obj as dynamic).manufacturingDate;
        case 'sidewall_damage':
          return (obj as dynamic).sidewallDamage;
        case 'description':
          return (obj as dynamic).description;
        case 'confidence':
          return (obj as dynamic).confidence;
      }
    } catch (_) {}

    return null;
  }

  static String _dash(dynamic v) {
    final s = _str(v);
    return s.isEmpty ? 'N/A' : s;
  }

  static Future<pw.ImageProvider?> _localImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 115,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: _muted,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.trim().isEmpty ? 'N/A' : value.trim(),
              style: const pw.TextStyle(
                fontSize: 10,
                color: _text,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _imageBox(pw.ImageProvider? image) {
    return pw.Container(
      height: 115,
      decoration: pw.BoxDecoration(
        color: _softBg,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: image == null
          ? pw.Center(
              child: pw.Text(
                'No image',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
    );
  }

  static _PdfTyreData _tyreData({
    required String title,
    required dynamic side,
    required String imagePath,
    required bool isSidewall,
    required pw.ImageProvider? image,
  }) {
    final status = _str(_read(side, 'status')).isNotEmpty
        ? _str(_read(side, 'status'))
        : _str(_read(side, 'condition'));

    final pressure = _read(side, 'tire_pressure') ??
        _read(side, 'pressure_advisory') ??
        _read(side, 'pressure');

    final pressureStatus = _str(_read(pressure, 'status'));
    final pressureReason = _str(_read(pressure, 'reason'));
    final pressureConfidence = _str(_read(pressure, 'confidence'));

    final sidewall = _read(side, 'sidewall');
    final sidewallDamage = _read(sidewall, 'sidewall_damage');

    return _PdfTyreData(
      title: title,
      image: image,
      treadDepth: _str(_read(side, 'tread_depth')).isEmpty
          ? 'N/A'
          : '${_str(_read(side, 'tread_depth'))} mm',
      status: status.isEmpty ? 'N/A' : status,
      wearPatterns: _dash(_read(side, 'wear_patterns')),
      pressureStatus: pressureStatus.isEmpty ? 'N/A' : pressureStatus,
      pressureReason: pressureReason.isEmpty ? 'N/A' : pressureReason,
      pressureConfidence: pressureConfidence.isEmpty ? 'N/A' : pressureConfidence,
      summary: _dash(_read(side, 'summary')),
      isSidewall: isSidewall,
      sidewallIsTire: _dash(_read(sidewall, 'is_tire') ?? _read(side, 'is_tire')),
      brand: _dash(_read(sidewall, 'brand')),
      model: _dash(_read(sidewall, 'model')),
      size: _dash(_read(sidewall, 'size')),
      width: _dash(_read(sidewall, 'width')),
      aspectRatio: _dash(_read(sidewall, 'aspect_ratio')),
      rimDiameter: _dash(_read(sidewall, 'rim_diameter')),
      loadIndex: _dash(_read(sidewall, 'load_index')),
      speedRating: _dash(_read(sidewall, 'speed_rating')),
      manufacturingDate: _dash(_read(sidewall, 'manufacturing_date')),
      sidewallDamageStatus: _dash(_read(sidewallDamage, 'status')),
      sidewallDamageDescription: _dash(_read(sidewallDamage, 'description')),
      sidewallConfidence: _dash(_read(sidewall, 'confidence')),
    );
  }

  static pw.Widget _tyreTile(_PdfTyreData t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  t.title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _softBg,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  t.isSidewall ? 'Sidewall' : 'Tread',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _imageBox(t.image),
          pw.SizedBox(height: 10),
          _kv('Tread Depth', t.treadDepth),
          _kv('Status', t.status),
          _kv('Wear Patterns', t.wearPatterns),
          pw.Divider(color: _border),
          pw.Text(
            'Tire Pressure',
            style: pw.TextStyle(
              fontSize: 10.5,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          _kv('Status', t.pressureStatus),
          _kv('Reason', t.pressureReason),
          _kv('Confidence', t.pressureConfidence),
          if (t.isSidewall) ...[
            pw.Divider(color: _border),
            pw.Text(
              'Sidewall Details',
              style: pw.TextStyle(
                fontSize: 10.5,
                color: _text,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            _kv('Is Tire', t.sidewallIsTire),
            _kv('Brand', t.brand),
            _kv('Model', t.model),
            _kv('Size', t.size),
            _kv('Width', t.width),
            _kv('Aspect Ratio', t.aspectRatio),
            _kv('Rim Diameter', t.rimDiameter),
            _kv('Load Index', t.loadIndex),
            _kv('Speed Rating', t.speedRating),
            _kv('Manufacturing Date', t.manufacturingDate),
            _kv('Damage Status', t.sidewallDamageStatus),
            _kv('Damage Detail', t.sidewallDamageDescription),
            _kv('Confidence', t.sidewallConfidence),
          ],
          pw.Divider(color: _border),
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 10.5,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            t.summary,
            style: const pw.TextStyle(fontSize: 10, color: _text, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Future<List<int>> build({
    required String title,
    required String vehicleId,
    required String vin,
    required String vehicleType,
    required String frontTyreId,
    required String backTyreId,
    required String frontPath,
    required String frontSidewallPath,
    required String backPath,
    required String backSidewallPath,
    required dynamic data,
    required String message,
    required dynamic front,
    required dynamic back,
  }) async {
    final items = <_PdfTyreData>[
      _tyreData(
        title: 'Front Tread',
        side: front,
        imagePath: frontPath,
        isSidewall: false,
        image: await _localImage(frontPath),
      ),
      _tyreData(
        title: 'Front Sidewall',
        side: front,
        imagePath: frontSidewallPath,
        isSidewall: true,
        image: await _localImage(frontSidewallPath),
      ),
      _tyreData(
        title: 'Back Tread',
        side: back,
        imagePath: backPath,
        isSidewall: false,
        image: await _localImage(backPath),
      ),
      _tyreData(
        title: 'Back Sidewall',
        side: back,
        imagePath: backSidewallPath,
        isSidewall: true,
        image: await _localImage(backSidewallPath),
      ),
    ];

    final doc = pw.Document();

    void addTyrePage({
      required String pageTitle,
      required _PdfTyreData item,
      bool showHeader = false,
    }) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                pageTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),

              if (showHeader) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: _border),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Record ID', _dash(_read(data, 'record_id'))),
                      _kv('Vehicle ID', _dash(_read(data, 'vehicle_id')).isEmpty || _dash(_read(data, 'vehicle_id')) == 'N/A' ? _dash(vehicleId) : _dash(_read(data, 'vehicle_id'))),
                      _kv('VIN', _dash(_read(data, 'vin')).isEmpty || _dash(_read(data, 'vin')) == 'N/A' ? _dash(vin) : _dash(_read(data, 'vin'))),
                      _kv('Vehicle Type', _dash(_read(data, 'vehicle_type')).isEmpty || _dash(_read(data, 'vehicle_type')) == 'N/A' ? _dash(vehicleType.toUpperCase()) : _dash(_read(data, 'vehicle_type')).toUpperCase()),
                      _kv('Front Tire ID', _dash(frontTyreId)),
                      _kv('Back Tire ID', _dash(backTyreId)),
                      _kv('API Message', _dash(message)),
                      _kv('Generated At', DateTime.now().toString()),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 14),
              _tyreTile(item),

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Generated by TireTest AI',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report',
      item: items[0],
      showHeader: true,
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Front Sidewall',
      item: items[1],
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Back Tread',
      item: items[2],
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Back Sidewall',
      item: items[3],
    );

    return doc.save();
  }
}

class _PdfTyreData {
  const _PdfTyreData({
    required this.title,
    required this.image,
    required this.treadDepth,
    required this.status,
    required this.wearPatterns,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
    required this.isSidewall,
    required this.sidewallIsTire,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.sidewallDamageStatus,
    required this.sidewallDamageDescription,
    required this.sidewallConfidence,
  });

  final String title;
  final pw.ImageProvider? image;
  final String treadDepth;
  final String status;
  final String wearPatterns;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;
  final String summary;
  final bool isSidewall;

  final String sidewallIsTire;
  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String sidewallDamageStatus;
  final String sidewallDamageDescription;
  final String sidewallConfidence;
}

class _PdfActionDialog extends StatelessWidget {
  const _PdfActionDialog({
    required this.s,
    required this.onSave,
    required this.onShare,
  });

  final double s;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 300 * s,
            padding: EdgeInsets.fromLTRB(16 * s, 40 * s, 16 * s, 16 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18 * s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Report Ready',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 18 * s,
                    color: _Ui.ink,
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Save or share the inspection report as a PDF file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _Ui.subInk,
                    fontSize: 13.5 * s,
                    height: 1.35,
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.download_rounded, size: 23),
                    label: Text(
                      'Save PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF4F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * s),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 23),
                    label: Text(
                      'Share PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF4F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * s),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -26 * s,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 64 * s,
                height: 64 * s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _Ui.brandGrad,
                ),
                child: const Center(
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _ReportOverviewCard extends StatelessWidget {
  const _ReportOverviewCard({
    required this.s,
    required this.responseData,
    required this.responseMessage,
    required this.vehicleId,
    required this.vin,
    required this.vehicleType,
    required this.frontTyreId,
    required this.backTyreId,
  });

  final double s;
  final dynamic responseData;
  final String responseMessage;
  final String vehicleId;
  final String vin;
  final String vehicleType;
  final String frontTyreId;
  final String backTyreId;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRow('Record ID', _JsonValue.string(_JsonValue.read(responseData, 'record_id'))),
      _InfoRow('Vehicle ID', _JsonValue.string(_JsonValue.read(responseData, 'vehicle_id'), fallback: vehicleId)),
      _InfoRow('VIN', _JsonValue.string(_JsonValue.read(responseData, 'vin'), fallback: vin)),
      _InfoRow('Vehicle Type', _JsonValue.string(_JsonValue.read(responseData, 'vehicle_type'), fallback: vehicleType.toUpperCase())),
      _InfoRow('Front Tire ID', frontTyreId),
      _InfoRow('Back Tire ID', backTyreId),
      _InfoRow('API Message', responseMessage),
    ];

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            s: s,
            title: 'Report Details',
            icon: Icons.article_outlined,
          ),
          SizedBox(height: 12 * s),
          ...rows.map((r) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8 * s),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w800,
                        color: _Ui.subInk,
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    flex: 6,
                    child: Text(
                      r.value.trim().isEmpty ? 'N/A' : r.value.trim(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w900,
                        color: _Ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
  });

  final double s;
  final _BikeReportTab active;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;

  @override
  Widget build(BuildContext context) {
    final isFront =
        active == _BikeReportTab.frontTread || active == _BikeReportTab.frontSidewall;
    final isSidewall = active == _BikeReportTab.frontSidewall ||
        active == _BikeReportTab.backSidewall;

    final side = isFront ? front : back;

    if (side == null) {
      return _EmptyStateCardModern(
        s: s,
        title: "No ${isFront ? "front" : "back"} tyre data",
        subtitle: "Try scanning again.",
        onRetry: () => Navigator.of(context).pop(),
      );
    }

    final title = switch (active) {
      _BikeReportTab.frontTread => "Front Tread",
      _BikeReportTab.frontSidewall => "Front Sidewall",
      _BikeReportTab.backTread => "Back Tread",
      _BikeReportTab.backSidewall => "Back Sidewall",
    };

    final imagePath = switch (active) {
      _BikeReportTab.frontTread => frontPath,
      _BikeReportTab.frontSidewall => frontSidewallPath,
      _BikeReportTab.backTread => backPath,
      _BikeReportTab.backSidewall => backSidewallPath,
    };

    final t = _TyreUi.fromSide(
      title: title,
      side: side,
      localImagePath: imagePath,
      isSidewallTab: isSidewall,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TyreImageCardModern(
          s: s,
          title: t.title,
          imagePathOrUrl: t.imagePathOrUrl,
          badge: isSidewall ? "Sidewall" : "Tread",
          subtitle: t.conditionText.replaceFirst("Status:", "Status"),
        ),
        SizedBox(height: 12 * s),

        Row(
          children: [
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText,
                icon: Icons.straighten_rounded,
                minHeight: 178 * s,
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tire Pressure",
                value: t.pressureValueText,
                status: t.pressureStatusText,
                icon: Icons.speed_rounded,
                minHeight: 178 * s,
              ),
            ),
          ],
        ),

        SizedBox(height: 10 * s),

        _MetricCardModern(
          s: s,
          title: isSidewall ? "Sidewall Damage" : "Damage Check",
          value: isSidewall ? t.sidewallDamageDescription : t.wearPatternsText,
          status: isSidewall ? t.sidewallDamageStatus : t.damageStatusText,
          icon: Icons.report_gmailerrorred_rounded,
        ),

        if (isSidewall) ...[
          SizedBox(height: 10 * s),
          _SidewallDetailsCard(
            s: s,
            isTire: t.sidewallIsTire,
            brand: t.brand,
            model: t.model,
            size: t.size,
            width: t.width,
            aspectRatio: t.aspectRatio,
            rimDiameter: t.rimDiameter,
            loadIndex: t.loadIndex,
            speedRating: t.speedRating,
            manufacturingDate: t.manufacturingDate,
            damageStatus: t.sidewallDamageStatus,
            damageDescription: t.sidewallDamageDescription,
            confidence: t.sidewallConfidence,
          ),
        ],

        SizedBox(height: 10 * s),

        _SummaryCardModern(
          s: s,
          title: "Report Summary",
          summary: t.summaryText,
        ),
      ],
    );
  }
}

class _TyreUi {
  final String title;
  final String treadDepthText;
  final String conditionText;
  final String wearPatternsText;
  final String damageStatusText;
  final String summaryText;
  final String imagePathOrUrl;

  final String pressureValueText;
  final String pressureStatusText;
  final String pressureReasonText;
  final String pressureConfidenceText;

  final String sidewallIsTire;
  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String sidewallDamageStatus;
  final String sidewallDamageDescription;
  final String sidewallConfidence;

  const _TyreUi({
    required this.title,
    required this.treadDepthText,
    required this.conditionText,
    required this.wearPatternsText,
    required this.damageStatusText,
    required this.summaryText,
    required this.imagePathOrUrl,
    required this.pressureValueText,
    required this.pressureStatusText,
    required this.pressureReasonText,
    required this.pressureConfidenceText,
    required this.sidewallIsTire,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.sidewallDamageStatus,
    required this.sidewallDamageDescription,
    required this.sidewallConfidence,
  });

  factory _TyreUi.fromSide({
    required String title,
    required TwoWheelerTyreSide side,
    required String localImagePath,
    required bool isSidewallTab,
  }) {
    String str(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.toLowerCase() == 'null') return '';
      return s;
    }

    dynamic read(dynamic obj, String key) {
      if (obj == null) return null;

      if (obj is Map) {
        return obj[key];
      }

      try {
        final json = (obj as dynamic).toJson();
        if (json is Map) return json[key];
      } catch (_) {}

      try {
        switch (key) {
          case 'is_tire':
            return (obj as dynamic).isTire;
          case 'status':
            return (obj as dynamic).status;
          case 'condition':
            return (obj as dynamic).condition;
          case 'tread_depth':
            return (obj as dynamic).treadDepth;
          case 'wear_patterns':
            return (obj as dynamic).wearPatterns;
          case 'tire_pressure':
            return (obj as dynamic).tirePressure;
          case 'pressure':
            return (obj as dynamic).pressure;
          case 'pressure_advisory':
            return (obj as dynamic).pressureAdvisory;
          case 'summary':
            return (obj as dynamic).summary;
          case 'image':
            return (obj as dynamic).image;
          case 'sidewall':
            return (obj as dynamic).sidewall;
          case 'brand':
            return (obj as dynamic).brand;
          case 'model':
            return (obj as dynamic).model;
          case 'size':
            return (obj as dynamic).size;
          case 'width':
            return (obj as dynamic).width;
          case 'aspect_ratio':
            return (obj as dynamic).aspectRatio;
          case 'rim_diameter':
            return (obj as dynamic).rimDiameter;
          case 'load_index':
            return (obj as dynamic).loadIndex;
          case 'speed_rating':
            return (obj as dynamic).speedRating;
          case 'manufacturing_date':
            return (obj as dynamic).manufacturingDate;
          case 'sidewall_damage':
            return (obj as dynamic).sidewallDamage;
          case 'description':
            return (obj as dynamic).description;
          case 'confidence':
            return (obj as dynamic).confidence;
        }
      } catch (_) {}

      return null;
    }

    final dynamic dynSide = side;

    final isTireValue = read(dynSide, 'is_tire');
    final isTireFalse = isTireValue == false;

    final condition = str(read(dynSide, 'status')).isNotEmpty
        ? str(read(dynSide, 'status'))
        : str(read(dynSide, 'condition'));

    final treadRaw = read(dynSide, 'tread_depth');
    final tread = str(treadRaw);

    final pressure = read(dynSide, 'tire_pressure') ??
        read(dynSide, 'pressure_advisory') ??
        read(dynSide, 'pressure');

    final pressureStatus = str(read(pressure, 'status'));
    final pressureReason = str(read(pressure, 'reason'));
    final pressureConfidence = str(read(pressure, 'confidence'));

    final sidewall = read(dynSide, 'sidewall');
    final sidewallDamage = read(sidewall, 'sidewall_damage');

    final brand = str(read(sidewall, 'brand'));
    final model = str(read(sidewall, 'model'));
    final size = str(read(sidewall, 'size'));
    final width = str(read(sidewall, 'width'));
    final aspectRatio = str(read(sidewall, 'aspect_ratio'));
    final rimDiameter = str(read(sidewall, 'rim_diameter'));
    final loadIndex = str(read(sidewall, 'load_index'));
    final speedRating = str(read(sidewall, 'speed_rating'));
    final manufacturingDate = str(read(sidewall, 'manufacturing_date'));
    final swDamageStatus = str(read(sidewallDamage, 'status'));
    final swDamageDesc = str(read(sidewallDamage, 'description'));
    final swConfidence = str(read(sidewall, 'confidence'));

    final pressureLines = <String>[
      'Value: ${pressureStatus.isEmpty ? "N/A" : pressureStatus}',
      if (pressureReason.isNotEmpty) 'Reason: $pressureReason',
      if (pressureConfidence.isNotEmpty) 'Confidence: $pressureConfidence',
    ];

    String _dashForUi(dynamic v) {
      final value = str(v);
      return value.isEmpty ? 'N/A' : value;
    }

    return _TyreUi(
      title: title,
      treadDepthText: isTireFalse
          ? 'N/A'
          : tread.isEmpty
              ? 'N/A'
              : '$tread mm',
      conditionText: isTireFalse
          ? 'Status: Not a tyre'
          : condition.isEmpty
              ? 'Status: N/A'
              : 'Status: $condition',
      wearPatternsText: str(read(dynSide, 'wear_patterns')).isEmpty
          ? 'N/A'
          : str(read(dynSide, 'wear_patterns')),
      damageStatusText: isTireFalse
          ? 'Not a tyre'
          : condition.isEmpty
              ? 'N/A'
              : condition,
      summaryText: str(read(dynSide, 'summary')).isEmpty
          ? 'N/A'
          : str(read(dynSide, 'summary')),
      imagePathOrUrl: localImagePath,
      pressureValueText: pressureLines.join('\n'),
      pressureStatusText: pressureStatus.isEmpty ? 'N/A' : pressureStatus,
      pressureReasonText: pressureReason,
      pressureConfidenceText: pressureConfidence,
      sidewallIsTire: _dashForUi(read(sidewall, 'is_tire') ?? read(dynSide, 'is_tire')),
      brand: brand,
      model: model,
      size: size,
      width: width,
      aspectRatio: aspectRatio,
      rimDiameter: rimDiameter,
      loadIndex: loadIndex,
      speedRating: speedRating,
      manufacturingDate: manufacturingDate,
      sidewallDamageStatus: swDamageStatus.isEmpty ? 'N/A' : swDamageStatus,
      sidewallDamageDescription: swDamageDesc.isEmpty ? 'N/A' : swDamageDesc,
      sidewallConfidence: swConfidence,
    );
  }
}

class _FourImagePreviewRow extends StatelessWidget {
  const _FourImagePreviewRow({
    required this.s,
    required this.active,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
    required this.onSelect,
  });

  final double s;
  final _BikeReportTab active;
  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;
  final ValueChanged<_BikeReportTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _PreviewItem('Front Tread', frontPath, _BikeReportTab.frontTread),
      _PreviewItem('Front Sidewall', frontSidewallPath, _BikeReportTab.frontSidewall),
      _PreviewItem('Back Tread', backPath, _BikeReportTab.backTread),
      _PreviewItem('Back Sidewall', backSidewallPath, _BikeReportTab.backSidewall),
    ];

    return SizedBox(
      height: 160 * s,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 12 * s),
        itemBuilder: (_, i) {
          final item = items[i];
          final selected = active == item.tab;

          return GestureDetector(
            onTap: () => onSelect(item.tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 126 * s,
              padding: EdgeInsets.all(3 * s),
              decoration: BoxDecoration(
                gradient: selected ? _Ui.brandGrad : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(18 * s),
                border: Border.all(
                  color: selected ? Colors.transparent : _Ui.line,
                ),
                boxShadow: [_Ui.softShadow],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15 * s),
                      child: _SmartImage(pathOrUrl: item.path),
                    ),
                  ),
                  SizedBox(height: 7 * s),
                  Padding(
                    padding: EdgeInsets.only(bottom: 5 * s),
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 12.5 * s,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : _Ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.label, this.path, this.tab);

  final String label;
  final String path;
  final _BikeReportTab tab;
}

class _TabChips extends StatelessWidget {
  const _TabChips({
    required this.s,
    required this.active,
    required this.onSelect,
  });

  final double s;
  final _BikeReportTab active;
  final ValueChanged<_BikeReportTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ChipItem('Front Tread', _BikeReportTab.frontTread),
      _ChipItem('Front Sidewall', _BikeReportTab.frontSidewall),
      _ChipItem('Back Tread', _BikeReportTab.backTread),
      _ChipItem('Back Sidewall', _BikeReportTab.backSidewall),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final selected = active == item.tab;

          return Padding(
            padding: EdgeInsets.only(right: 10 * s),
            child: InkWell(
              onTap: () => onSelect(item.tab),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * s,
                  vertical: 10 * s,
                ),
                decoration: BoxDecoration(
                  gradient: selected ? _Ui.brandGrad : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? Colors.transparent : _Ui.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(selected ? .10 : .04),
                      blurRadius: selected ? 16 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : _Ui.subInk,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChipItem {
  const _ChipItem(this.label, this.tab);

  final String label;
  final _BikeReportTab tab;
}

class _SidewallDetailsCard extends StatelessWidget {
  const _SidewallDetailsCard({
    required this.s,
    required this.isTire,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.damageStatus,
    required this.damageDescription,
    required this.confidence,
  });

  final double s;
  final String isTire;
  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String damageStatus;
  final String damageDescription;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRow('Is Tire', isTire),
      _InfoRow('Brand', brand),
      _InfoRow('Model', model),
      _InfoRow('Size', size),
      _InfoRow('Width', width),
      _InfoRow('Aspect Ratio', aspectRatio),
      _InfoRow('Rim Diameter', rimDiameter),
      _InfoRow('Load Index', loadIndex),
      _InfoRow('Speed Rating', speedRating),
      _InfoRow('Manufacturing Date', manufacturingDate),
      _InfoRow('Damage Status', damageStatus),
      _InfoRow('Damage Detail', damageDescription),
      _InfoRow('Confidence', confidence),
    ];

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            s: s,
            title: 'Sidewall Details',
            icon: Icons.tire_repair_rounded,
          ),
          SizedBox(height: 12 * s),
          ...rows.map((r) {
            final value = r.value.trim().isEmpty ? 'N/A' : r.value.trim();
            return Padding(
              padding: EdgeInsets.only(bottom: 8 * s),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w800,
                        color: _Ui.subInk,
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    flex: 6,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w900,
                        color: _Ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}

class _TyreImageCardModern extends StatelessWidget {
  const _TyreImageCardModern({
    required this.s,
    required this.title,
    required this.imagePathOrUrl,
    required this.badge,
    this.subtitle,
  });

  final double s;
  final String title;
  final String imagePathOrUrl;
  final String badge;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s,
                  vertical: 6 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: _Ui.line),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w800,
                    color: _Ui.subInk,
                  ),
                ),
              ),
            ],
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w700,
                color: _Ui.subInk,
              ),
            ),
          ],
          SizedBox(height: 12 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * s),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SmartImage(pathOrUrl: imagePathOrUrl),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.04),
                            Colors.black.withOpacity(.20),
                          ],
                        ),
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

class _SmartImage extends StatelessWidget {
  const _SmartImage({required this.pathOrUrl});

  final String pathOrUrl;

  @override
  Widget build(BuildContext context) {
    final value = pathOrUrl.trim();

    if (value.isEmpty) {
      return _empty();
    }

    final file = File(value);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    if (value.startsWith("data:image")) {
      try {
        final comma = value.indexOf(',');
        final b64 = comma >= 0 ? value.substring(comma + 1) : value;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _broken();
      }
    }

    if (value.length > 100 && !value.contains(' ') && !value.startsWith('http')) {
      try {
        final bytes = base64Decode(value);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _broken(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF0F1F5),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }

    return _empty();
  }

  Widget _empty() {
    return Container(
      color: const Color(0xFFF0F1F5),
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }

  Widget _broken() {
    return Container(
      color: const Color(0xFFF0F1F5),
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    this.minHeight = 190,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeader(s: s, title: title, icon: icon),
          SizedBox(height: 12 * s),
          Text(
            v,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.2 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),
          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCardModern extends StatelessWidget {
  const _MetricCardModern({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(s: s, title: title, icon: icon),
          SizedBox(height: 12 * s),
          Text(
            v,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),
          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.s,
    required this.title,
    required this.icon,
  });

  final double s;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34 * s,
          height: 34 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * s),
            gradient: _Ui.brandGrad,
          ),
          child: Icon(icon, size: 18 * s, color: Colors.white),
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              color: _Ui.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCardModern extends StatelessWidget {
  const _SummaryCardModern({
    required this.s,
    required this.title,
    required this.summary,
  });

  final double s;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            s: s,
            title: title,
            icon: Icons.assignment_outlined,
          ),
          SizedBox(height: 12 * s),
          Text(
            summary.trim().isEmpty ? "N/A" : summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.s, required this.text});

  final double s;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: _Ui.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * s,
            height: 8 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Ui.brandGrad,
            ),
          ),
          SizedBox(width: 8 * s),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w800,
                color: _Ui.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarModern extends StatelessWidget {
  const _TopBarModern({
    required this.s,
    required this.title,
    required this.onBack,
    required this.onShare,
  });

  final double s;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 6 * s),
      child: Row(
        children: [
          _IconPill(s: s, icon: Icons.chevron_left_rounded, onTap: onBack),
          SizedBox(width: 10 * s),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 20.5 * s,
                fontWeight: FontWeight.w900,
                color: _Ui.ink,
              ),
            ),
          ),
          SizedBox(width: 10 * s),
          _IconPill(s: s, icon: Icons.ios_share_rounded, onTap: onShare),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.s,
    required this.icon,
    required this.onTap,
  });

  final double s;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      borderRadius: BorderRadius.circular(14 * s),
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * s),
        onTap: onTap,
        child: Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: _Ui.line),
          ),
          child: Icon(icon, size: 28 * s, color: _Ui.ink),
        ),
      ),
    );
  }
}

class _EmptyStateCardModern extends StatelessWidget {
  const _EmptyStateCardModern({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final double s;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 17 * s,
              fontWeight: FontWeight.w900,
              color: _Ui.ink,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: _Ui.subInk,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14 * s),
          _PrimaryButton(s: s, text: "Retry", onTap: onRetry),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.s,
    required this.text,
    required this.onTap,
  });

  final double s;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          gradient: _Ui.brandGrad,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GradDot extends StatelessWidget {
  const _GradDot({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * s,
      height: 12 * s,
      decoration: const BoxDecoration(
        gradient: _Ui.brandGrad,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GeneratingOverlayModern extends StatelessWidget {
  const _GeneratingOverlayModern({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.40),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

class _ThemedScanFailedView extends StatelessWidget {
  const _ThemedScanFailedView({
    required this.s,
    required this.message,
    required this.gradient,
    required this.onRetake,
    required this.onRetry,
  });

  final double s;
  final String message;
  final LinearGradient gradient;
  final VoidCallback onRetake;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16 * s),
            child: Container(
              padding: EdgeInsets.all(18 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20 * s),
                boxShadow: [_Ui.softShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64 * s,
                    height: 64 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 34 * s,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    'Scan Failed',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18 * s,
                      fontWeight: FontWeight.w900,
                      color: _Ui.ink,
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.8 * s,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: _Ui.subInk,
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          s: s,
                          label: 'Retake Images',
                          icon: Icons.refresh_rounded,
                          onTap: onRetake,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: _GradientButton(
                          s: s,
                          label: 'Retry',
                          icon: Icons.restart_alt_rounded,
                          gradient: gradient,
                          onTap: onRetry,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14 * s),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: Colors.white),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: _Ui.ink),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: _Ui.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ui {
  static const Color ink = Color(0xFF111827);
  static const Color subInk = Color(0xFF6B7280);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE8EAF0);

  static const LinearGradient brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxShadow softShadow = BoxShadow(
    color: Colors.black.withOpacity(.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  static BoxDecoration cardDeco(double r) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: line),
        boxShadow: [softShadow],
      );
}



/*

enum _BikeReportTab {
  frontTread,
  frontSidewall,
  backTread,
  backSidewall,
}

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Inspection Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState
    extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;
  bool _navigated = false;

  _BikeReportTab _active = _BikeReportTab.frontTread;

  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(
          AdsFetchRequested(token: widget.token, silent: true),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;

    if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tyre ids. Save preferences again.')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          UploadTwoWheelerRequested(
            userId: widget.userId,
            vehicleId: widget.vehicleId,
            token: widget.token,
            vin: widget.vin,
            vehicleType: widget.vehicleType,
            frontPath: widget.frontPath,
            frontSidewallPath: widget.frontSidewallPath,
            backPath: widget.backPath,
            backSidewallPath: widget.backSidewallPath,
            frontTyreId: widget.frontTyreId,
            backTyreId: widget.backTyreId,
          ),
        );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentVideoUrl == u && _videoCtrl != null) return;

    _currentVideoUrl = u;

    try {
      final old = _videoCtrl;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));

      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() => _videoCtrl = ctrl);
      await old?.dispose();
    } catch (_) {}
  }

  void _stopVideo() {
  final vc = _videoCtrl;
  _videoCtrl = null;
  _currentVideoUrl = '';
  _adPlayStarted = false;
  vc?.dispose();
}

String _safePdfName() {
  final vin = widget.vin.trim().isEmpty ? 'bike_report' : widget.vin.trim();
  final safeVin = vin.replaceAll(RegExp(r'[^\w\-]+'), '_');
  final time = DateTime.now().millisecondsSinceEpoch;
  return 'Bike_Tyre_Report_${safeVin}_$time.pdf';
}

// String _safePdfName() {
//   final vin = widget.vin.trim().isEmpty ? 'bike_report' : widget.vin.trim();
//   final safeVin = vin.replaceAll(RegExp(r'[^\w\-]+'), '_');
//   return 'Bike_Tyre_Report_$safeVin.pdf';
// }

Future<File> _createReportPdfFile({required bool temporary}) async {
  final state = context.read<AuthBloc>().state;
  final data = state.twoWheelerResponse?.data;

  final baseDir = temporary
      ? await getTemporaryDirectory()
      : await getApplicationDocumentsDirectory();

  final reportDir = Directory('${baseDir.path}/Reports');
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }

  final file = File('${reportDir.path}/${_safePdfName()}');

  final bytes = await _TwoWheelerPdfReport.build(
    title: widget.title,
    vehicleId: widget.vehicleId,
    vin: widget.vin,
    vehicleType: widget.vehicleType,
    frontTyreId: widget.frontTyreId,
    backTyreId: widget.backTyreId,
    frontPath: widget.frontPath,
    frontSidewallPath: widget.frontSidewallPath,
    backPath: widget.backPath,
    backSidewallPath: widget.backSidewallPath,
    front: data?.front,
    back: data?.back,
  );

  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> _saveReportPdf() async {
  try {
    final file = await _createReportPdfFile(temporary: false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved: ${file.path.split('/').last}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF save failed: $e')),
    );
  }
}

Future<void> _shareReportPdf() async {
  try {
    final file = await _createReportPdfFile(temporary: true);
    if (!mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bike Tire Inspection Report',
      subject: 'Bike Tire Inspection Report',
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF share failed: $e')),
    );
  }
}

Future<void> _shareReport() async {
  final s = MediaQuery.sizeOf(context).width / 390.0;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: _PdfActionDialog(
          s: s,
          onSave: () async {
            Navigator.of(context).pop();
            await _saveReportPdf();
          },
          onShare: () async {
            Navigator.of(context).pop();
            await _shareReportPdf();
          },
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

  // void _stopVideo() {
  //   final vc = _videoCtrl;
  //   _videoCtrl = null;
  //   _currentVideoUrl = '';
  //   _adPlayStarted = false;
  //   vc?.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F8FC), Color(0xFFF3F4F7)],
            ),
          ),
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (p, c) =>
                    p.selectedAd?.media != c.selectedAd?.media ||
                    p.adsStatus != c.adsStatus ||
                    p.twoWheelerStatus != c.twoWheelerStatus,
                listener: (context, state) {
                  final isLoading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
  final media = state.selectedAd?.media.trim() ?? '';

  if (isLoading && media.isNotEmpty && !_adPlayStarted) {
    _adPlayStarted = true;
    _playVideo(media);
  }

  // ✅ IMPORTANT FIX: stop ad video/audio as soon as report is ready or failed
  if (state.twoWheelerStatus == TwoWheelerStatus.success ||
      state.twoWheelerStatus == TwoWheelerStatus.failure) {
    _stopVideo();
  }

  if (state.twoWheelerStatus == TwoWheelerStatus.success) {
    context.read<AuthBloc>().add(
      FetchTyreHistoryRequested(
        userId: widget.userId,
        vehicleId: "ALL",
      ),
    );
  }
                  // if (state.twoWheelerStatus == TwoWheelerStatus.success) {
                  //   context.read<AuthBloc>().add(
                  //         FetchTyreHistoryRequested(
                  //           userId: widget.userId,
                  //           vehicleId: "ALL",
                  //         ),
                  //       );
                  // }

                  // final isLoading =
                  //     state.twoWheelerStatus == TwoWheelerStatus.uploading;
                  // final media = state.selectedAd?.media.trim() ?? '';

                  // if (isLoading && media.isNotEmpty && !_adPlayStarted) {
                  //   _adPlayStarted = true;
                  //   _playVideo(media);
                  // }

                  // if (!isLoading) {
                  //   _stopVideo();
                  // }
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (p, c) =>
                  p.twoWheelerStatus != c.twoWheelerStatus ||
                  p.twoWheelerResponse != c.twoWheelerResponse,
              builder: (context, state) {
                final st = state.twoWheelerStatus;
                final loading = st == TwoWheelerStatus.uploading;

                if (st == TwoWheelerStatus.failure) {
                  final msg = state.twoWheelerError.trim().isEmpty
                      ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                      : state.twoWheelerError.trim();

                  return _ThemedScanFailedView(
                    s: s,
                    message: msg,
                    gradient: _Ui.brandGrad,
                    onRetake: () {
                      if (_navigated) return;
                      _navigated = true;
                      Navigator.of(context).pop('retake');
                    },
                    onRetry: () {
                      if (_navigated) return;
                      setState(() => _dispatched = false);
                      _upload();
                    },
                  );
                }

                if (loading) {
                  return Stack(
                    children: [
                      _FullscreenVideoOnly(controller: _videoCtrl),
                      Positioned(
                        left: 16 * s,
                        right: 16 * s,
                        bottom: 22 * s,
                        child: _GeneratingOverlayModern(s: s),
                      ),
                    ],
                  );
                }

                final resp = state.twoWheelerResponse;
                final data = resp?.data;
                final front = data?.front;
                final back = data?.back;
                final hasAny = front != null || back != null;

                return Column(
                  children: [
                    _TopBarModern(
                      s: s,
                      title: widget.title,
                      onBack: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false,
                        );
                      },
                      onShare: _shareReport,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16 * s,
                          10 * s,
                          16 * s,
                          20 * s,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!loading && resp == null)
                              _EmptyStateCardModern(
                                s: s,
                                title: "No report yet",
                                subtitle:
                                    "Tap retry to generate the bike report again.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),

                            if (!loading && resp != null && !hasAny)
                              _EmptyStateCardModern(
                                s: s,
                                title: "No data found",
                                subtitle:
                                    "Upload succeeded but front/back data is missing.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),

                            if (hasAny) ...[
                              _FourImagePreviewRow(
                                s: s,
                                active: _active,
                                frontPath: widget.frontPath,
                                frontSidewallPath: widget.frontSidewallPath,
                                backPath: widget.backPath,
                                backSidewallPath: widget.backSidewallPath,
                                onSelect: (tab) => setState(() => _active = tab),
                              ),
                              SizedBox(height: 12 * s),
                              _TabChips(
                                s: s,
                                active: _active,
                                onSelect: (tab) => setState(() => _active = tab),
                              ),
                              SizedBox(height: 12 * s),
                              _TyreReportSection(
                                s: s,
                                active: _active,
                                front: front,
                                back: back,
                                frontPath: widget.frontPath,
                                frontSidewallPath: widget.frontSidewallPath,
                                backPath: widget.backPath,
                                backSidewallPath: widget.backSidewallPath,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


class _TwoWheelerPdfReport {
  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _softBg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _blue = PdfColor.fromInt(0xFF4F7BFF);

  static String _str(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.toLowerCase() == 'null') return '';
    return s;
  }

  static dynamic _read(dynamic obj, String key) {
    if (obj == null) return null;

    if (obj is Map) return obj[key];

    try {
      final json = (obj as dynamic).toJson();
      if (json is Map) return json[key];
    } catch (_) {}

    try {
      switch (key) {
        case 'is_tire':
          return (obj as dynamic).isTire;
        case 'status':
          return (obj as dynamic).status;
        case 'condition':
          return (obj as dynamic).condition;
        case 'tread_depth':
          return (obj as dynamic).treadDepth;
        case 'wear_patterns':
          return (obj as dynamic).wearPatterns;
        case 'tire_pressure':
          return (obj as dynamic).tirePressure;
        case 'pressure':
          return (obj as dynamic).pressure;
        case 'pressure_advisory':
          return (obj as dynamic).pressureAdvisory;
        case 'summary':
          return (obj as dynamic).summary;
        case 'sidewall':
          return (obj as dynamic).sidewall;
        case 'brand':
          return (obj as dynamic).brand;
        case 'model':
          return (obj as dynamic).model;
        case 'size':
          return (obj as dynamic).size;
        case 'width':
          return (obj as dynamic).width;
        case 'aspect_ratio':
          return (obj as dynamic).aspectRatio;
        case 'rim_diameter':
          return (obj as dynamic).rimDiameter;
        case 'load_index':
          return (obj as dynamic).loadIndex;
        case 'speed_rating':
          return (obj as dynamic).speedRating;
        case 'manufacturing_date':
          return (obj as dynamic).manufacturingDate;
        case 'sidewall_damage':
          return (obj as dynamic).sidewallDamage;
        case 'description':
          return (obj as dynamic).description;
        case 'confidence':
          return (obj as dynamic).confidence;
      }
    } catch (_) {}

    return null;
  }

  static String _dash(dynamic v) {
    final s = _str(v);
    return s.isEmpty ? 'N/A' : s;
  }

  static Future<pw.ImageProvider?> _localImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 115,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: _muted,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.trim().isEmpty ? 'N/A' : value.trim(),
              style: const pw.TextStyle(
                fontSize: 10,
                color: _text,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _imageBox(pw.ImageProvider? image) {
    return pw.Container(
      height: 115,
      decoration: pw.BoxDecoration(
        color: _softBg,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: image == null
          ? pw.Center(
              child: pw.Text(
                'No image',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
    );
  }

  static _PdfTyreData _tyreData({
    required String title,
    required dynamic side,
    required String imagePath,
    required bool isSidewall,
    required pw.ImageProvider? image,
  }) {
    final status = _str(_read(side, 'status')).isNotEmpty
        ? _str(_read(side, 'status'))
        : _str(_read(side, 'condition'));

    final pressure = _read(side, 'tire_pressure') ??
        _read(side, 'pressure_advisory') ??
        _read(side, 'pressure');

    final pressureStatus = _str(_read(pressure, 'status'));
    final pressureReason = _str(_read(pressure, 'reason'));
    final pressureConfidence = _str(_read(pressure, 'confidence'));

    final sidewall = _read(side, 'sidewall');
    final sidewallDamage = _read(sidewall, 'sidewall_damage');

    return _PdfTyreData(
      title: title,
      image: image,
      treadDepth: _str(_read(side, 'tread_depth')).isEmpty
          ? 'N/A'
          : '${_str(_read(side, 'tread_depth'))} mm',
      status: status.isEmpty ? 'N/A' : status,
      wearPatterns: _dash(_read(side, 'wear_patterns')),
      pressureStatus: pressureStatus.isEmpty ? 'N/A' : pressureStatus,
      pressureReason: pressureReason.isEmpty ? 'N/A' : pressureReason,
      pressureConfidence: pressureConfidence.isEmpty ? 'N/A' : pressureConfidence,
      summary: _dash(_read(side, 'summary')),
      isSidewall: isSidewall,
      brand: _dash(_read(sidewall, 'brand')),
      model: _dash(_read(sidewall, 'model')),
      size: _dash(_read(sidewall, 'size')),
      width: _dash(_read(sidewall, 'width')),
      aspectRatio: _dash(_read(sidewall, 'aspect_ratio')),
      rimDiameter: _dash(_read(sidewall, 'rim_diameter')),
      loadIndex: _dash(_read(sidewall, 'load_index')),
      speedRating: _dash(_read(sidewall, 'speed_rating')),
      manufacturingDate: _dash(_read(sidewall, 'manufacturing_date')),
      sidewallDamageStatus: _dash(_read(sidewallDamage, 'status')),
      sidewallDamageDescription: _dash(_read(sidewallDamage, 'description')),
      sidewallConfidence: _dash(_read(sidewall, 'confidence')),
    );
  }

  static pw.Widget _tyreTile(_PdfTyreData t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  t.title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _softBg,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  t.isSidewall ? 'Sidewall' : 'Tread',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _imageBox(t.image),
          pw.SizedBox(height: 10),
          _kv('Tread Depth', t.treadDepth),
          _kv('Status', t.status),
          _kv('Wear Patterns', t.wearPatterns),
          pw.Divider(color: _border),
          pw.Text(
            'Tire Pressure',
            style: pw.TextStyle(
              fontSize: 10.5,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          _kv('Status', t.pressureStatus),
          _kv('Reason', t.pressureReason),
          _kv('Confidence', t.pressureConfidence),
          if (t.isSidewall) ...[
            pw.Divider(color: _border),
            pw.Text(
              'Sidewall Details',
              style: pw.TextStyle(
                fontSize: 10.5,
                color: _text,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            _kv('Brand', t.brand),
            _kv('Model', t.model),
            _kv('Size', t.size),
            _kv('Width', t.width),
            _kv('Aspect Ratio', t.aspectRatio),
            _kv('Rim Diameter', t.rimDiameter),
            _kv('Load Index', t.loadIndex),
            _kv('Speed Rating', t.speedRating),
            _kv('Manufacturing Date', t.manufacturingDate),
            _kv('Damage Status', t.sidewallDamageStatus),
            _kv('Damage Detail', t.sidewallDamageDescription),
            _kv('Confidence', t.sidewallConfidence),
          ],
          pw.Divider(color: _border),
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 10.5,
              color: _text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            t.summary,
            style: const pw.TextStyle(fontSize: 10, color: _text, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Future<List<int>> build({
    required String title,
    required String vehicleId,
    required String vin,
    required String vehicleType,
    required String frontTyreId,
    required String backTyreId,
    required String frontPath,
    required String frontSidewallPath,
    required String backPath,
    required String backSidewallPath,
    required dynamic front,
    required dynamic back,
  }) async {
    final items = <_PdfTyreData>[
      _tyreData(
        title: 'Front Tread',
        side: front,
        imagePath: frontPath,
        isSidewall: false,
        image: await _localImage(frontPath),
      ),
      _tyreData(
        title: 'Front Sidewall',
        side: front,
        imagePath: frontSidewallPath,
        isSidewall: true,
        image: await _localImage(frontSidewallPath),
      ),
      _tyreData(
        title: 'Back Tread',
        side: back,
        imagePath: backPath,
        isSidewall: false,
        image: await _localImage(backPath),
      ),
      _tyreData(
        title: 'Back Sidewall',
        side: back,
        imagePath: backSidewallPath,
        isSidewall: true,
        image: await _localImage(backSidewallPath),
      ),
    ];

    final doc = pw.Document();

    void addTyrePage({
      required String pageTitle,
      required _PdfTyreData item,
      bool showHeader = false,
    }) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                pageTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),

              if (showHeader) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: _border),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Vehicle ID', _dash(vehicleId)),
                      _kv('VIN', _dash(vin)),
                      _kv('Vehicle Type', _dash(vehicleType.toUpperCase())),
                      _kv('Front Tire ID', _dash(frontTyreId)),
                      _kv('Back Tire ID', _dash(backTyreId)),
                      _kv('Generated At', DateTime.now().toString()),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 14),
              _tyreTile(item),

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Generated by TireTest AI',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report',
      item: items[0],
      showHeader: true,
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Front Sidewall',
      item: items[1],
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Back Tread',
      item: items[2],
    );

    addTyrePage(
      pageTitle: 'Bike Tire Inspection Report - Back Sidewall',
      item: items[3],
    );

    return doc.save();
  }
}

class _PdfTyreData {
  const _PdfTyreData({
    required this.title,
    required this.image,
    required this.treadDepth,
    required this.status,
    required this.wearPatterns,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
    required this.isSidewall,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.sidewallDamageStatus,
    required this.sidewallDamageDescription,
    required this.sidewallConfidence,
  });

  final String title;
  final pw.ImageProvider? image;
  final String treadDepth;
  final String status;
  final String wearPatterns;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;
  final String summary;
  final bool isSidewall;

  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String sidewallDamageStatus;
  final String sidewallDamageDescription;
  final String sidewallConfidence;
}

class _PdfActionDialog extends StatelessWidget {
  const _PdfActionDialog({
    required this.s,
    required this.onSave,
    required this.onShare,
  });

  final double s;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 300 * s,
            padding: EdgeInsets.fromLTRB(16 * s, 40 * s, 16 * s, 16 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18 * s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Report Ready',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 18 * s,
                    color: _Ui.ink,
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Save or share the inspection report as a PDF file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _Ui.subInk,
                    fontSize: 13.5 * s,
                    height: 1.35,
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.download_rounded, size: 23),
                    label: Text(
                      'Save PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF4F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * s),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 23),
                    label: Text(
                      'Share PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF4F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * s),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -26 * s,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 64 * s,
                height: 64 * s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _Ui.brandGrad,
                ),
                child: const Center(
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
  });

  final double s;
  final _BikeReportTab active;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;

  @override
  Widget build(BuildContext context) {
    final isFront =
        active == _BikeReportTab.frontTread || active == _BikeReportTab.frontSidewall;
    final isSidewall = active == _BikeReportTab.frontSidewall ||
        active == _BikeReportTab.backSidewall;

    final side = isFront ? front : back;

    if (side == null) {
      return _EmptyStateCardModern(
        s: s,
        title: "No ${isFront ? "front" : "back"} tyre data",
        subtitle: "Try scanning again.",
        onRetry: () => Navigator.of(context).pop(),
      );
    }

    final title = switch (active) {
      _BikeReportTab.frontTread => "Front Tread",
      _BikeReportTab.frontSidewall => "Front Sidewall",
      _BikeReportTab.backTread => "Back Tread",
      _BikeReportTab.backSidewall => "Back Sidewall",
    };

    final imagePath = switch (active) {
      _BikeReportTab.frontTread => frontPath,
      _BikeReportTab.frontSidewall => frontSidewallPath,
      _BikeReportTab.backTread => backPath,
      _BikeReportTab.backSidewall => backSidewallPath,
    };

    final t = _TyreUi.fromSide(
      title: title,
      side: side,
      localImagePath: imagePath,
      isSidewallTab: isSidewall,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TyreImageCardModern(
          s: s,
          title: t.title,
          imagePathOrUrl: t.imagePathOrUrl,
          badge: isSidewall ? "Sidewall" : "Tread",
          subtitle: t.conditionText.replaceFirst("Status:", "Status"),
        ),
        SizedBox(height: 12 * s),

        Row(
          children: [
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText,
                icon: Icons.straighten_rounded,
                minHeight: 178 * s,
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tire Pressure",
                value: t.pressureValueText,
                status: t.pressureStatusText,
                icon: Icons.speed_rounded,
                minHeight: 178 * s,
              ),
            ),
          ],
        ),

        SizedBox(height: 10 * s),

        _MetricCardModern(
          s: s,
          title: isSidewall ? "Sidewall Damage" : "Damage Check",
          value: isSidewall ? t.sidewallDamageDescription : t.wearPatternsText,
          status: isSidewall ? t.sidewallDamageStatus : t.damageStatusText,
          icon: Icons.report_gmailerrorred_rounded,
        ),

        if (isSidewall) ...[
          SizedBox(height: 10 * s),
          _SidewallDetailsCard(
            s: s,
            brand: t.brand,
            model: t.model,
            size: t.size,
            width: t.width,
            aspectRatio: t.aspectRatio,
            rimDiameter: t.rimDiameter,
            loadIndex: t.loadIndex,
            speedRating: t.speedRating,
            manufacturingDate: t.manufacturingDate,
            confidence: t.sidewallConfidence,
          ),
        ],

        SizedBox(height: 10 * s),

        _SummaryCardModern(
          s: s,
          title: "Report Summary",
          summary: t.summaryText,
        ),
      ],
    );
  }
}

class _TyreUi {
  final String title;
  final String treadDepthText;
  final String conditionText;
  final String wearPatternsText;
  final String damageStatusText;
  final String summaryText;
  final String imagePathOrUrl;

  final String pressureValueText;
  final String pressureStatusText;
  final String pressureReasonText;
  final String pressureConfidenceText;

  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String sidewallDamageStatus;
  final String sidewallDamageDescription;
  final String sidewallConfidence;

  const _TyreUi({
    required this.title,
    required this.treadDepthText,
    required this.conditionText,
    required this.wearPatternsText,
    required this.damageStatusText,
    required this.summaryText,
    required this.imagePathOrUrl,
    required this.pressureValueText,
    required this.pressureStatusText,
    required this.pressureReasonText,
    required this.pressureConfidenceText,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.sidewallDamageStatus,
    required this.sidewallDamageDescription,
    required this.sidewallConfidence,
  });

  factory _TyreUi.fromSide({
    required String title,
    required TwoWheelerTyreSide side,
    required String localImagePath,
    required bool isSidewallTab,
  }) {
    String str(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.toLowerCase() == 'null') return '';
      return s;
    }

    dynamic read(dynamic obj, String key) {
      if (obj == null) return null;

      if (obj is Map) {
        return obj[key];
      }

      try {
        final json = (obj as dynamic).toJson();
        if (json is Map) return json[key];
      } catch (_) {}

      try {
        switch (key) {
          case 'is_tire':
            return (obj as dynamic).isTire;
          case 'status':
            return (obj as dynamic).status;
          case 'condition':
            return (obj as dynamic).condition;
          case 'tread_depth':
            return (obj as dynamic).treadDepth;
          case 'wear_patterns':
            return (obj as dynamic).wearPatterns;
          case 'tire_pressure':
            return (obj as dynamic).tirePressure;
          case 'pressure':
            return (obj as dynamic).pressure;
          case 'pressure_advisory':
            return (obj as dynamic).pressureAdvisory;
          case 'summary':
            return (obj as dynamic).summary;
          case 'image':
            return (obj as dynamic).image;
          case 'sidewall':
            return (obj as dynamic).sidewall;
          case 'brand':
            return (obj as dynamic).brand;
          case 'model':
            return (obj as dynamic).model;
          case 'size':
            return (obj as dynamic).size;
          case 'width':
            return (obj as dynamic).width;
          case 'aspect_ratio':
            return (obj as dynamic).aspectRatio;
          case 'rim_diameter':
            return (obj as dynamic).rimDiameter;
          case 'load_index':
            return (obj as dynamic).loadIndex;
          case 'speed_rating':
            return (obj as dynamic).speedRating;
          case 'manufacturing_date':
            return (obj as dynamic).manufacturingDate;
          case 'sidewall_damage':
            return (obj as dynamic).sidewallDamage;
          case 'description':
            return (obj as dynamic).description;
          case 'confidence':
            return (obj as dynamic).confidence;
        }
      } catch (_) {}

      return null;
    }

    final dynamic dynSide = side;

    final isTireValue = read(dynSide, 'is_tire');
    final isTireFalse = isTireValue == false;

    final condition = str(read(dynSide, 'status')).isNotEmpty
        ? str(read(dynSide, 'status'))
        : str(read(dynSide, 'condition'));

    final treadRaw = read(dynSide, 'tread_depth');
    final tread = str(treadRaw);

    final pressure = read(dynSide, 'tire_pressure') ??
        read(dynSide, 'pressure_advisory') ??
        read(dynSide, 'pressure');

    final pressureStatus = str(read(pressure, 'status'));
    final pressureReason = str(read(pressure, 'reason'));
    final pressureConfidence = str(read(pressure, 'confidence'));

    final sidewall = read(dynSide, 'sidewall');
    final sidewallDamage = read(sidewall, 'sidewall_damage');

    final brand = str(read(sidewall, 'brand'));
    final model = str(read(sidewall, 'model'));
    final size = str(read(sidewall, 'size'));
    final width = str(read(sidewall, 'width'));
    final aspectRatio = str(read(sidewall, 'aspect_ratio'));
    final rimDiameter = str(read(sidewall, 'rim_diameter'));
    final loadIndex = str(read(sidewall, 'load_index'));
    final speedRating = str(read(sidewall, 'speed_rating'));
    final manufacturingDate = str(read(sidewall, 'manufacturing_date'));
    final swDamageStatus = str(read(sidewallDamage, 'status'));
    final swDamageDesc = str(read(sidewallDamage, 'description'));
    final swConfidence = str(read(sidewall, 'confidence'));

    final pressureLines = <String>[
      'Value: ${pressureStatus.isEmpty ? "N/A" : pressureStatus}',
      if (pressureReason.isNotEmpty) 'Reason: $pressureReason',
      if (pressureConfidence.isNotEmpty) 'Confidence: $pressureConfidence',
    ];

    return _TyreUi(
      title: title,
      treadDepthText: isTireFalse
          ? 'N/A'
          : tread.isEmpty
              ? 'N/A'
              : '$tread mm',
      conditionText: isTireFalse
          ? 'Status: Not a tyre'
          : condition.isEmpty
              ? 'Status: N/A'
              : 'Status: $condition',
      wearPatternsText: str(read(dynSide, 'wear_patterns')).isEmpty
          ? 'N/A'
          : str(read(dynSide, 'wear_patterns')),
      damageStatusText: isTireFalse
          ? 'Not a tyre'
          : condition.isEmpty
              ? 'N/A'
              : condition,
      summaryText: str(read(dynSide, 'summary')).isEmpty
          ? 'N/A'
          : str(read(dynSide, 'summary')),
      imagePathOrUrl: localImagePath,
      pressureValueText: pressureLines.join('\n'),
      pressureStatusText: pressureStatus.isEmpty ? 'N/A' : pressureStatus,
      pressureReasonText: pressureReason,
      pressureConfidenceText: pressureConfidence,
      brand: brand,
      model: model,
      size: size,
      width: width,
      aspectRatio: aspectRatio,
      rimDiameter: rimDiameter,
      loadIndex: loadIndex,
      speedRating: speedRating,
      manufacturingDate: manufacturingDate,
      sidewallDamageStatus: swDamageStatus.isEmpty ? 'N/A' : swDamageStatus,
      sidewallDamageDescription: swDamageDesc.isEmpty ? 'N/A' : swDamageDesc,
      sidewallConfidence: swConfidence,
    );
  }
}

class _FourImagePreviewRow extends StatelessWidget {
  const _FourImagePreviewRow({
    required this.s,
    required this.active,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
    required this.onSelect,
  });

  final double s;
  final _BikeReportTab active;
  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;
  final ValueChanged<_BikeReportTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _PreviewItem('Front Tread', frontPath, _BikeReportTab.frontTread),
      _PreviewItem('Front Sidewall', frontSidewallPath, _BikeReportTab.frontSidewall),
      _PreviewItem('Back Tread', backPath, _BikeReportTab.backTread),
      _PreviewItem('Back Sidewall', backSidewallPath, _BikeReportTab.backSidewall),
    ];

    return SizedBox(
      height: 160 * s,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 12 * s),
        itemBuilder: (_, i) {
          final item = items[i];
          final selected = active == item.tab;

          return GestureDetector(
            onTap: () => onSelect(item.tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 126 * s,
              padding: EdgeInsets.all(3 * s),
              decoration: BoxDecoration(
                gradient: selected ? _Ui.brandGrad : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(18 * s),
                border: Border.all(
                  color: selected ? Colors.transparent : _Ui.line,
                ),
                boxShadow: [_Ui.softShadow],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15 * s),
                      child: _SmartImage(pathOrUrl: item.path),
                    ),
                  ),
                  SizedBox(height: 7 * s),
                  Padding(
                    padding: EdgeInsets.only(bottom: 5 * s),
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 12.5 * s,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : _Ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.label, this.path, this.tab);

  final String label;
  final String path;
  final _BikeReportTab tab;
}

class _TabChips extends StatelessWidget {
  const _TabChips({
    required this.s,
    required this.active,
    required this.onSelect,
  });

  final double s;
  final _BikeReportTab active;
  final ValueChanged<_BikeReportTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ChipItem('Front Tread', _BikeReportTab.frontTread),
      _ChipItem('Front Sidewall', _BikeReportTab.frontSidewall),
      _ChipItem('Back Tread', _BikeReportTab.backTread),
      _ChipItem('Back Sidewall', _BikeReportTab.backSidewall),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final selected = active == item.tab;

          return Padding(
            padding: EdgeInsets.only(right: 10 * s),
            child: InkWell(
              onTap: () => onSelect(item.tab),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * s,
                  vertical: 10 * s,
                ),
                decoration: BoxDecoration(
                  gradient: selected ? _Ui.brandGrad : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? Colors.transparent : _Ui.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(selected ? .10 : .04),
                      blurRadius: selected ? 16 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : _Ui.subInk,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChipItem {
  const _ChipItem(this.label, this.tab);

  final String label;
  final _BikeReportTab tab;
}

class _SidewallDetailsCard extends StatelessWidget {
  const _SidewallDetailsCard({
    required this.s,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.confidence,
  });

  final double s;
  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRow('Brand', brand),
      _InfoRow('Model', model),
      _InfoRow('Size', size),
      _InfoRow('Width', width),
      _InfoRow('Aspect Ratio', aspectRatio),
      _InfoRow('Rim Diameter', rimDiameter),
      _InfoRow('Load Index', loadIndex),
      _InfoRow('Speed Rating', speedRating),
      _InfoRow('Manufacturing Date', manufacturingDate),
      _InfoRow('Confidence', confidence),
    ];

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            s: s,
            title: 'Sidewall Details',
            icon: Icons.tire_repair_rounded,
          ),
          SizedBox(height: 12 * s),
          ...rows.map((r) {
            final value = r.value.trim().isEmpty ? 'N/A' : r.value.trim();
            return Padding(
              padding: EdgeInsets.only(bottom: 8 * s),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w800,
                        color: _Ui.subInk,
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    flex: 6,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w900,
                        color: _Ui.ink,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}

class _TyreImageCardModern extends StatelessWidget {
  const _TyreImageCardModern({
    required this.s,
    required this.title,
    required this.imagePathOrUrl,
    required this.badge,
    this.subtitle,
  });

  final double s;
  final String title;
  final String imagePathOrUrl;
  final String badge;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s,
                  vertical: 6 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: _Ui.line),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w800,
                    color: _Ui.subInk,
                  ),
                ),
              ),
            ],
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w700,
                color: _Ui.subInk,
              ),
            ),
          ],
          SizedBox(height: 12 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * s),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SmartImage(pathOrUrl: imagePathOrUrl),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.04),
                            Colors.black.withOpacity(.20),
                          ],
                        ),
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

class _SmartImage extends StatelessWidget {
  const _SmartImage({required this.pathOrUrl});

  final String pathOrUrl;

  @override
  Widget build(BuildContext context) {
    final value = pathOrUrl.trim();

    if (value.isEmpty) {
      return _empty();
    }

    final file = File(value);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    if (value.startsWith("data:image")) {
      try {
        final comma = value.indexOf(',');
        final b64 = comma >= 0 ? value.substring(comma + 1) : value;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _broken();
      }
    }

    if (value.length > 100 && !value.contains(' ') && !value.startsWith('http')) {
      try {
        final bytes = base64Decode(value);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _broken(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF0F1F5),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }

    return _empty();
  }

  Widget _empty() {
    return Container(
      color: const Color(0xFFF0F1F5),
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }

  Widget _broken() {
    return Container(
      color: const Color(0xFFF0F1F5),
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    this.minHeight = 190,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeader(s: s, title: title, icon: icon),
          SizedBox(height: 12 * s),
          Text(
            v,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.2 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),
          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCardModern extends StatelessWidget {
  const _MetricCardModern({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(s: s, title: title, icon: icon),
          SizedBox(height: 12 * s),
          Text(
            v,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),
          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.s,
    required this.title,
    required this.icon,
  });

  final double s;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34 * s,
          height: 34 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * s),
            gradient: _Ui.brandGrad,
          ),
          child: Icon(icon, size: 18 * s, color: Colors.white),
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              color: _Ui.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCardModern extends StatelessWidget {
  const _SummaryCardModern({
    required this.s,
    required this.title,
    required this.summary,
  });

  final double s;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            s: s,
            title: title,
            icon: Icons.assignment_outlined,
          ),
          SizedBox(height: 12 * s),
          Text(
            summary.trim().isEmpty ? "N/A" : summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.s, required this.text});

  final double s;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: _Ui.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * s,
            height: 8 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Ui.brandGrad,
            ),
          ),
          SizedBox(width: 8 * s),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w800,
                color: _Ui.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarModern extends StatelessWidget {
  const _TopBarModern({
    required this.s,
    required this.title,
    required this.onBack,
    required this.onShare,
  });

  final double s;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 6 * s),
      child: Row(
        children: [
          _IconPill(s: s, icon: Icons.chevron_left_rounded, onTap: onBack),
          SizedBox(width: 10 * s),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 20.5 * s,
                fontWeight: FontWeight.w900,
                color: _Ui.ink,
              ),
            ),
          ),
          SizedBox(width: 10 * s),
          _IconPill(s: s, icon: Icons.ios_share_rounded, onTap: onShare),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.s,
    required this.icon,
    required this.onTap,
  });

  final double s;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      borderRadius: BorderRadius.circular(14 * s),
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * s),
        onTap: onTap,
        child: Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: _Ui.line),
          ),
          child: Icon(icon, size: 28 * s, color: _Ui.ink),
        ),
      ),
    );
  }
}

class _EmptyStateCardModern extends StatelessWidget {
  const _EmptyStateCardModern({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final double s;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 17 * s,
              fontWeight: FontWeight.w900,
              color: _Ui.ink,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: _Ui.subInk,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14 * s),
          _PrimaryButton(s: s, text: "Retry", onTap: onRetry),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.s,
    required this.text,
    required this.onTap,
  });

  final double s;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          gradient: _Ui.brandGrad,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GradDot extends StatelessWidget {
  const _GradDot({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * s,
      height: 12 * s,
      decoration: const BoxDecoration(
        gradient: _Ui.brandGrad,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GeneratingOverlayModern extends StatelessWidget {
  const _GeneratingOverlayModern({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.40),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

class _ThemedScanFailedView extends StatelessWidget {
  const _ThemedScanFailedView({
    required this.s,
    required this.message,
    required this.gradient,
    required this.onRetake,
    required this.onRetry,
  });

  final double s;
  final String message;
  final LinearGradient gradient;
  final VoidCallback onRetake;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16 * s),
            child: Container(
              padding: EdgeInsets.all(18 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20 * s),
                boxShadow: [_Ui.softShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64 * s,
                    height: 64 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 34 * s,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    'Scan Failed',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18 * s,
                      fontWeight: FontWeight.w900,
                      color: _Ui.ink,
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.8 * s,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: _Ui.subInk,
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          s: s,
                          label: 'Retake Images',
                          icon: Icons.refresh_rounded,
                          onTap: onRetake,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: _GradientButton(
                          s: s,
                          label: 'Retry',
                          icon: Icons.restart_alt_rounded,
                          gradient: gradient,
                          onTap: onRetry,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14 * s),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: Colors.white),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: _Ui.ink),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: _Ui.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ui {
  static const Color ink = Color(0xFF111827);
  static const Color subInk = Color(0xFF6B7280);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE8EAF0);

  static const LinearGradient brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxShadow softShadow = BoxShadow(
    color: Colors.black.withOpacity(.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  static BoxDecoration cardDeco(double r) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: line),
        boxShadow: [softShadow],
      );
}

*/


















// enum _BikeReportTab {
//   frontTread,
//   frontSidewall,
//   backTread,
//   backSidewall,
// }

// class TwoWheelerReportResultScreen extends StatefulWidget {
//   final String title;
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

//   final String frontTyreId;
//   final String backTyreId;

//   final String frontPath;
//   final String frontSidewallPath;
//   final String backPath;
//   final String backSidewallPath;

//   const TwoWheelerReportResultScreen({
//     super.key,
//     this.title = "Inspection Report",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     this.vehicleType = "bike",
//     required this.frontTyreId,
//     required this.backTyreId,
//     required this.frontPath,
//     required this.frontSidewallPath,
//     required this.backPath,
//     required this.backSidewallPath,
//   });

//   @override
//   State<TwoWheelerReportResultScreen> createState() =>
//       _TwoWheelerReportResultScreenState();
// }

// class _TwoWheelerReportResultScreenState
//     extends State<TwoWheelerReportResultScreen> {
//   bool _dispatched = false;
//   bool _navigated = false;

//   _BikeReportTab _active = _BikeReportTab.frontTread;

//   VideoPlayerController? _videoCtrl;
//   String _currentVideoUrl = '';
//   bool _adPlayStarted = false;

//   @override
//   void initState() {
//     super.initState();

//     context.read<AuthBloc>().add(
//           AdsFetchRequested(token: widget.token, silent: true),
//         );

//     WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
//   }

//   @override
//   void dispose() {
//     _stopVideo();
//     super.dispose();
//   }

//   void _upload() {
//     if (_dispatched) return;
//     _dispatched = true;

//     if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Missing tyre ids. Save preferences again.')),
//       );
//       return;
//     }

//     context.read<AuthBloc>().add(
//           UploadTwoWheelerRequested(
//             userId: widget.userId,
//             vehicleId: widget.vehicleId,
//             token: widget.token,
//             vin: widget.vin,
//             vehicleType: widget.vehicleType,
//             frontPath: widget.frontPath,
//             frontSidewallPath: widget.frontSidewallPath,
//             backPath: widget.backPath,
//             backSidewallPath: widget.backSidewallPath,
//             frontTyreId: widget.frontTyreId,
//             backTyreId: widget.backTyreId,
//           ),
//         );
//   }

//   Future<void> _playVideo(String url) async {
//     final u = url.trim();
//     if (u.isEmpty) return;
//     if (_currentVideoUrl == u && _videoCtrl != null) return;

//     _currentVideoUrl = u;

//     try {
//       final old = _videoCtrl;
//       final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));

//       await ctrl.initialize();
//       await ctrl.setLooping(true);
//       await ctrl.play();

//       if (!mounted) {
//         await ctrl.dispose();
//         return;
//       }

//       setState(() => _videoCtrl = ctrl);
//       await old?.dispose();
//     } catch (_) {}
//   }

//   void _stopVideo() {
//   final vc = _videoCtrl;
//   _videoCtrl = null;
//   _currentVideoUrl = '';
//   _adPlayStarted = false;
//   vc?.dispose();
// }

//   // void _stopVideo() {
//   //   final vc = _videoCtrl;
//   //   _videoCtrl = null;
//   //   _currentVideoUrl = '';
//   //   _adPlayStarted = false;
//   //   vc?.dispose();
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       body: SafeArea(
//         child: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Color(0xFFF7F8FC), Color(0xFFF3F4F7)],
//             ),
//           ),
//           child: MultiBlocListener(
//             listeners: [
//               BlocListener<AuthBloc, AuthState>(
//                 listenWhen: (p, c) =>
//                     p.selectedAd?.media != c.selectedAd?.media ||
//                     p.adsStatus != c.adsStatus ||
//                     p.twoWheelerStatus != c.twoWheelerStatus,
//                 listener: (context, state) {
//                   final isLoading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
//   final media = state.selectedAd?.media.trim() ?? '';

//   if (isLoading && media.isNotEmpty && !_adPlayStarted) {
//     _adPlayStarted = true;
//     _playVideo(media);
//   }

//   // ✅ IMPORTANT FIX: stop ad video/audio as soon as report is ready or failed
//   if (state.twoWheelerStatus == TwoWheelerStatus.success ||
//       state.twoWheelerStatus == TwoWheelerStatus.failure) {
//     _stopVideo();
//   }

//   if (state.twoWheelerStatus == TwoWheelerStatus.success) {
//     context.read<AuthBloc>().add(
//       FetchTyreHistoryRequested(
//         userId: widget.userId,
//         vehicleId: "ALL",
//       ),
//     );
//   }
//                   // if (state.twoWheelerStatus == TwoWheelerStatus.success) {
//                   //   context.read<AuthBloc>().add(
//                   //         FetchTyreHistoryRequested(
//                   //           userId: widget.userId,
//                   //           vehicleId: "ALL",
//                   //         ),
//                   //       );
//                   // }

//                   // final isLoading =
//                   //     state.twoWheelerStatus == TwoWheelerStatus.uploading;
//                   // final media = state.selectedAd?.media.trim() ?? '';

//                   // if (isLoading && media.isNotEmpty && !_adPlayStarted) {
//                   //   _adPlayStarted = true;
//                   //   _playVideo(media);
//                   // }

//                   // if (!isLoading) {
//                   //   _stopVideo();
//                   // }
//                 },
//               ),
//             ],
//             child: BlocBuilder<AuthBloc, AuthState>(
//               buildWhen: (p, c) =>
//                   p.twoWheelerStatus != c.twoWheelerStatus ||
//                   p.twoWheelerResponse != c.twoWheelerResponse,
//               builder: (context, state) {
//                 final st = state.twoWheelerStatus;
//                 final loading = st == TwoWheelerStatus.uploading;

//                 if (st == TwoWheelerStatus.failure) {
//                   final msg = state.twoWheelerError.trim().isEmpty
//                       ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
//                       : state.twoWheelerError.trim();

//                   return _ThemedScanFailedView(
//                     s: s,
//                     message: msg,
//                     gradient: _Ui.brandGrad,
//                     onRetake: () {
//                       if (_navigated) return;
//                       _navigated = true;
//                       Navigator.of(context).pop('retake');
//                     },
//                     onRetry: () {
//                       if (_navigated) return;
//                       setState(() => _dispatched = false);
//                       _upload();
//                     },
//                   );
//                 }

//                 if (loading) {
//                   return Stack(
//                     children: [
//                       _FullscreenVideoOnly(controller: _videoCtrl),
//                       Positioned(
//                         left: 16 * s,
//                         right: 16 * s,
//                         bottom: 22 * s,
//                         child: _GeneratingOverlayModern(s: s),
//                       ),
//                     ],
//                   );
//                 }

//                 final resp = state.twoWheelerResponse;
//                 final data = resp?.data;
//                 final front = data?.front;
//                 final back = data?.back;
//                 final hasAny = front != null || back != null;

//                 return Column(
//                   children: [
//                     _TopBarModern(
//                       s: s,
//                       title: widget.title,
//                       onBack: () {
//                         Navigator.of(context).pushAndRemoveUntil(
//                           MaterialPageRoute(builder: (_) => const AppShell()),
//                           (route) => false,
//                         );
//                       },
//                     ),
//                     Expanded(
//                       child: SingleChildScrollView(
//                         padding: EdgeInsets.fromLTRB(
//                           16 * s,
//                           10 * s,
//                           16 * s,
//                           20 * s,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (!loading && resp == null)
//                               _EmptyStateCardModern(
//                                 s: s,
//                                 title: "No report yet",
//                                 subtitle:
//                                     "Tap retry to generate the bike report again.",
//                                 onRetry: () {
//                                   setState(() => _dispatched = false);
//                                   _upload();
//                                 },
//                               ),

//                             if (!loading && resp != null && !hasAny)
//                               _EmptyStateCardModern(
//                                 s: s,
//                                 title: "No data found",
//                                 subtitle:
//                                     "Upload succeeded but front/back data is missing.",
//                                 onRetry: () {
//                                   setState(() => _dispatched = false);
//                                   _upload();
//                                 },
//                               ),

//                             if (hasAny) ...[
//                               _FourImagePreviewRow(
//                                 s: s,
//                                 active: _active,
//                                 frontPath: widget.frontPath,
//                                 frontSidewallPath: widget.frontSidewallPath,
//                                 backPath: widget.backPath,
//                                 backSidewallPath: widget.backSidewallPath,
//                                 onSelect: (tab) => setState(() => _active = tab),
//                               ),
//                               SizedBox(height: 12 * s),
//                               _TabChips(
//                                 s: s,
//                                 active: _active,
//                                 onSelect: (tab) => setState(() => _active = tab),
//                               ),
//                               SizedBox(height: 12 * s),
//                               _TyreReportSection(
//                                 s: s,
//                                 active: _active,
//                                 front: front,
//                                 back: back,
//                                 frontPath: widget.frontPath,
//                                 frontSidewallPath: widget.frontSidewallPath,
//                                 backPath: widget.backPath,
//                                 backSidewallPath: widget.backSidewallPath,
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _TyreReportSection extends StatelessWidget {
//   const _TyreReportSection({
//     required this.s,
//     required this.active,
//     required this.front,
//     required this.back,
//     required this.frontPath,
//     required this.frontSidewallPath,
//     required this.backPath,
//     required this.backSidewallPath,
//   });

//   final double s;
//   final _BikeReportTab active;
//   final TwoWheelerTyreSide? front;
//   final TwoWheelerTyreSide? back;

//   final String frontPath;
//   final String frontSidewallPath;
//   final String backPath;
//   final String backSidewallPath;

//   @override
//   Widget build(BuildContext context) {
//     final isFront =
//         active == _BikeReportTab.frontTread || active == _BikeReportTab.frontSidewall;
//     final isSidewall = active == _BikeReportTab.frontSidewall ||
//         active == _BikeReportTab.backSidewall;

//     final side = isFront ? front : back;

//     if (side == null) {
//       return _EmptyStateCardModern(
//         s: s,
//         title: "No ${isFront ? "front" : "back"} tyre data",
//         subtitle: "Try scanning again.",
//         onRetry: () => Navigator.of(context).pop(),
//       );
//     }

//     final title = switch (active) {
//       _BikeReportTab.frontTread => "Front Tread",
//       _BikeReportTab.frontSidewall => "Front Sidewall",
//       _BikeReportTab.backTread => "Back Tread",
//       _BikeReportTab.backSidewall => "Back Sidewall",
//     };

//     final imagePath = switch (active) {
//       _BikeReportTab.frontTread => frontPath,
//       _BikeReportTab.frontSidewall => frontSidewallPath,
//       _BikeReportTab.backTread => backPath,
//       _BikeReportTab.backSidewall => backSidewallPath,
//     };

//     final t = _TyreUi.fromSide(
//       title: title,
//       side: side,
//       localImagePath: imagePath,
//       isSidewallTab: isSidewall,
//     );

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _TyreImageCardModern(
//           s: s,
//           title: t.title,
//           imagePathOrUrl: t.imagePathOrUrl,
//           badge: isSidewall ? "Sidewall" : "Tread",
//           subtitle: t.conditionText.replaceFirst("Status:", "Status"),
//         ),
//         SizedBox(height: 12 * s),

//         Row(
//           children: [
//             Expanded(
//               child: _MetricTile(
//                 s: s,
//                 title: "Tread Depth",
//                 value: t.treadDepthText,
//                 status: t.conditionText,
//                 icon: Icons.straighten_rounded,
//                 minHeight: 178 * s,
//               ),
//             ),
//             SizedBox(width: 12 * s),
//             Expanded(
//               child: _MetricTile(
//                 s: s,
//                 title: "Tire Pressure",
//                 value: t.pressureValueText,
//                 status: t.pressureStatusText,
//                 icon: Icons.speed_rounded,
//                 minHeight: 178 * s,
//               ),
//             ),
//           ],
//         ),

//         SizedBox(height: 10 * s),

//         _MetricCardModern(
//           s: s,
//           title: isSidewall ? "Sidewall Damage" : "Damage Check",
//           value: isSidewall ? t.sidewallDamageDescription : t.wearPatternsText,
//           status: isSidewall ? t.sidewallDamageStatus : t.damageStatusText,
//           icon: Icons.report_gmailerrorred_rounded,
//         ),

//         if (isSidewall) ...[
//           SizedBox(height: 10 * s),
//           _SidewallDetailsCard(
//             s: s,
//             brand: t.brand,
//             model: t.model,
//             size: t.size,
//             width: t.width,
//             aspectRatio: t.aspectRatio,
//             rimDiameter: t.rimDiameter,
//             loadIndex: t.loadIndex,
//             speedRating: t.speedRating,
//             manufacturingDate: t.manufacturingDate,
//             confidence: t.sidewallConfidence,
//           ),
//         ],

//         SizedBox(height: 10 * s),

//         _SummaryCardModern(
//           s: s,
//           title: "Report Summary",
//           summary: t.summaryText,
//         ),
//       ],
//     );
//   }
// }

// class _TyreUi {
//   final String title;
//   final String treadDepthText;
//   final String conditionText;
//   final String wearPatternsText;
//   final String damageStatusText;
//   final String summaryText;
//   final String imagePathOrUrl;

//   final String pressureValueText;
//   final String pressureStatusText;
//   final String pressureReasonText;
//   final String pressureConfidenceText;

//   final String brand;
//   final String model;
//   final String size;
//   final String width;
//   final String aspectRatio;
//   final String rimDiameter;
//   final String loadIndex;
//   final String speedRating;
//   final String manufacturingDate;
//   final String sidewallDamageStatus;
//   final String sidewallDamageDescription;
//   final String sidewallConfidence;

//   const _TyreUi({
//     required this.title,
//     required this.treadDepthText,
//     required this.conditionText,
//     required this.wearPatternsText,
//     required this.damageStatusText,
//     required this.summaryText,
//     required this.imagePathOrUrl,
//     required this.pressureValueText,
//     required this.pressureStatusText,
//     required this.pressureReasonText,
//     required this.pressureConfidenceText,
//     required this.brand,
//     required this.model,
//     required this.size,
//     required this.width,
//     required this.aspectRatio,
//     required this.rimDiameter,
//     required this.loadIndex,
//     required this.speedRating,
//     required this.manufacturingDate,
//     required this.sidewallDamageStatus,
//     required this.sidewallDamageDescription,
//     required this.sidewallConfidence,
//   });

//   factory _TyreUi.fromSide({
//     required String title,
//     required TwoWheelerTyreSide side,
//     required String localImagePath,
//     required bool isSidewallTab,
//   }) {
//     String str(dynamic v) {
//       if (v == null) return '';
//       final s = v.toString().trim();
//       if (s.toLowerCase() == 'null') return '';
//       return s;
//     }

//     dynamic read(dynamic obj, String key) {
//       if (obj == null) return null;

//       if (obj is Map) {
//         return obj[key];
//       }

//       try {
//         final json = (obj as dynamic).toJson();
//         if (json is Map) return json[key];
//       } catch (_) {}

//       try {
//         switch (key) {
//           case 'is_tire':
//             return (obj as dynamic).isTire;
//           case 'status':
//             return (obj as dynamic).status;
//           case 'condition':
//             return (obj as dynamic).condition;
//           case 'tread_depth':
//             return (obj as dynamic).treadDepth;
//           case 'wear_patterns':
//             return (obj as dynamic).wearPatterns;
//           case 'tire_pressure':
//             return (obj as dynamic).tirePressure;
//           case 'pressure':
//             return (obj as dynamic).pressure;
//           case 'pressure_advisory':
//             return (obj as dynamic).pressureAdvisory;
//           case 'summary':
//             return (obj as dynamic).summary;
//           case 'image':
//             return (obj as dynamic).image;
//           case 'sidewall':
//             return (obj as dynamic).sidewall;
//           case 'brand':
//             return (obj as dynamic).brand;
//           case 'model':
//             return (obj as dynamic).model;
//           case 'size':
//             return (obj as dynamic).size;
//           case 'width':
//             return (obj as dynamic).width;
//           case 'aspect_ratio':
//             return (obj as dynamic).aspectRatio;
//           case 'rim_diameter':
//             return (obj as dynamic).rimDiameter;
//           case 'load_index':
//             return (obj as dynamic).loadIndex;
//           case 'speed_rating':
//             return (obj as dynamic).speedRating;
//           case 'manufacturing_date':
//             return (obj as dynamic).manufacturingDate;
//           case 'sidewall_damage':
//             return (obj as dynamic).sidewallDamage;
//           case 'description':
//             return (obj as dynamic).description;
//           case 'confidence':
//             return (obj as dynamic).confidence;
//         }
//       } catch (_) {}

//       return null;
//     }

//     final dynamic dynSide = side;

//     final isTireValue = read(dynSide, 'is_tire');
//     final isTireFalse = isTireValue == false;

//     final condition = str(read(dynSide, 'status')).isNotEmpty
//         ? str(read(dynSide, 'status'))
//         : str(read(dynSide, 'condition'));

//     final treadRaw = read(dynSide, 'tread_depth');
//     final tread = str(treadRaw);

//     final pressure = read(dynSide, 'tire_pressure') ??
//         read(dynSide, 'pressure_advisory') ??
//         read(dynSide, 'pressure');

//     final pressureStatus = str(read(pressure, 'status'));
//     final pressureReason = str(read(pressure, 'reason'));
//     final pressureConfidence = str(read(pressure, 'confidence'));

//     final sidewall = read(dynSide, 'sidewall');
//     final sidewallDamage = read(sidewall, 'sidewall_damage');

//     final brand = str(read(sidewall, 'brand'));
//     final model = str(read(sidewall, 'model'));
//     final size = str(read(sidewall, 'size'));
//     final width = str(read(sidewall, 'width'));
//     final aspectRatio = str(read(sidewall, 'aspect_ratio'));
//     final rimDiameter = str(read(sidewall, 'rim_diameter'));
//     final loadIndex = str(read(sidewall, 'load_index'));
//     final speedRating = str(read(sidewall, 'speed_rating'));
//     final manufacturingDate = str(read(sidewall, 'manufacturing_date'));
//     final swDamageStatus = str(read(sidewallDamage, 'status'));
//     final swDamageDesc = str(read(sidewallDamage, 'description'));
//     final swConfidence = str(read(sidewall, 'confidence'));

//     final pressureLines = <String>[
//       'Value: ${pressureStatus.isEmpty ? "N/A" : pressureStatus}',
//       if (pressureReason.isNotEmpty) 'Reason: $pressureReason',
//       if (pressureConfidence.isNotEmpty) 'Confidence: $pressureConfidence',
//     ];

//     return _TyreUi(
//       title: title,
//       treadDepthText: isTireFalse
//           ? 'N/A'
//           : tread.isEmpty
//               ? 'N/A'
//               : '$tread mm',
//       conditionText: isTireFalse
//           ? 'Status: Not a tyre'
//           : condition.isEmpty
//               ? 'Status: N/A'
//               : 'Status: $condition',
//       wearPatternsText: str(read(dynSide, 'wear_patterns')).isEmpty
//           ? 'N/A'
//           : str(read(dynSide, 'wear_patterns')),
//       damageStatusText: isTireFalse
//           ? 'Not a tyre'
//           : condition.isEmpty
//               ? 'N/A'
//               : condition,
//       summaryText: str(read(dynSide, 'summary')).isEmpty
//           ? 'N/A'
//           : str(read(dynSide, 'summary')),
//       imagePathOrUrl: localImagePath,
//       pressureValueText: pressureLines.join('\n'),
//       pressureStatusText: pressureStatus.isEmpty ? 'N/A' : pressureStatus,
//       pressureReasonText: pressureReason,
//       pressureConfidenceText: pressureConfidence,
//       brand: brand,
//       model: model,
//       size: size,
//       width: width,
//       aspectRatio: aspectRatio,
//       rimDiameter: rimDiameter,
//       loadIndex: loadIndex,
//       speedRating: speedRating,
//       manufacturingDate: manufacturingDate,
//       sidewallDamageStatus: swDamageStatus.isEmpty ? 'N/A' : swDamageStatus,
//       sidewallDamageDescription: swDamageDesc.isEmpty ? 'N/A' : swDamageDesc,
//       sidewallConfidence: swConfidence,
//     );
//   }
// }

// class _FourImagePreviewRow extends StatelessWidget {
//   const _FourImagePreviewRow({
//     required this.s,
//     required this.active,
//     required this.frontPath,
//     required this.frontSidewallPath,
//     required this.backPath,
//     required this.backSidewallPath,
//     required this.onSelect,
//   });

//   final double s;
//   final _BikeReportTab active;
//   final String frontPath;
//   final String frontSidewallPath;
//   final String backPath;
//   final String backSidewallPath;
//   final ValueChanged<_BikeReportTab> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     final items = [
//       _PreviewItem('Front Tread', frontPath, _BikeReportTab.frontTread),
//       _PreviewItem('Front Sidewall', frontSidewallPath, _BikeReportTab.frontSidewall),
//       _PreviewItem('Back Tread', backPath, _BikeReportTab.backTread),
//       _PreviewItem('Back Sidewall', backSidewallPath, _BikeReportTab.backSidewall),
//     ];

//     return SizedBox(
//       height: 160 * s,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: items.length,
//         separatorBuilder: (_, __) => SizedBox(width: 12 * s),
//         itemBuilder: (_, i) {
//           final item = items[i];
//           final selected = active == item.tab;

//           return GestureDetector(
//             onTap: () => onSelect(item.tab),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 180),
//               width: 126 * s,
//               padding: EdgeInsets.all(3 * s),
//               decoration: BoxDecoration(
//                 gradient: selected ? _Ui.brandGrad : null,
//                 color: selected ? null : Colors.white,
//                 borderRadius: BorderRadius.circular(18 * s),
//                 border: Border.all(
//                   color: selected ? Colors.transparent : _Ui.line,
//                 ),
//                 boxShadow: [_Ui.softShadow],
//               ),
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(15 * s),
//                       child: _SmartImage(pathOrUrl: item.path),
//                     ),
//                   ),
//                   SizedBox(height: 7 * s),
//                   Padding(
//                     padding: EdgeInsets.only(bottom: 5 * s),
//                     child: Text(
//                       item.label,
//                       textAlign: TextAlign.center,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 12.5 * s,
//                         fontWeight: FontWeight.w900,
//                         color: selected ? Colors.white : _Ui.ink,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class _PreviewItem {
//   const _PreviewItem(this.label, this.path, this.tab);

//   final String label;
//   final String path;
//   final _BikeReportTab tab;
// }

// class _TabChips extends StatelessWidget {
//   const _TabChips({
//     required this.s,
//     required this.active,
//     required this.onSelect,
//   });

//   final double s;
//   final _BikeReportTab active;
//   final ValueChanged<_BikeReportTab> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     final items = [
//       _ChipItem('Front Tread', _BikeReportTab.frontTread),
//       _ChipItem('Front Sidewall', _BikeReportTab.frontSidewall),
//       _ChipItem('Back Tread', _BikeReportTab.backTread),
//       _ChipItem('Back Sidewall', _BikeReportTab.backSidewall),
//     ];

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children: items.map((item) {
//           final selected = active == item.tab;

//           return Padding(
//             padding: EdgeInsets.only(right: 10 * s),
//             child: InkWell(
//               onTap: () => onSelect(item.tab),
//               borderRadius: BorderRadius.circular(999),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding: EdgeInsets.symmetric(
//                   horizontal: 14 * s,
//                   vertical: 10 * s,
//                 ),
//                 decoration: BoxDecoration(
//                   gradient: selected ? _Ui.brandGrad : null,
//                   color: selected ? null : Colors.white,
//                   borderRadius: BorderRadius.circular(999),
//                   border: Border.all(
//                     color: selected ? Colors.transparent : _Ui.line,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(selected ? .10 : .04),
//                       blurRadius: selected ? 16 : 10,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Text(
//                   item.label,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 13 * s,
//                     fontWeight: FontWeight.w900,
//                     color: selected ? Colors.white : _Ui.subInk,
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// class _ChipItem {
//   const _ChipItem(this.label, this.tab);

//   final String label;
//   final _BikeReportTab tab;
// }

// class _SidewallDetailsCard extends StatelessWidget {
//   const _SidewallDetailsCard({
//     required this.s,
//     required this.brand,
//     required this.model,
//     required this.size,
//     required this.width,
//     required this.aspectRatio,
//     required this.rimDiameter,
//     required this.loadIndex,
//     required this.speedRating,
//     required this.manufacturingDate,
//     required this.confidence,
//   });

//   final double s;
//   final String brand;
//   final String model;
//   final String size;
//   final String width;
//   final String aspectRatio;
//   final String rimDiameter;
//   final String loadIndex;
//   final String speedRating;
//   final String manufacturingDate;
//   final String confidence;

//   @override
//   Widget build(BuildContext context) {
//     final rows = [
//       _InfoRow('Brand', brand),
//       _InfoRow('Model', model),
//       _InfoRow('Size', size),
//       _InfoRow('Width', width),
//       _InfoRow('Aspect Ratio', aspectRatio),
//       _InfoRow('Rim Diameter', rimDiameter),
//       _InfoRow('Load Index', loadIndex),
//       _InfoRow('Speed Rating', speedRating),
//       _InfoRow('Manufacturing Date', manufacturingDate),
//       _InfoRow('Confidence', confidence),
//     ];

//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardHeader(
//             s: s,
//             title: 'Sidewall Details',
//             icon: Icons.tire_repair_rounded,
//           ),
//           SizedBox(height: 12 * s),
//           ...rows.map((r) {
//             final value = r.value.trim().isEmpty ? 'N/A' : r.value.trim();
//             return Padding(
//               padding: EdgeInsets.only(bottom: 8 * s),
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 4,
//                     child: Text(
//                       r.label,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 13 * s,
//                         fontWeight: FontWeight.w800,
//                         color: _Ui.subInk,
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 10 * s),
//                   Expanded(
//                     flex: 6,
//                     child: Text(
//                       value,
//                       textAlign: TextAlign.right,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 13 * s,
//                         fontWeight: FontWeight.w900,
//                         color: _Ui.ink,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
// }

// class _InfoRow {
//   const _InfoRow(this.label, this.value);
//   final String label;
//   final String value;
// }

// class _TyreImageCardModern extends StatelessWidget {
//   const _TyreImageCardModern({
//     required this.s,
//     required this.title,
//     required this.imagePathOrUrl,
//     required this.badge,
//     this.subtitle,
//   });

//   final double s;
//   final String title;
//   final String imagePathOrUrl;
//   final String badge;
//   final String? subtitle;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               _GradDot(s: s),
//               SizedBox(width: 10 * s),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 16.5 * s,
//                     fontWeight: FontWeight.w900,
//                     color: _Ui.ink,
//                   ),
//                 ),
//               ),
//               Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: 10 * s,
//                   vertical: 6 * s,
//                 ),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(999),
//                   color: const Color(0xFFF3F4F6),
//                   border: Border.all(color: _Ui.line),
//                 ),
//                 child: Text(
//                   badge,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 12 * s,
//                     fontWeight: FontWeight.w800,
//                     color: _Ui.subInk,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           if ((subtitle ?? '').trim().isNotEmpty) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               subtitle!,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 12.5 * s,
//                 fontWeight: FontWeight.w700,
//                 color: _Ui.subInk,
//               ),
//             ),
//           ],
//           SizedBox(height: 12 * s),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(16 * s),
//             child: AspectRatio(
//               aspectRatio: 16 / 10,
//               child: Stack(
//                 fit: StackFit.expand,
//                 children: [
//                   _SmartImage(pathOrUrl: imagePathOrUrl),
//                   Positioned.fill(
//                     child: DecoratedBox(
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Colors.black.withOpacity(.04),
//                             Colors.black.withOpacity(.20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SmartImage extends StatelessWidget {
//   const _SmartImage({required this.pathOrUrl});

//   final String pathOrUrl;

//   @override
//   Widget build(BuildContext context) {
//     final value = pathOrUrl.trim();

//     if (value.isEmpty) {
//       return _empty();
//     }

//     final file = File(value);
//     if (file.existsSync()) {
//       return Image.file(file, fit: BoxFit.cover);
//     }

//     if (value.startsWith("data:image")) {
//       try {
//         final comma = value.indexOf(',');
//         final b64 = comma >= 0 ? value.substring(comma + 1) : value;
//         final bytes = base64Decode(b64);
//         return Image.memory(bytes, fit: BoxFit.cover);
//       } catch (_) {
//         return _broken();
//       }
//     }

//     if (value.length > 100 && !value.contains(' ') && !value.startsWith('http')) {
//       try {
//         final bytes = base64Decode(value);
//         return Image.memory(bytes, fit: BoxFit.cover);
//       } catch (_) {}
//     }

//     if (value.startsWith('http://') || value.startsWith('https://')) {
//       return Image.network(
//         value,
//         fit: BoxFit.cover,
//         errorBuilder: (_, __, ___) => _broken(),
//         loadingBuilder: (context, child, progress) {
//           if (progress == null) return child;
//           return Container(
//             color: const Color(0xFFF0F1F5),
//             child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
//           );
//         },
//       );
//     }

//     return _empty();
//   }

//   Widget _empty() {
//     return Container(
//       color: const Color(0xFFF0F1F5),
//       child: const Center(child: Icon(Icons.image_not_supported_outlined)),
//     );
//   }

//   Widget _broken() {
//     return Container(
//       color: const Color(0xFFF0F1F5),
//       child: const Center(child: Icon(Icons.broken_image_outlined)),
//     );
//   }
// }

// class _MetricTile extends StatelessWidget {
//   const _MetricTile({
//     required this.s,
//     required this.title,
//     required this.value,
//     required this.status,
//     required this.icon,
//     this.minHeight = 190,
//   });

//   final double s;
//   final String title;
//   final String value;
//   final String status;
//   final IconData icon;
//   final double minHeight;

//   @override
//   Widget build(BuildContext context) {
//     final v = value.trim().isEmpty ? "N/A" : value.trim();
//     final st = status.trim();

//     return Container(
//       constraints: BoxConstraints(minHeight: minHeight),
//       padding: EdgeInsets.all(14 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _CardHeader(s: s, title: title, icon: icon),
//           SizedBox(height: 12 * s),
//           Text(
//             v,
//             maxLines: 6,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13.2 * s,
//               fontWeight: FontWeight.w700,
//               color: _Ui.ink,
//               height: 1.35,
//             ),
//           ),
//           if (st.isNotEmpty) ...[
//             SizedBox(height: 10 * s),
//             _StatusPill(
//               s: s,
//               text: st.startsWith("Status:") ? st : "Status: $st",
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class _MetricCardModern extends StatelessWidget {
//   const _MetricCardModern({
//     required this.s,
//     required this.title,
//     required this.value,
//     required this.status,
//     required this.icon,
//   });

//   final double s;
//   final String title;
//   final String value;
//   final String status;
//   final IconData icon;

//   @override
//   Widget build(BuildContext context) {
//     final v = value.trim().isEmpty ? "N/A" : value.trim();
//     final st = status.trim();

//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardHeader(s: s, title: title, icon: icon),
//           SizedBox(height: 12 * s),
//           Text(
//             v,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13.5 * s,
//               fontWeight: FontWeight.w700,
//               color: _Ui.ink,
//               height: 1.35,
//             ),
//           ),
//           if (st.isNotEmpty) ...[
//             SizedBox(height: 10 * s),
//             _StatusPill(
//               s: s,
//               text: st.startsWith("Status:") ? st : "Status: $st",
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class _CardHeader extends StatelessWidget {
//   const _CardHeader({
//     required this.s,
//     required this.title,
//     required this.icon,
//   });

//   final double s;
//   final String title;
//   final IconData icon;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           width: 34 * s,
//           height: 34 * s,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(12 * s),
//             gradient: _Ui.brandGrad,
//           ),
//           child: Icon(icon, size: 18 * s, color: Colors.white),
//         ),
//         SizedBox(width: 10 * s),
//         Expanded(
//           child: Text(
//             title,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w900,
//               color: _Ui.ink,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _SummaryCardModern extends StatelessWidget {
//   const _SummaryCardModern({
//     required this.s,
//     required this.title,
//     required this.summary,
//   });

//   final double s;
//   final String title;
//   final String summary;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardHeader(
//             s: s,
//             title: title,
//             icon: Icons.assignment_outlined,
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             summary.trim().isEmpty ? "N/A" : summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13.5 * s,
//               fontWeight: FontWeight.w700,
//               color: _Ui.ink,
//               height: 1.4,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StatusPill extends StatelessWidget {
//   const _StatusPill({required this.s, required this.text});

//   final double s;
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(999),
//         color: const Color(0xFFF3F4F6),
//         border: Border.all(color: _Ui.line),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 8 * s,
//             height: 8 * s,
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: _Ui.brandGrad,
//             ),
//           ),
//           SizedBox(width: 8 * s),
//           Flexible(
//             child: Text(
//               text,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 12.5 * s,
//                 fontWeight: FontWeight.w800,
//                 color: _Ui.ink,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TopBarModern extends StatelessWidget {
//   const _TopBarModern({
//     required this.s,
//     required this.title,
//     required this.onBack,
//   });

//   final double s;
//   final String title;
//   final VoidCallback onBack;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 6 * s),
//       child: Row(
//         children: [
//           _IconPill(s: s, icon: Icons.chevron_left_rounded, onTap: onBack),
//           SizedBox(width: 10 * s),
//           Expanded(
//             child: Text(
//               title,
//               textAlign: TextAlign.center,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 20.5 * s,
//                 fontWeight: FontWeight.w900,
//                 color: _Ui.ink,
//               ),
//             ),
//           ),
//           SizedBox(width: 46 * s),
//         ],
//       ),
//     );
//   }
// }

// class _IconPill extends StatelessWidget {
//   const _IconPill({
//     required this.s,
//     required this.icon,
//     required this.onTap,
//   });

//   final double s;
//   final IconData icon;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white.withOpacity(.9),
//       borderRadius: BorderRadius.circular(14 * s),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14 * s),
//         onTap: onTap,
//         child: Container(
//           width: 42 * s,
//           height: 42 * s,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(14 * s),
//             border: Border.all(color: _Ui.line),
//           ),
//           child: Icon(icon, size: 28 * s, color: _Ui.ink),
//         ),
//       ),
//     );
//   }
// }

// class _EmptyStateCardModern extends StatelessWidget {
//   const _EmptyStateCardModern({
//     required this.s,
//     required this.title,
//     required this.subtitle,
//     required this.onRetry,
//   });

//   final double s;
//   final String title;
//   final String subtitle;
//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: _Ui.cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 17 * s,
//               fontWeight: FontWeight.w900,
//               color: _Ui.ink,
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13 * s,
//               fontWeight: FontWeight.w600,
//               color: _Ui.subInk,
//               height: 1.35,
//             ),
//           ),
//           SizedBox(height: 14 * s),
//           _PrimaryButton(s: s, text: "Retry", onTap: onRetry),
//         ],
//       ),
//     );
//   }
// }

// class _PrimaryButton extends StatelessWidget {
//   const _PrimaryButton({
//     required this.s,
//     required this.text,
//     required this.onTap,
//   });

//   final double s;
//   final String text;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: 46 * s,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(14 * s),
//           gradient: _Ui.brandGrad,
//         ),
//         alignment: Alignment.center,
//         child: Text(
//           text,
//           style: TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontSize: 14 * s,
//             fontWeight: FontWeight.w900,
//             color: Colors.white,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _GradDot extends StatelessWidget {
//   const _GradDot({required this.s});

//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 12 * s,
//       height: 12 * s,
//       decoration: const BoxDecoration(
//         gradient: _Ui.brandGrad,
//         shape: BoxShape.circle,
//       ),
//     );
//   }
// }

// class _GeneratingOverlayModern extends StatelessWidget {
//   const _GeneratingOverlayModern({required this.s});

//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(.40),
//         borderRadius: BorderRadius.circular(18 * s),
//         border: Border.all(color: Colors.white.withOpacity(.12)),
//       ),
//       child: Row(
//         children: [
//           const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(
//               strokeWidth: 2.6,
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//             ),
//           ),
//           SizedBox(width: 12 * s),
//           Expanded(
//             child: Text(
//               "Generating report… Please wait",
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14 * s,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _FullscreenVideoOnly extends StatelessWidget {
//   const _FullscreenVideoOnly({required this.controller});

//   final VideoPlayerController? controller;

//   @override
//   Widget build(BuildContext context) {
//     final c = controller;

//     if (c == null || !c.value.isInitialized) {
//       return const ColoredBox(color: Colors.black);
//     }

//     return SizedBox.expand(
//       child: FittedBox(
//         fit: BoxFit.cover,
//         child: SizedBox(
//           width: c.value.size.width,
//           height: c.value.size.height,
//           child: VideoPlayer(c),
//         ),
//       ),
//     );
//   }
// }

// class _ThemedScanFailedView extends StatelessWidget {
//   const _ThemedScanFailedView({
//     required this.s,
//     required this.message,
//     required this.gradient,
//     required this.onRetake,
//     required this.onRetry,
//   });

//   final double s;
//   final String message;
//   final LinearGradient gradient;
//   final VoidCallback onRetake;
//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: SafeArea(
//         child: Center(
//           child: Padding(
//             padding: EdgeInsets.all(16 * s),
//             child: Container(
//               padding: EdgeInsets.all(18 * s),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20 * s),
//                 boxShadow: [_Ui.softShadow],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     width: 64 * s,
//                     height: 64 * s,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: gradient,
//                     ),
//                     child: Icon(
//                       Icons.error_outline_rounded,
//                       color: Colors.white,
//                       size: 34 * s,
//                     ),
//                   ),
//                   SizedBox(height: 12 * s),
//                   Text(
//                     'Scan Failed',
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 18 * s,
//                       fontWeight: FontWeight.w900,
//                       color: _Ui.ink,
//                     ),
//                   ),
//                   SizedBox(height: 8 * s),
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 13.8 * s,
//                       fontWeight: FontWeight.w600,
//                       height: 1.35,
//                       color: _Ui.subInk,
//                     ),
//                   ),
//                   SizedBox(height: 16 * s),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _GhostButton(
//                           s: s,
//                           label: 'Retake Images',
//                           icon: Icons.refresh_rounded,
//                           onTap: onRetake,
//                         ),
//                       ),
//                       SizedBox(width: 12 * s),
//                       Expanded(
//                         child: _GradientButton(
//                           s: s,
//                           label: 'Retry',
//                           icon: Icons.restart_alt_rounded,
//                           gradient: gradient,
//                           onTap: onRetry,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _GradientButton extends StatelessWidget {
//   const _GradientButton({
//     required this.s,
//     required this.label,
//     required this.icon,
//     required this.gradient,
//     required this.onTap,
//   });

//   final double s;
//   final String label;
//   final IconData icon;
//   final LinearGradient gradient;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(14 * s),
//       child: Container(
//         padding: EdgeInsets.symmetric(vertical: 12.5 * s),
//         decoration: BoxDecoration(
//           gradient: gradient,
//           borderRadius: BorderRadius.circular(14 * s),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 20 * s, color: Colors.white),
//             SizedBox(width: 8 * s),
//             Text(
//               label,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontWeight: FontWeight.w900,
//                 fontSize: 14.5 * s,
//                 color: Colors.white,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _GhostButton extends StatelessWidget {
//   const _GhostButton({
//     required this.s,
//     required this.label,
//     required this.icon,
//     required this.onTap,
//   });

//   final double s;
//   final String label;
//   final IconData icon;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(14 * s),
//       child: Container(
//         padding: EdgeInsets.symmetric(vertical: 12.5 * s),
//         decoration: BoxDecoration(
//           color: const Color(0xFFF1F5F9),
//           borderRadius: BorderRadius.circular(14 * s),
//           border: Border.all(color: const Color(0xFFE5E7EB)),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 20 * s, color: _Ui.ink),
//             SizedBox(width: 8 * s),
//             Text(
//               label,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontWeight: FontWeight.w900,
//                 fontSize: 14.5 * s,
//                 color: _Ui.ink,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _Ui {
//   static const Color ink = Color(0xFF111827);
//   static const Color subInk = Color(0xFF6B7280);
//   static const Color card = Colors.white;
//   static const Color line = Color(0xFFE8EAF0);

//   static const LinearGradient brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.topLeft,
//     end: Alignment.bottomRight,
//   );

//   static BoxShadow softShadow = BoxShadow(
//     color: Colors.black.withOpacity(.06),
//     blurRadius: 22,
//     offset: const Offset(0, 10),
//   );

//   static BoxDecoration cardDeco(double r) => BoxDecoration(
//         color: card,
//         borderRadius: BorderRadius.circular(r),
//         border: Border.all(color: line),
//         boxShadow: [softShadow],
//       );
// }










/*

enum _BikeTyrePos { front, back }

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

  final String frontPath;
  final String frontSidewallPath;
  final String backPath;
  final String backSidewallPath;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Inspection Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
    required this.frontPath,
    required this.frontSidewallPath,
    required this.backPath,
    required this.backSidewallPath,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState
    extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;
  _BikeTyrePos _active = _BikeTyrePos.front;

  // ✅ keep navigation protection (same idea as 4-wheeler)
  bool _navigated = false;

  // ✅ VIDEO STATE (ad video while generating)
  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  @override
  void initState() {
    super.initState();

    // ✅ Fetch Ads (video)
    context.read<AuthBloc>().add(
      AdsFetchRequested(token: widget.token, silent: true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;
    if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing tyre ids. Save preferences again.'),
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(
      UploadTwoWheelerRequested(
        userId: widget.userId,
        vehicleId: widget.vehicleId,
        token: widget.token,
        vin: widget.vin,
        vehicleType: widget.vehicleType,
        frontPath: widget.frontPath,
        frontSidewallPath: widget.frontSidewallPath,
        backPath: widget.backPath,
        backSidewallPath: widget.backSidewallPath,
        frontTyreId: widget.frontTyreId,
        backTyreId: widget.backTyreId,
      ),
    );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentVideoUrl == u && _videoCtrl != null) return;

    _currentVideoUrl = u;

    try {
      final old = _videoCtrl;

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _videoCtrl = ctrl;
      });

      await old?.dispose();
    } catch (_) {
      // fallback: keep black screen
    }
  }

  void _stopVideo() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    _currentVideoUrl = '';
    _adPlayStarted = false;
    vc?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Container(
          // ✅ Modern subtle background (no data changes)
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F8FC), Color(0xFFF3F4F7)],
            ),
          ),
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (p, c) =>
                    p.selectedAd?.media != c.selectedAd?.media ||
                    p.adsStatus != c.adsStatus ||
                    p.twoWheelerStatus != c.twoWheelerStatus,
                listener: (context, state) {
                  if (state.twoWheelerStatus == TwoWheelerStatus.success) {
                    context.read<AuthBloc>().add(
                      FetchTyreHistoryRequested(
                        userId: widget.userId,
                        vehicleId: "ALL",
                      ),
                    );
                  }
                  final isLoading =
                      state.twoWheelerStatus == TwoWheelerStatus.uploading;
                  final media = state.selectedAd?.media.trim() ?? '';

                  if (isLoading && media.isNotEmpty && !_adPlayStarted) {
                    _adPlayStarted = true;
                    _playVideo(media);
                  }
                  if (!isLoading) _stopVideo();
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (p, c) =>
                  p.twoWheelerStatus != c.twoWheelerStatus ||
                  p.twoWheelerResponse != c.twoWheelerResponse,
              builder: (context, state) {
                final st = state.twoWheelerStatus;
                final loading = st == TwoWheelerStatus.uploading;

                // ✅ APPLY SAME "SCAN FAILED" CONDITION AS 4-WHEELER
                // AuthBloc already sets twoWheelerStatus=failure when front/back is_tire=false.
                if (st == TwoWheelerStatus.failure) {
                  final msg = state.twoWheelerError.trim().isEmpty
                      ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                      : state.twoWheelerError.trim();

                  return _ThemedScanFailedView(
                    s: s,
                    message: msg,
                    gradient: _Ui.brandGrad,
                    onRetake: () {
                      if (_navigated) return;
                      _navigated = true;
                      Navigator.of(context).pop('retake');
                    },
                    onRetry: () {
                      if (_navigated) return;
                      setState(() {
                        _dispatched = false;
                      });
                      _upload();
                    },
                  );
                }

                // ✅ SHOW FULLSCREEN VIDEO DURING LOADING
                if (loading) {
                  return Stack(
                    children: [
                      _FullscreenVideoOnly(controller: _videoCtrl),
                      Positioned(
                        left: 16 * s,
                        right: 16 * s,
                        bottom: 22 * s,
                        child: _GeneratingOverlayModern(s: s),
                      ),
                    ],
                  );
                }

                final resp = state.twoWheelerResponse;
                final data = resp?.data;
                final front = data?.front;
                final back = data?.back;
                final hasAny = (front != null) || (back != null);

                return Column(
                  children: [
                    _TopBarModern(
                      s: s,
                      title: widget.title,
                      onBack: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false,
                        );
                      },
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16 * s,
                          10 * s,
                          16 * s,
                          20 * s,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SegmentToggleModern(
                              s: s,
                              leftLabel: "Front",
                              rightLabel: "Back",
                              isLeft: _active == _BikeTyrePos.front,
                              onLeft: () =>
                                  setState(() => _active = _BikeTyrePos.front),
                              onRight: () =>
                                  setState(() => _active = _BikeTyrePos.back),
                            ),
                            SizedBox(height: 12 * s),

                            if (!loading && resp == null) ...[
                              _EmptyStateCardModern(
                                s: s,
                                title: "No report yet",
                                subtitle:
                                    "Tap retry to generate the bike report again.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),
                            ],

                            if (!loading && resp != null && !hasAny) ...[
                              _EmptyStateCardModern(
                                s: s,
                                title: "No data found",
                                subtitle:
                                    "Upload succeeded but front/back data is missing.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),
                            ],

                            if (hasAny) ...[
                              _TyreReportSection(
                                s: s,
                                active: _active,
                                front: front,
                                back: back,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

// ✅ Modern overlay (same text, nicer look)
class _GeneratingOverlayModern extends StatelessWidget {
  const _GeneratingOverlayModern({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.40),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// ✅ REPORT SECTION (DATA SAME)
// ===============================

class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
  });

  final double s;
  final _BikeTyrePos active;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  @override
  Widget build(BuildContext context) {
    final side = active == _BikeTyrePos.front ? front : back;

    if (side == null) {
      return _EmptyStateCardModern(
        s: s,
        title:
            "No ${active == _BikeTyrePos.front ? "front" : "back"} tyre data",
        subtitle: "Try scanning again.",
        onRetry: () => Navigator.of(context).pop(),
      );
    }

    final t = _TyreUi.fromSide(
      title: active == _BikeTyrePos.front ? "Front" : "Back",
      side: side,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TyreImageCardModern(
          s: s,
          title: t.title,
          imageUrl: t.imageUrl,
          // ✅ optional tiny line under title
          subtitle: (t.conditionText.trim().isEmpty)
              ? null
              : t.conditionText.replaceFirst("Status:", "Status"),
        ),
        SizedBox(height: 12 * s),
        SizedBox(height: 2 * s),

        // ✅ same row, but equal height + better spacing + better alignment
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText,
                icon: Icons.straighten_rounded,
                minHeight: 190 * s, // ✅ tweak if needed
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tire Pressure",
                value: t.pressureValueText,
                status: t.pressureStatusText,
                icon: Icons.speed_rounded,
                minHeight: 190 * s,
              ),
            ),
          ],
        ),

        SizedBox(height: 10 * s),
        _MetricCardModern(
          s: s,
          title: "Damage Check",
          value: t.wearPatternsText,
          status: t.damageStatusText,
          icon: Icons.report_gmailerrorred_rounded,
        ),
        SizedBox(height: 10 * s),
        _SummaryCardModern(
          s: s,
          title: "Report Summary",
          summary: t.summaryText,
        ),
      ],
    );
  }
}

class _TyreUi {
  final String title;

  final String treadDepthText;
  final String conditionText;

  final String wearPatternsText;
  final String damageStatusText;

  final String summaryText;

  final String imageUrl;

  final String pressureValueText;
  final String pressureStatusText;
  final String pressureReasonText;
  final String pressureConfidenceText;

  const _TyreUi({
    required this.title,
    required this.treadDepthText,
    required this.conditionText,
    required this.wearPatternsText,
    required this.damageStatusText,
    required this.summaryText,
    required this.imageUrl,
    required this.pressureValueText,
    required this.pressureStatusText,
    required this.pressureReasonText,
    required this.pressureConfidenceText,
  });

  factory _TyreUi.fromSide({
    required String title,
    required TwoWheelerTyreSide side,
  }) {
    String str(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.toLowerCase() == 'null') return '';
      return s;
    }

    // ✅ NEW: if backend says this uploaded image isn't a tyre, show clear UI.
    if (side.isTire == false) {
      final tp = side.pressureAdvisory;
      final status = str(tp?.status);
      final reason = str(tp?.reason);
      final confidence = str(tp?.confidence);

      final valueLines = <String>['Value: N/A'];
      if (reason.isNotEmpty) valueLines.add('Reason: $reason');
      if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

      return _TyreUi(
        title: title,
        treadDepthText: 'N/A',
        conditionText: 'Status: Not a tyre',
        wearPatternsText: 'N/A',
        damageStatusText: 'Not a tyre',
        summaryText: str(side.summary).isEmpty
            ? 'Uploaded image does not contain a tyre. Please upload a clear tyre photo.'
            : str(side.summary),
        imageUrl: str(side.image),
        pressureValueText: valueLines.join('\n'),
        pressureStatusText: status.isEmpty ? '' : status,
        pressureReasonText: reason,
        pressureConfidenceText: confidence,
      );
    }

    final td = side.treadDepth;
    final tread = (td == null) ? '' : td.toString();

    final pressure = side.pressureAdvisory;

    final status = str(pressure?.status);
    final reason = str(pressure?.reason);
    final confidence = str(pressure?.confidence);

    final valueLines = <String>[];
    valueLines.add('Value: N/A');
    if (reason.isNotEmpty) valueLines.add('Reason: $reason');
    if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

    return _TyreUi(
      title: title,
      treadDepthText: tread.isEmpty ? "N/A" : "$tread mm",
      conditionText: str(side.condition).isEmpty
          ? ""
          : "Status: ${str(side.condition)}",
      wearPatternsText: str(side.wearPatterns).isEmpty
          ? "N/A"
          : str(side.wearPatterns),
      damageStatusText: str(side.condition).isEmpty ? "" : str(side.condition),
      summaryText: str(side.summary).isEmpty ? "N/A" : str(side.summary),
      imageUrl: str(side.image),
      pressureValueText: valueLines.join('\n'),
      pressureStatusText: status.isEmpty ? "" : status,
      pressureReasonText: reason,
      pressureConfidenceText: confidence,
    );
  }
}

// ===============================
// ✅ MODERN DESIGN TOKENS
// ===============================

class _Ui {
  static const Color ink = Color(0xFF111827);
  static const Color subInk = Color(0xFF6B7280);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE8EAF0);

  static const LinearGradient brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxShadow softShadow = BoxShadow(
    color: Colors.black.withOpacity(.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  static BoxDecoration cardDeco(double r) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: line),
    boxShadow: [softShadow],
  );
}

// ===============================
// ✅ UI WIDGETS (DESIGN UPDATED)
// ===============================

class _TopBarModern extends StatelessWidget {
  const _TopBarModern({
    required this.s,
    required this.title,
    required this.onBack,
  });

  final double s;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 6 * s),
      child: Row(
        children: [
          _IconPill(s: s, icon: Icons.chevron_left_rounded, onTap: onBack),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 20.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 46 * s),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.s, required this.icon, required this.onTap});

  final double s;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      borderRadius: BorderRadius.circular(14 * s),
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * s),
        onTap: onTap,
        child: Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: _Ui.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 28 * s, color: _Ui.ink),
        ),
      ),
    );
  }
}

class _SegmentToggleModern extends StatelessWidget {
  const _SegmentToggleModern({
    required this.s,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeft,
    required this.onLeft,
    required this.onRight,
  });

  final double s;
  final String leftLabel;
  final String rightLabel;
  final bool isLeft;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48 * s,
      padding: EdgeInsets.all(5 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Ui.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _seg(label: leftLabel, active: isLeft, onTap: onLeft),
          ),
          Expanded(
            child: _seg(label: rightLabel, active: !isLeft, onTap: onRight),
          ),
        ],
      ),
    );
  }

  Widget _seg({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active ? _Ui.brandGrad : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13.5 * s,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : _Ui.subInk,
                letterSpacing: .2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCardModern extends StatelessWidget {
  const _EmptyStateCardModern({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final double s;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: _Ui.subInk,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14 * s),
          _PrimaryButton(s: s, text: "Retry", onTap: onRetry),
        ],
      ),
    );
  }
}

class _GradDot extends StatelessWidget {
  const _GradDot({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * s,
      height: 12 * s,
      decoration: BoxDecoration(
        gradient: _Ui.brandGrad,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.s,
    required this.text,
    required this.onTap,
  });

  final double s;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          gradient: _Ui.brandGrad,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: .2,
          ),
        ),
      ),
    );
  }
}

class _TyreImageCardModern extends StatelessWidget {
  const _TyreImageCardModern({
    required this.s,
    required this.title,
    required this.imageUrl,
    this.subtitle,
  });

  final double s;
  final String title;
  final String imageUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final img = _imageWidget(imageUrl);

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Title with gradient text feel (same data)
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s,
                  vertical: 6 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: _Ui.line),
                ),
                child: Text(
                  "Tyre",
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w800,
                    color: _Ui.subInk,
                  ),
                ),
              ),
            ],
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w700,
                color: _Ui.subInk,
              ),
            ),
          ],
          SizedBox(height: 12 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * s),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img,
                  // ✅ soft overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.05),
                            Colors.black.withOpacity(.22),
                          ],
                        ),
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

  Widget _imageWidget(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color: const Color(0xFFF0F1F5),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    if (url.startsWith("data:image")) {
      try {
        final comma = url.indexOf(',');
        final b64 = comma >= 0 ? url.substring(comma + 1) : url;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: const Color(0xFFF0F1F5),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
    }

    // ✅ raw base64 (no data-uri)
    if (url.length > 100 && !url.contains(' ') && !url.startsWith('http')) {
      try {
        final bytes = base64Decode(url);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        // fallthrough to network
      }
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF0F1F5),
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF0F1F5),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    this.minHeight = 190,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ critical in scroll views
        children: [
          Row(
            children: [
              Container(
                width: 36 * s,
                height: 36 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(icon, size: 18 * s, color: Colors.white),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * s),

          // ✅ no Expanded here (prevents infinite height crash)
          Text(
            v,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.2 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),

          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCardModern extends StatelessWidget {
  const _MetricCardModern({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value;
    final st = status.trim();

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            children: [
              Container(
                width: 34 * s,
                height: 34 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(icon, size: 18 * s, color: Colors.white),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),

          Text(
            v,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),

          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.s, required this.text});
  final double s;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: _Ui.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * s,
            height: 8 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Ui.brandGrad,
            ),
          ),
          SizedBox(width: 8 * s),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w800,
                color: _Ui.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardModern extends StatelessWidget {
  const _SummaryCardModern({
    required this.s,
    required this.title,
    required this.summary,
  });

  final double s;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34 * s,
                height: 34 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 18 * s,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              // Icon(
              //   Icons.chevron_right_rounded,
              //   color: _Ui.subInk,
              //   size: 22 * s,
              // ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            summary.trim().isEmpty ? "N/A" : summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// ✅ Scan Failed View (SAME behavior as 4-wheeler)
// NOTE: This view is only shown when AuthBloc emits TwoWheelerStatus.failure
// (including the "is_tire=false" validation).
// ==============================

class _ThemedScanFailedView extends StatelessWidget {
  const _ThemedScanFailedView({
    required this.s,
    required this.message,
    required this.gradient,
    required this.onRetake,
    required this.onRetry,
  });

  final double s;
  final String message;
  final LinearGradient gradient;
  final VoidCallback onRetake;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16 * s),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 360 * s),
                  padding: EdgeInsets.fromLTRB(18 * s, 44 * s, 18 * s, 18 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20 * s),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan Failed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 18 * s,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 13.8 * s,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 16 * s),
                      Row(
                        children: [
                          Expanded(
                            child: _GhostButton(
                              s: s,
                              label: 'Retake Images',
                              icon: Icons.refresh_rounded,
                              onTap: onRetake,
                            ),
                          ),
                          SizedBox(width: 12 * s),
                          Expanded(
                            child: _GradientButton(
                              s: s,
                              label: 'Retry',
                              icon: Icons.restart_alt_rounded,
                              gradient: gradient,
                              onTap: onRetry,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * s),
                      Text(
                        'Tip: Use clear photos with proper lighting and full tyre visible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 12.5 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -26 * s,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 64 * s,
                      height: 64 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.10),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 34 * s,
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

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: Colors.white),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.s,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final double s;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.5 * s),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20 * s, color: const Color(0xFF111827)),
            SizedBox(width: 8 * s),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5 * s,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



*/