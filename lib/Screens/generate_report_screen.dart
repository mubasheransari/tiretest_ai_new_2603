import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart' show AppShell;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart' as fw;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    this.frontLeftSidewallPath,
    this.frontRightSidewallPath,
    this.backLeftSidewallPath,
    this.backRightSidewallPath,
    required this.vehicleId,
    required this.userId,
    required this.token,
    this.response,
    this.fourWheelerRaw,
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String? frontLeftSidewallPath;
  final String? frontRightSidewallPath;
  final String? backLeftSidewallPath;
  final String? backRightSidewallPath;

  final String vehicleId;
  final String userId;
  final String token;

  final dynamic response;
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  static const _bg = Color(0xFFF6F7FA);
  static const _ink = Color(0xFF111827);
  static const _subInk = Color(0xFF6B7280);
  static const _line = Color(0xFFE8EAF0);

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  int _selected = 0;

  @override
  void initState() {
    super.initState();
    try {
      final userid = context.read<AuthBloc>().state.profile?.userId.toString();
      if (userid != null && userid.isNotEmpty) {
        context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
      }
    } catch (_) {}
  }


  String _safePdfName() {
    final rawRoot = widget.fourWheelerRaw ?? _safeToJson(widget.response);
    final rawData = _extractDataMap(rawRoot);
    final vin = _dash(_read(rawData, 'vin'));
    final vehicle = vin == 'N/A' ? widget.vehicleId : vin;
    final safeName = vehicle.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final time = DateTime.now().millisecondsSinceEpoch;
    return 'Car_Tyre_Report_${safeName}_$time.pdf';
  }

  List<_FourPdfItem> _buildPdfItems() {
    final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
    final d = parsed?.data;
    final rawRoot = widget.fourWheelerRaw ?? _safeToJson(widget.response);
    final rawData = _extractDataMap(rawRoot);

    dynamic sideData(dynamic typed, String rawKey) {
      return _rawSide(rawData, rawKey) ?? _safeToJson(typed) ?? typed;
    }

    return <_FourPdfItem>[
      _FourPdfItem(title: 'Front Left Tread', localPath: widget.frontLeftPath, side: sideData(d?.frontLeft, 'front_left'), isSidewall: false),
      _FourPdfItem(title: 'Front Left Sidewall', localPath: widget.frontLeftSidewallPath ?? widget.frontLeftPath, side: sideData(d?.frontLeft, 'front_left'), isSidewall: true),
      _FourPdfItem(title: 'Front Right Tread', localPath: widget.frontRightPath, side: sideData(d?.frontRight, 'front_right'), isSidewall: false),
      _FourPdfItem(title: 'Front Right Sidewall', localPath: widget.frontRightSidewallPath ?? widget.frontRightPath, side: sideData(d?.frontRight, 'front_right'), isSidewall: true),
      _FourPdfItem(title: 'Back Left Tread', localPath: widget.backLeftPath, side: sideData(d?.backLeft, 'back_left'), isSidewall: false),
      _FourPdfItem(title: 'Back Left Sidewall', localPath: widget.backLeftSidewallPath ?? widget.backLeftPath, side: sideData(d?.backLeft, 'back_left'), isSidewall: true),
      _FourPdfItem(title: 'Back Right Tread', localPath: widget.backRightPath, side: sideData(d?.backRight, 'back_right'), isSidewall: false),
      _FourPdfItem(title: 'Back Right Sidewall', localPath: widget.backRightSidewallPath ?? widget.backRightPath, side: sideData(d?.backRight, 'back_right'), isSidewall: true),
    ];
  }

  Future<File> _createReportPdfFile({required bool temporary}) async {
    final rawRoot = widget.fourWheelerRaw ?? _safeToJson(widget.response);
    final rawData = _extractDataMap(rawRoot);

    final baseDir = temporary
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();

    final reportDir = Directory('${baseDir.path}/Reports');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    final file = File('${reportDir.path}/${_safePdfName()}');

    final bytes = await _FourWheelerPdfReport.build(
      title: 'Car Tire Inspection Report',
      vehicleId: _dash(_read(rawData, 'vehicle_id') ?? widget.vehicleId),
      vin: _dash(_read(rawData, 'vin')),
      vehicleType: _dash(_read(rawData, 'vehicle_type')),
      recordId: _dash(_read(rawData, 'record_id')),
      message: _dash(_read(rawRoot, 'message')),
      generatedAt: DateTime.now().toString(),
      items: _buildPdfItems(),
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
        text: 'Car Tire Inspection Report',
        subject: 'Car Tire Inspection Report',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF share failed: $e')),
      );
    }
  }

  Future<void> _showPdfActions() async {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _FourPdfActionDialog(
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
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
    final d = parsed?.data;
    final rawRoot = widget.fourWheelerRaw ?? _safeToJson(widget.response);
    final rawData = _extractDataMap(rawRoot);

    final items = <_ReportItem>[
      _reportItem(
        title: 'Front Left Tread',
        shortLabel: 'FL',
        localPath: widget.frontLeftPath,
        typedSide: d?.frontLeft,
        rawSide: _rawSide(rawData, 'front_left'),
        isSidewall: false,
      ),
      _reportItem(
        title: 'Front Left Sidewall',
        shortLabel: 'FL-S',
        localPath: widget.frontLeftSidewallPath ?? widget.frontLeftPath,
        typedSide: d?.frontLeft,
        rawSide: _rawSide(rawData, 'front_left'),
        isSidewall: true,
      ),
      _reportItem(
        title: 'Front Right Tread',
        shortLabel: 'FR',
        localPath: widget.frontRightPath,
        typedSide: d?.frontRight,
        rawSide: _rawSide(rawData, 'front_right'),
        isSidewall: false,
      ),
      _reportItem(
        title: 'Front Right Sidewall',
        shortLabel: 'FR-S',
        localPath: widget.frontRightSidewallPath ?? widget.frontRightPath,
        typedSide: d?.frontRight,
        rawSide: _rawSide(rawData, 'front_right'),
        isSidewall: true,
      ),
      _reportItem(
        title: 'Back Left Tread',
        shortLabel: 'BL',
        localPath: widget.backLeftPath,
        typedSide: d?.backLeft,
        rawSide: _rawSide(rawData, 'back_left'),
        isSidewall: false,
      ),
      _reportItem(
        title: 'Back Left Sidewall',
        shortLabel: 'BL-S',
        localPath: widget.backLeftSidewallPath ?? widget.backLeftPath,
        typedSide: d?.backLeft,
        rawSide: _rawSide(rawData, 'back_left'),
        isSidewall: true,
      ),
      _reportItem(
        title: 'Back Right Tread',
        shortLabel: 'BR',
        localPath: widget.backRightPath,
        typedSide: d?.backRight,
        rawSide: _rawSide(rawData, 'back_right'),
        isSidewall: false,
      ),
      _reportItem(
        title: 'Back Right Sidewall',
        shortLabel: 'BR-S',
        localPath: widget.backRightSidewallPath ?? widget.backRightPath,
        typedSide: d?.backRight,
        rawSide: _rawSide(rawData, 'back_right'),
        isSidewall: true,
      ),
    ];

    final selected = items[_selected.clamp(0, items.length - 1)];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => AppShell()),
              (route) => false,
            );
          },
        ),
        centerTitle: true,
        title: Text(
          'Inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Save / Share PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.black),
            onPressed: _showPdfActions,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // _VehicleHeaderCard(
            //   s: s,
            //   vehicleId: _dash(_read(rawData, 'vehicle_id') ?? widget.vehicleId),
            //   vin: _dash(_read(rawData, 'vin')),
            //   vehicleType: _dash(_read(rawData, 'vehicle_type')),
            //   recordId: _dash(_read(rawData, 'record_id')),
            // ),
            // SizedBox(height: 8 * s),
            SizedBox(
              height: 160 * s,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 14 * s),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(width: 10 * s),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return _WheelImageCard(
                    s: s,
                    image: item.image,
                    label: item.shortLabel,
                    title: item.title,
                    selected: i == _selected,
                    gradient: _brandGrad,
                    onTap: () => setState(() => _selected = i),
                  );
                },
              ),
            ),
            SizedBox(height: 10 * s),
            _ReportChips(
              s: s,
              items: items,
              selected: _selected,
              gradient: _brandGrad,
              onSelect: (i) => setState(() => _selected = i),
            ),
            SizedBox(height: 10 * s),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14 * s, 0, 14 * s, 16 * s),
                children: [
                  _SelectedImageCard(s: s, item: selected, gradient: _brandGrad),
                  SizedBox(height: 12 * s),
                  _MetricGrid(s: s, tyre: selected.tyre, isSidewall: selected.isSidewall, gradient: _brandGrad),
                  if (selected.isSidewall) ...[
                    SizedBox(height: 12 * s),
                    _SidewallDetailsCard(s: s, tyre: selected.tyre, gradient: _brandGrad),
                  ],
                  SizedBox(height: 12 * s),
                  _ReportSummaryCard(
                    s: s,
                    gradient: _brandGrad,
                    tyre: selected.tyre,
                    summary: _composeFullSummary(selected.tyre),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ReportItem _reportItem({
    required String title,
    required String shortLabel,
    required String localPath,
    required fw.FourWheelerTyreSide? typedSide,
    required Map<String, dynamic>? rawSide,
    required bool isSidewall,
  }) {
    return _ReportItem(
      title: title,
      shortLabel: shortLabel,
      isSidewall: isSidewall,
      image: _imgProvider(localPath: localPath, apiValue: _read(rawSide, 'image')),
      tyre: _tyreUiFromAny(label: title, typedSide: typedSide, rawSide: rawSide),
    );
  }

  _TyreUi _tyreUiFromAny({
    required String label,
    required fw.FourWheelerTyreSide? typedSide,
    required Map<String, dynamic>? rawSide,
  }) {
    final sideJson = rawSide ?? _safeToJson(typedSide) ?? <String, dynamic>{};
    final sidewall = _asMap(_read(sideJson, 'sidewall')) ?? <String, dynamic>{};
    final sidewallDamage = _asMap(_read(sidewall, 'sidewall_damage')) ?? <String, dynamic>{};
    final tirePressure = _asMap(_read(sideJson, 'tire_pressure')) ?? _asMap(_read(sideJson, 'pressure')) ?? <String, dynamic>{};

    final isTire = _read(sideJson, 'is_tire') ?? _read(sidewall, 'is_tire');
    final condition = _firstText([
      _read(sideJson, 'status'),
      _read(sideJson, 'condition'),
      typedSide?.condition,
    ], fallback: isTire == false ? 'Not a tyre' : 'N/A');

    final treadRaw = _read(sideJson, 'tread_depth') ?? typedSide?.treadDepth;
    final treadDepth = _formatTread(treadRaw);

    final wear = _firstText([
      _read(sideJson, 'wear_patterns'),
      typedSide?.wearPatterns,
    ], fallback: 'N/A');

    final summary = _firstText([
      _read(sideJson, 'summary'),
      typedSide?.summary,
    ], fallback: 'N/A');

    final pressureStatus = _firstText([_read(tirePressure, 'status')], fallback: 'N/A');
    final pressureReason = _firstText([_read(tirePressure, 'reason')], fallback: 'N/A');
    final pressureConfidence = _firstText([_read(tirePressure, 'confidence')], fallback: 'N/A');

    final damageStatus = _firstText([_read(sidewallDamage, 'status')], fallback: condition);
    final damageDescription = _firstText([_read(sidewallDamage, 'description')], fallback: wear);

    return _TyreUi(
      label: label,
      treadDepth: isTire == false ? 'N/A' : treadDepth,
      tyreStatus: isTire == false ? 'Not a tyre' : condition,
      wearPatterns: wear,
      pressureStatus: pressureStatus,
      pressureReason: pressureReason,
      pressureConfidence: pressureConfidence,
      summary: summary,
      brand: _firstText([_read(sidewall, 'brand')], fallback: 'N/A'),
      model: _firstText([_read(sidewall, 'model')], fallback: 'N/A'),
      size: _firstText([_read(sidewall, 'size')], fallback: 'N/A'),
      width: _firstText([_read(sidewall, 'width')], fallback: 'N/A'),
      aspectRatio: _firstText([_read(sidewall, 'aspect_ratio')], fallback: 'N/A'),
      rimDiameter: _firstText([_read(sidewall, 'rim_diameter')], fallback: 'N/A'),
      loadIndex: _firstText([_read(sidewall, 'load_index')], fallback: 'N/A'),
      speedRating: _firstText([_read(sidewall, 'speed_rating')], fallback: 'N/A'),
      manufacturingDate: _firstText([_read(sidewall, 'manufacturing_date')], fallback: 'N/A'),
      sidewallIsTire: _firstText([_read(sidewall, 'is_tire')], fallback: 'N/A'),
      sidewallConfidence: _firstText([_read(sidewall, 'confidence')], fallback: 'N/A'),
      sidewallDamageStatus: damageStatus,
      sidewallDamageDescription: damageDescription,
    );
  }

  String _composeFullSummary(_TyreUi t) {
    return [
      if (t.summary != 'N/A') t.summary,
      'Tread Depth: ${t.treadDepth}',
      'Status: ${t.tyreStatus}',
      'Wear Patterns: ${t.wearPatterns}',
      'Tire Pressure: ${t.pressureStatus}',
      'Pressure Reason: ${t.pressureReason}',
      'Pressure Confidence: ${t.pressureConfidence}',
      'Sidewall Brand: ${t.brand}',
      'Sidewall Model: ${t.model}',
      'Sidewall Size: ${t.size}',
      'Sidewall Damage: ${t.sidewallDamageStatus} - ${t.sidewallDamageDescription}',
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  fw.ResponseFourWheeler? _parseFourWheeler(Map<String, dynamic>? rawOverride, dynamic response) {
    try {
      if (response is fw.ResponseFourWheeler) return response;
      final raw = rawOverride ?? _safeToJson(response);
      if (raw == null) return null;
      return fw.ResponseFourWheeler.fromJson(raw.containsKey('data') ? raw : {'data': raw, 'message': ''});
    } catch (_) {
      return null;
    }
  }

  ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
    final apiStr = _asNonEmptyString(apiValue);
    if (apiStr != null) {
      if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) return NetworkImage(apiStr);
      if (apiStr.startsWith('data:image')) {
        try {
          return MemoryImage(base64Decode(apiStr.split(',').last));
        } catch (_) {}
      }
      if (apiStr.length > 100 && !apiStr.contains(' ')) {
        try {
          return MemoryImage(base64Decode(apiStr));
        } catch (_) {}
      }
    }
    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _extractDataMap(Map<String, dynamic>? root) {
    if (root == null) return null;
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return root;
  }

  Map<String, dynamic>? _rawSide(Map<String, dynamic>? data, String key) {
    final v = data == null ? null : data[key];
    return _asMap(v);
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);
    if (obj is String) {
      try {
        final decoded = jsonDecode(obj);
        return _asMap(decoded);
      } catch (_) {}
    }
    try {
      return _asMap((obj as dynamic).toJson());
    } catch (_) {}
    try {
      return _asMap(jsonDecode(jsonEncode(obj)));
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  dynamic _read(dynamic obj, String key) {
    if (obj == null) return null;
    if (obj is Map) return obj[key];
    try {
      final j = (obj as dynamic).toJson();
      if (j is Map) return j[key];
    } catch (_) {}
    return null;
  }

  String _firstText(List<dynamic> values, {required String fallback}) {
    for (final v in values) {
      final s = _asNonEmptyString(v);
      if (s != null) return s;
    }
    return fallback;
  }

  String _formatTread(dynamic v) {
    if (v == null) return 'N/A';
    if (v is num) return '${v.toStringAsFixed(1)} mm';
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return 'N/A';
    return s.toLowerCase().contains('mm') ? s : '$s mm';
  }

  String _dash(dynamic v) => _asNonEmptyString(v) ?? 'N/A';

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
}

class _ReportItem {
  const _ReportItem({required this.title, required this.shortLabel, required this.image, required this.tyre, required this.isSidewall});
  final String title;
  final String shortLabel;
  final ImageProvider image;
  final _TyreUi tyre;
  final bool isSidewall;
}

class _VehicleHeaderCard extends StatelessWidget {
  const _VehicleHeaderCard({required this.s, required this.vehicleId, required this.vin, required this.vehicleType, required this.recordId});
  final double s;
  final String vehicleId;
  final String vin;
  final String vehicleType;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 0),
      padding: EdgeInsets.all(14 * s),
      decoration: _cardDeco(18 * s),
      child: Column(
        children: [
          _infoRow(s, 'Record ID', recordId),
          _infoRow(s, 'Vehicle ID', vehicleId),
          _infoRow(s, 'VIN', vin),
          _infoRow(s, 'Vehicle Type', vehicleType.toUpperCase()),
        ],
      ),
    );
  }
}

class _WheelImageCard extends StatelessWidget {
  const _WheelImageCard({required this.s, required this.image, required this.label, required this.title, required this.selected, required this.gradient, required this.onTap});
  final double s;
  final ImageProvider image;
  final String label;
  final String title;
  final bool selected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 120 * s,
        padding: EdgeInsets.all(selected ? 3 * s : 0),
        decoration: BoxDecoration(
          gradient: selected ? gradient : null,
          borderRadius: BorderRadius.circular(18 * s),
        ),
        child: Container(
          decoration: _cardDeco(16 * s),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16 * s)),
                  child: Image(image: image, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 7 * s),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w900, color: selected ? const Color(0xFF7F53FD) : const Color(0xFF111827)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportChips extends StatelessWidget {
  const _ReportChips({required this.s, required this.items, required this.selected, required this.gradient, required this.onSelect});
  final double s;
  final List<_ReportItem> items;
  final int selected;
  final LinearGradient gradient;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42 * s,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 14 * s),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 8 * s),
        itemBuilder: (_, i) {
          final isSel = i == selected;
          return InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 13 * s, vertical: 9 * s),
              decoration: BoxDecoration(
                gradient: isSel ? gradient : null,
                color: isSel ? null : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE8EAF0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 6))],
              ),
              child: Text(items[i].shortLabel, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13 * s, fontWeight: FontWeight.w900, color: isSel ? Colors.white : const Color(0xFF111827))),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedImageCard extends StatelessWidget {
  const _SelectedImageCard({required this.s, required this.item, required this.gradient});
  final double s;
  final _ReportItem item;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _gradIcon(s, item.isSidewall ? Icons.tire_repair_rounded : Icons.straighten_rounded, gradient),
            SizedBox(width: 10 * s),
            Expanded(child: Text(item.title, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 17 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
            _pill(s, item.isSidewall ? 'Sidewall' : 'Tread'),
          ]),
          SizedBox(height: 12 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * s),
            child: AspectRatio(aspectRatio: 16 / 10, child: Image(image: item.image, fit: BoxFit.cover)),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.s, required this.tyre, required this.isSidewall, required this.gradient});
  final double s;
  final _TyreUi tyre;
  final bool isSidewall;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _InfoMetricCard(s: s, title: 'Tread Depth', value: tyre.treadDepth, status: 'Status: ${tyre.tyreStatus}', icon: Icons.straighten_rounded, gradient: gradient)),
        SizedBox(width: 12 * s),
        Expanded(child: _InfoMetricCard(s: s, title: 'Tire Pressure', value: tyre.pressureStatus, status: 'Confidence: ${tyre.pressureConfidence}', icon: Icons.speed_rounded, gradient: gradient)),
      ]),
      SizedBox(height: 12 * s),
      _InfoMetricCard(s: s, title: isSidewall ? 'Sidewall Damage' : 'Wear Patterns', value: isSidewall ? tyre.sidewallDamageDescription : tyre.wearPatterns, status: isSidewall ? 'Status: ${tyre.sidewallDamageStatus}' : 'Status: ${tyre.tyreStatus}', icon: Icons.report_gmailerrorred_rounded, gradient: gradient, fullWidth: true),
      SizedBox(height: 12 * s),
      _InfoMetricCard(s: s, title: 'Pressure Reason', value: tyre.pressureReason, status: 'Pressure Status: ${tyre.pressureStatus}', icon: Icons.info_outline_rounded, gradient: gradient, fullWidth: true),
    ]);
  }
}

class _SidewallDetailsCard extends StatelessWidget {
  const _SidewallDetailsCard({required this.s, required this.tyre, required this.gradient});
  final double s;
  final _TyreUi tyre;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Is Tire', tyre.sidewallIsTire],
      ['Brand', tyre.brand],
      ['Model', tyre.model],
      ['Size', tyre.size],
      ['Width', tyre.width],
      ['Aspect Ratio', tyre.aspectRatio],
      ['Rim Diameter', tyre.rimDiameter],
      ['Load Index', tyre.loadIndex],
      ['Speed Rating', tyre.speedRating],
      ['Manufacturing Date', tyre.manufacturingDate],
      ['Damage Status', tyre.sidewallDamageStatus],
      ['Damage Description', tyre.sidewallDamageDescription],
      ['Confidence', tyre.sidewallConfidence],
    ];

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _cardDeco(20 * s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_gradIcon(s, Icons.tire_repair_rounded, gradient), SizedBox(width: 10 * s), Text('Sidewall Details', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 17 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))]),
        SizedBox(height: 12 * s),
        ...rows.map((r) => _infoRow(s, r[0], r[1])),
      ]),
    );
  }
}

class _InfoMetricCard extends StatelessWidget {
  const _InfoMetricCard({required this.s, required this.title, required this.value, required this.status, required this.icon, required this.gradient, this.fullWidth = false});
  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final LinearGradient gradient;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(15 * s),
      decoration: _cardDeco(18 * s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_gradIcon(s, icon, gradient), SizedBox(width: 8 * s), Expanded(child: Text(title, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14.5 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))))]),
        SizedBox(height: 10 * s),
        Text(value.trim().isEmpty ? 'N/A' : value, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.5 * s, fontWeight: FontWeight.w700, color: const Color(0xFF111827), height: 1.35)),
        SizedBox(height: 8 * s),
        _pill(s, status),
      ]),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({required this.s, required this.gradient, required this.tyre, required this.summary});
  final double s;
  final LinearGradient gradient;
  final _TyreUi tyre;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: _cardDeco(20 * s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_gradIcon(s, Icons.description_outlined, gradient), SizedBox(width: 10 * s), Expanded(child: Text('Report Summary', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 18 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))))]),
        SizedBox(height: 10 * s),
        Text(tyre.label, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14.5 * s, fontWeight: FontWeight.w900, foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 250, 40)))),
        SizedBox(height: 8 * s),
        Text(summary, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.5 * s, fontWeight: FontWeight.w600, height: 1.42, color: const Color(0xFF222222))),
      ]),
    );
  }
}

class _TyreUi {
  _TyreUi({
    required this.label,
    required this.treadDepth,
    required this.tyreStatus,
    required this.wearPatterns,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
    required this.brand,
    required this.model,
    required this.size,
    required this.width,
    required this.aspectRatio,
    required this.rimDiameter,
    required this.loadIndex,
    required this.speedRating,
    required this.manufacturingDate,
    required this.sidewallIsTire,
    required this.sidewallConfidence,
    required this.sidewallDamageStatus,
    required this.sidewallDamageDescription,
  });

  final String label;
  final String treadDepth;
  final String tyreStatus;
  final String wearPatterns;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;
  final String summary;
  final String brand;
  final String model;
  final String size;
  final String width;
  final String aspectRatio;
  final String rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final String sidewallIsTire;
  final String sidewallConfidence;
  final String sidewallDamageStatus;
  final String sidewallDamageDescription;
}

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.frontLeftSidewallPath,
    required this.frontRightSidewallPath,
    required this.backLeftSidewallPath,
    required this.backRightSidewallPath,
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = 'car',
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;
  final String frontLeftSidewallPath;
  final String frontRightSidewallPath;
  final String backLeftSidewallPath;
  final String backRightSidewallPath;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;
  final String vehicleType;

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  bool _fired = false;
  bool _navigated = false;
  bool _adPlayStarted = false;
  fw.ResponseFourWheeler? _apiResponse;
  VideoPlayerController? _videoCtrl;
  String _currentUrl = '';

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
    _startUpload();
  }

  void _startUpload() {
    if (_fired) return;
    _fired = true;
    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,
        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backRightTyreId,
        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
        frontLeftSidewallPath: widget.frontLeftSidewallPath,
        frontRightSidewallPath: widget.frontRightSidewallPath,
        backLeftSidewallPath: widget.backLeftSidewallPath,
        backRightSidewallPath: widget.backRightSidewallPath,
      ),
    );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentUrl == u && _videoCtrl != null) return;
    _currentUrl = u;
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
    _currentUrl = '';
    _adPlayStarted = false;
    try {
      vc?.pause();
    } catch (_) {}
    vc?.dispose();
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);
    if (obj is String) {
      try {
        final decoded = jsonDecode(obj);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    try {
      final j = (obj as dynamic).toJson();
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return null;
  }

  void _navigateToResult() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _stopVideo();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          frontLeftPath: widget.frontLeftPath,
          frontRightPath: widget.frontRightPath,
          backLeftPath: widget.backLeftPath,
          backRightPath: widget.backRightPath,
          frontLeftSidewallPath: widget.frontLeftSidewallPath,
          frontRightSidewallPath: widget.frontRightSidewallPath,
          backLeftSidewallPath: widget.backLeftSidewallPath,
          backRightSidewallPath: widget.backRightSidewallPath,
          vehicleId: widget.vehicleId,
          userId: widget.userId,
          token: widget.token,
          response: _apiResponse,
          fourWheelerRaw: _safeToJson(_apiResponse),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media ||
                p.adsStatus != c.adsStatus ||
                p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              final isUploading = state.fourWheelerStatus == FourWheelerStatus.uploading;
              final media = state.selectedAd?.media.trim() ?? '';
              if (isUploading && media.isNotEmpty && !_adPlayStarted) {
                _adPlayStarted = true;
                _playVideo(media);
              }
              if (state.fourWheelerStatus == FourWheelerStatus.success ||
                  state.fourWheelerStatus == FourWheelerStatus.failure) {
                _stopVideo();
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
                _navigateToResult();
              }
            },
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
          builder: (context, state) {
            final st = state.fourWheelerStatus;
            if (st == FourWheelerStatus.uploading) {
              return Stack(
                children: [
                  _FullscreenVideoOnly(controller: _videoCtrl),
                  Positioned(left: 16 * s, right: 16 * s, bottom: 22 * s, child: _GeneratingOverlayModern(s: s)),
                ],
              );
            }
            if (st == FourWheelerStatus.failure) {
              final msg = (state.fourWheelerError ?? '').trim().isEmpty
                  ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                  : state.fourWheelerError!.trim();
              return _ThemedScanFailedView(
                s: s,
                message: msg,
                gradient: _brandGrad,
                onRetake: () => Navigator.of(context).pop('retake'),
                onRetry: () {
                  _stopVideo();
                  setState(() {
                    _fired = false;
                    _navigated = false;
                  });
                  _startUpload();
                },
              );
            }
            return Stack(
              children: [
                _FullscreenVideoOnly(controller: _videoCtrl),
                Positioned(left: 16 * s, right: 16 * s, bottom: 22 * s, child: _GeneratingOverlayModern(s: s)),
              ],
            );
          },
        ),
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
      decoration: BoxDecoration(color: Colors.black.withOpacity(.42), borderRadius: BorderRadius.circular(18 * s), border: Border.all(color: Colors.white.withOpacity(.12))),
      child: Row(children: [
        const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
        SizedBox(width: 12 * s),
        Expanded(child: Text('Generating report… Please wait', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14 * s, fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    );
  }
}

class _ThemedScanFailedView extends StatelessWidget {
  const _ThemedScanFailedView({required this.s, required this.message, required this.gradient, required this.onRetake, required this.onRetry});
  final double s;
  final String message;
  final LinearGradient gradient;
  final VoidCallback onRetake;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16 * s),
            child: Container(
              padding: EdgeInsets.all(18 * s),
              decoration: _cardDeco(20 * s),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 64 * s, height: 64 * s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient), child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 34 * s)),
                SizedBox(height: 12 * s),
                Text('Scan Failed', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 18 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
                SizedBox(height: 8 * s),
                Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.8 * s, fontWeight: FontWeight.w600, height: 1.35, color: const Color(0xFF6B7280))),
                SizedBox(height: 16 * s),
                Row(children: [
                  Expanded(child: _GhostButton(s: s, label: 'Retake Images', icon: Icons.refresh_rounded, onTap: onRetake)),
                  SizedBox(width: 12 * s),
                  Expanded(child: _GradientButton(s: s, label: 'Retry', icon: Icons.restart_alt_rounded, gradient: gradient, onTap: onRetry)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.s, required this.label, required this.icon, required this.gradient, required this.onTap});
  final double s;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.5 * s),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14 * s)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20 * s, color: Colors.white), SizedBox(width: 8 * s), Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w900, fontSize: 14.5 * s, color: Colors.white))]),
        ),
      );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.s, required this.label, required this.icon, required this.onTap});
  final double s;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.5 * s),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14 * s), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20 * s, color: const Color(0xFF111827)), SizedBox(width: 8 * s), Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w900, fontSize: 14.5 * s, color: const Color(0xFF111827)))]),
        ),
      );
}

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});
  final VideoPlayerController? controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
      ),
    );
  }
}

BoxDecoration _cardDeco(double r) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: const Color(0xFFE8EAF0)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 22, offset: const Offset(0, 10))],
    );

Widget _gradIcon(double s, IconData icon, LinearGradient gradient) => Container(
      width: 34 * s,
      height: 34 * s,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12 * s), gradient: gradient),
      child: Icon(icon, size: 18 * s, color: Colors.white),
    );

Widget _pill(double s, String text) => Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 6 * s),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0xFFF3F4F6), border: Border.all(color: const Color(0xFFE8EAF0))),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 11.5 * s, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
    );

Widget _infoRow(double s, String label, String value) => Padding(
      padding: EdgeInsets.only(bottom: 7 * s),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w800, color: const Color(0xFF6B7280)))),
        SizedBox(width: 10 * s),
        Expanded(flex: 6, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
      ]),
    );

// ======================================================
// PDF SAVE / SHARE SUPPORT FOR 4-WHEELER REPORT
// ======================================================

class _FourPdfItem {
  const _FourPdfItem({
    required this.title,
    required this.localPath,
    required this.side,
    required this.isSidewall,
  });

  final String title;
  final String localPath;
  final dynamic side;
  final bool isSidewall;
}

class _FourWheelerPdfReport {
  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _softBg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _blue = PdfColor.fromInt(0xFF4F7BFF);

  static String _str(dynamic v, {String fallback = 'N/A'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
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
            width: 120,
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
              style: const pw.TextStyle(fontSize: 10, color: _text, height: 1.25),
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

  static _FourPdfTyreData _toTyreData({
    required _FourPdfItem item,
    required pw.ImageProvider? image,
  }) {
    final side = item.side;
    final sidewall = _read(side, 'sidewall');
    final sidewallDamage = _read(sidewall, 'sidewall_damage');
    final pressure = _read(side, 'tire_pressure') ?? _read(side, 'pressure');

    final status = _str(_read(side, 'status') ?? _read(side, 'condition'));

    final treadRaw = _str(_read(side, 'tread_depth'));
    final treadDepth = treadRaw == 'N/A'
        ? 'N/A'
        : treadRaw.toLowerCase().contains('mm')
            ? treadRaw
            : '$treadRaw mm';

    return _FourPdfTyreData(
      title: item.title,
      image: image,
      isSidewall: item.isSidewall,
      treadDepth: treadDepth,
      status: status,
      wearPatterns: _str(_read(side, 'wear_patterns')),
      pressureStatus: _str(_read(pressure, 'status')),
      pressureReason: _str(_read(pressure, 'reason')),
      pressureConfidence: _str(_read(pressure, 'confidence')),
      summary: _str(_read(side, 'summary')),
      sidewallIsTire: _str(_read(sidewall, 'is_tire') ?? _read(side, 'is_tire')),
      brand: _str(_read(sidewall, 'brand')),
      model: _str(_read(sidewall, 'model')),
      size: _str(_read(sidewall, 'size')),
      width: _str(_read(sidewall, 'width')),
      aspectRatio: _str(_read(sidewall, 'aspect_ratio')),
      rimDiameter: _str(_read(sidewall, 'rim_diameter')),
      loadIndex: _str(_read(sidewall, 'load_index')),
      speedRating: _str(_read(sidewall, 'speed_rating')),
      manufacturingDate: _str(_read(sidewall, 'manufacturing_date')),
      sidewallDamageStatus: _str(_read(sidewallDamage, 'status')),
      sidewallDamageDescription: _str(_read(sidewallDamage, 'description')),
      sidewallConfidence: _str(_read(sidewall, 'confidence')),
    );
  }

  static pw.Widget _tyreTile(_FourPdfTyreData t) {
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
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _text),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _softBg,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  t.isSidewall ? 'Sidewall' : 'Tread',
                  style: pw.TextStyle(fontSize: 8.5, color: _muted, fontWeight: pw.FontWeight.bold),
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
          pw.Text('Tire Pressure', style: pw.TextStyle(fontSize: 10.5, color: _text, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          _kv('Status', t.pressureStatus),
          _kv('Reason', t.pressureReason),
          _kv('Confidence', t.pressureConfidence),
          pw.Divider(color: _border),
          pw.Text('Sidewall Details', style: pw.TextStyle(fontSize: 10.5, color: _text, fontWeight: pw.FontWeight.bold)),
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
          _kv('Sidewall Confidence', t.sidewallConfidence),
          pw.Divider(color: _border),
          pw.Text('Summary', style: pw.TextStyle(fontSize: 10.5, color: _text, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(t.summary, style: const pw.TextStyle(fontSize: 10, color: _text, height: 1.35)),
        ],
      ),
    );
  }

  static Future<List<int>> build({
    required String title,
    required String vehicleId,
    required String vin,
    required String vehicleType,
    required String recordId,
    required String message,
    required String generatedAt,
    required List<_FourPdfItem> items,
  }) async {
    final pdfItems = <_FourPdfTyreData>[];

    for (final item in items) {
      pdfItems.add(
        _toTyreData(
          item: item,
          image: await _localImage(item.localPath),
        ),
      );
    }

    final doc = pw.Document();

    void addTyrePage({
      required String pageTitle,
      required _FourPdfTyreData item,
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
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _blue),
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
                      _kv('Record ID', recordId),
                      _kv('Vehicle ID', vehicleId),
                      _kv('VIN', vin),
                      _kv('Vehicle Type', vehicleType.toUpperCase()),
                      _kv('API Message', message),
                      _kv('Generated At', generatedAt),
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

    for (var i = 0; i < pdfItems.length; i++) {
      addTyrePage(
        pageTitle: i == 0 ? title : '$title - ${pdfItems[i].title}',
        item: pdfItems[i],
        showHeader: i == 0,
      );
    }

    return doc.save();
  }
}

class _FourPdfTyreData {
  const _FourPdfTyreData({
    required this.title,
    required this.image,
    required this.isSidewall,
    required this.treadDepth,
    required this.status,
    required this.wearPatterns,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
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
  final bool isSidewall;
  final String treadDepth;
  final String status;
  final String wearPatterns;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;
  final String summary;
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

class _FourPdfActionDialog extends StatelessWidget {
  const _FourPdfActionDialog({
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
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Save or share the inspection report as a PDF file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s)),
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
                  gradient: LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
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

// class InspectionResultScreen extends StatefulWidget {
//   const InspectionResultScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     this.frontLeftSidewallPath,
//     this.frontRightSidewallPath,
//     this.backLeftSidewallPath,
//     this.backRightSidewallPath,
//     required this.vehicleId,
//     required this.userId,
//     required this.token,
//     this.response,
//     this.fourWheelerRaw,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String? frontLeftSidewallPath;
//   final String? frontRightSidewallPath;
//   final String? backLeftSidewallPath;
//   final String? backRightSidewallPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final dynamic response;
//   final Map<String, dynamic>? fourWheelerRaw;

//   @override
//   State<InspectionResultScreen> createState() => _InspectionResultScreenState();
// }

// class _InspectionResultScreenState extends State<InspectionResultScreen> {
//   static const _bg = Color(0xFFF6F7FA);
//   static const _ink = Color(0xFF111827);
//   static const _subInk = Color(0xFF6B7280);
//   static const _line = Color(0xFFE8EAF0);

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   int _selected = 0;

//   @override
//   void initState() {
//     super.initState();
//     try {
//       final userid = context.read<AuthBloc>().state.profile?.userId.toString();
//       if (userid != null && userid.isNotEmpty) {
//         context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
//       }
//     } catch (_) {}
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
//     final d = parsed?.data;
//     final rawRoot = widget.fourWheelerRaw ?? _safeToJson(widget.response);
//     final rawData = _extractDataMap(rawRoot);

//     final items = <_ReportItem>[
//       _reportItem(
//         title: 'Front Left Tread',
//         shortLabel: 'FL',
//         localPath: widget.frontLeftPath,
//         typedSide: d?.frontLeft,
//         rawSide: _rawSide(rawData, 'front_left'),
//         isSidewall: false,
//       ),
//       _reportItem(
//         title: 'Front Left Sidewall',
//         shortLabel: 'FL-S',
//         localPath: widget.frontLeftSidewallPath ?? widget.frontLeftPath,
//         typedSide: d?.frontLeft,
//         rawSide: _rawSide(rawData, 'front_left'),
//         isSidewall: true,
//       ),
//       _reportItem(
//         title: 'Front Right Tread',
//         shortLabel: 'FR',
//         localPath: widget.frontRightPath,
//         typedSide: d?.frontRight,
//         rawSide: _rawSide(rawData, 'front_right'),
//         isSidewall: false,
//       ),
//       _reportItem(
//         title: 'Front Right Sidewall',
//         shortLabel: 'FR-S',
//         localPath: widget.frontRightSidewallPath ?? widget.frontRightPath,
//         typedSide: d?.frontRight,
//         rawSide: _rawSide(rawData, 'front_right'),
//         isSidewall: true,
//       ),
//       _reportItem(
//         title: 'Back Left Tread',
//         shortLabel: 'BL',
//         localPath: widget.backLeftPath,
//         typedSide: d?.backLeft,
//         rawSide: _rawSide(rawData, 'back_left'),
//         isSidewall: false,
//       ),
//       _reportItem(
//         title: 'Back Left Sidewall',
//         shortLabel: 'BL-S',
//         localPath: widget.backLeftSidewallPath ?? widget.backLeftPath,
//         typedSide: d?.backLeft,
//         rawSide: _rawSide(rawData, 'back_left'),
//         isSidewall: true,
//       ),
//       _reportItem(
//         title: 'Back Right Tread',
//         shortLabel: 'BR',
//         localPath: widget.backRightPath,
//         typedSide: d?.backRight,
//         rawSide: _rawSide(rawData, 'back_right'),
//         isSidewall: false,
//       ),
//       _reportItem(
//         title: 'Back Right Sidewall',
//         shortLabel: 'BR-S',
//         localPath: widget.backRightSidewallPath ?? widget.backRightPath,
//         typedSide: d?.backRight,
//         rawSide: _rawSide(rawData, 'back_right'),
//         isSidewall: true,
//       ),
//     ];

//     final selected = items[_selected.clamp(0, items.length - 1)];

//     return Scaffold(
//       backgroundColor: _bg,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black),
//           onPressed: () {
//             Navigator.of(context).pushAndRemoveUntil(
//               MaterialPageRoute(builder: (_) => AppShell()),
//               (route) => false,
//             );
//           },
//         ),
//         centerTitle: true,
//         title: Text(
//           'Inspection Report',
//           style: TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontSize: 20 * s,
//             fontWeight: FontWeight.w900,
//             color: _ink,
//           ),
//         ),
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // _VehicleHeaderCard(
//             //   s: s,
//             //   vehicleId: _dash(_read(rawData, 'vehicle_id') ?? widget.vehicleId),
//             //   vin: _dash(_read(rawData, 'vin')),
//             //   vehicleType: _dash(_read(rawData, 'vehicle_type')),
//             //   recordId: _dash(_read(rawData, 'record_id')),
//             // ),
//             // SizedBox(height: 8 * s),
//             SizedBox(
//               height: 160 * s,
//               child: ListView.separated(
//                 padding: EdgeInsets.symmetric(horizontal: 14 * s),
//                 scrollDirection: Axis.horizontal,
//                 itemCount: items.length,
//                 separatorBuilder: (_, __) => SizedBox(width: 10 * s),
//                 itemBuilder: (_, i) {
//                   final item = items[i];
//                   return _WheelImageCard(
//                     s: s,
//                     image: item.image,
//                     label: item.shortLabel,
//                     title: item.title,
//                     selected: i == _selected,
//                     gradient: _brandGrad,
//                     onTap: () => setState(() => _selected = i),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 10 * s),
//             _ReportChips(
//               s: s,
//               items: items,
//               selected: _selected,
//               gradient: _brandGrad,
//               onSelect: (i) => setState(() => _selected = i),
//             ),
//             SizedBox(height: 10 * s),
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.fromLTRB(14 * s, 0, 14 * s, 16 * s),
//                 children: [
//                   _SelectedImageCard(s: s, item: selected, gradient: _brandGrad),
//                   SizedBox(height: 12 * s),
//                   _MetricGrid(s: s, tyre: selected.tyre, isSidewall: selected.isSidewall, gradient: _brandGrad),
//                   if (selected.isSidewall) ...[
//                     SizedBox(height: 12 * s),
//                     _SidewallDetailsCard(s: s, tyre: selected.tyre, gradient: _brandGrad),
//                   ],
//                   SizedBox(height: 12 * s),
//                   _ReportSummaryCard(
//                     s: s,
//                     gradient: _brandGrad,
//                     tyre: selected.tyre,
//                     summary: _composeFullSummary(selected.tyre),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   _ReportItem _reportItem({
//     required String title,
//     required String shortLabel,
//     required String localPath,
//     required fw.FourWheelerTyreSide? typedSide,
//     required Map<String, dynamic>? rawSide,
//     required bool isSidewall,
//   }) {
//     return _ReportItem(
//       title: title,
//       shortLabel: shortLabel,
//       isSidewall: isSidewall,
//       image: _imgProvider(localPath: localPath, apiValue: _read(rawSide, 'image')),
//       tyre: _tyreUiFromAny(label: title, typedSide: typedSide, rawSide: rawSide),
//     );
//   }

//   _TyreUi _tyreUiFromAny({
//     required String label,
//     required fw.FourWheelerTyreSide? typedSide,
//     required Map<String, dynamic>? rawSide,
//   }) {
//     final sideJson = rawSide ?? _safeToJson(typedSide) ?? <String, dynamic>{};
//     final sidewall = _asMap(_read(sideJson, 'sidewall')) ?? <String, dynamic>{};
//     final sidewallDamage = _asMap(_read(sidewall, 'sidewall_damage')) ?? <String, dynamic>{};
//     final tirePressure = _asMap(_read(sideJson, 'tire_pressure')) ?? _asMap(_read(sideJson, 'pressure')) ?? <String, dynamic>{};

//     final isTire = _read(sideJson, 'is_tire') ?? _read(sidewall, 'is_tire');
//     final condition = _firstText([
//       _read(sideJson, 'status'),
//       _read(sideJson, 'condition'),
//       typedSide?.condition,
//     ], fallback: isTire == false ? 'Not a tyre' : 'N/A');

//     final treadRaw = _read(sideJson, 'tread_depth') ?? typedSide?.treadDepth;
//     final treadDepth = _formatTread(treadRaw);

//     final wear = _firstText([
//       _read(sideJson, 'wear_patterns'),
//       typedSide?.wearPatterns,
//     ], fallback: 'N/A');

//     final summary = _firstText([
//       _read(sideJson, 'summary'),
//       typedSide?.summary,
//     ], fallback: 'N/A');

//     final pressureStatus = _firstText([_read(tirePressure, 'status')], fallback: 'N/A');
//     final pressureReason = _firstText([_read(tirePressure, 'reason')], fallback: 'N/A');
//     final pressureConfidence = _firstText([_read(tirePressure, 'confidence')], fallback: 'N/A');

//     final damageStatus = _firstText([_read(sidewallDamage, 'status')], fallback: condition);
//     final damageDescription = _firstText([_read(sidewallDamage, 'description')], fallback: wear);

//     return _TyreUi(
//       label: label,
//       treadDepth: isTire == false ? 'N/A' : treadDepth,
//       tyreStatus: isTire == false ? 'Not a tyre' : condition,
//       wearPatterns: wear,
//       pressureStatus: pressureStatus,
//       pressureReason: pressureReason,
//       pressureConfidence: pressureConfidence,
//       summary: summary,
//       brand: _firstText([_read(sidewall, 'brand')], fallback: 'N/A'),
//       model: _firstText([_read(sidewall, 'model')], fallback: 'N/A'),
//       size: _firstText([_read(sidewall, 'size')], fallback: 'N/A'),
//       width: _firstText([_read(sidewall, 'width')], fallback: 'N/A'),
//       aspectRatio: _firstText([_read(sidewall, 'aspect_ratio')], fallback: 'N/A'),
//       rimDiameter: _firstText([_read(sidewall, 'rim_diameter')], fallback: 'N/A'),
//       loadIndex: _firstText([_read(sidewall, 'load_index')], fallback: 'N/A'),
//       speedRating: _firstText([_read(sidewall, 'speed_rating')], fallback: 'N/A'),
//       manufacturingDate: _firstText([_read(sidewall, 'manufacturing_date')], fallback: 'N/A'),
//       sidewallIsTire: _firstText([_read(sidewall, 'is_tire')], fallback: 'N/A'),
//       sidewallConfidence: _firstText([_read(sidewall, 'confidence')], fallback: 'N/A'),
//       sidewallDamageStatus: damageStatus,
//       sidewallDamageDescription: damageDescription,
//     );
//   }

//   String _composeFullSummary(_TyreUi t) {
//     return [
//       if (t.summary != 'N/A') t.summary,
//       'Tread Depth: ${t.treadDepth}',
//       'Status: ${t.tyreStatus}',
//       'Wear Patterns: ${t.wearPatterns}',
//       'Tire Pressure: ${t.pressureStatus}',
//       'Pressure Reason: ${t.pressureReason}',
//       'Pressure Confidence: ${t.pressureConfidence}',
//       'Sidewall Brand: ${t.brand}',
//       'Sidewall Model: ${t.model}',
//       'Sidewall Size: ${t.size}',
//       'Sidewall Damage: ${t.sidewallDamageStatus} - ${t.sidewallDamageDescription}',
//     ].where((e) => e.trim().isNotEmpty).join('\n');
//   }

//   fw.ResponseFourWheeler? _parseFourWheeler(Map<String, dynamic>? rawOverride, dynamic response) {
//     try {
//       if (response is fw.ResponseFourWheeler) return response;
//       final raw = rawOverride ?? _safeToJson(response);
//       if (raw == null) return null;
//       return fw.ResponseFourWheeler.fromJson(raw.containsKey('data') ? raw : {'data': raw, 'message': ''});
//     } catch (_) {
//       return null;
//     }
//   }

//   ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
//     final apiStr = _asNonEmptyString(apiValue);
//     if (apiStr != null) {
//       if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) return NetworkImage(apiStr);
//       if (apiStr.startsWith('data:image')) {
//         try {
//           return MemoryImage(base64Decode(apiStr.split(',').last));
//         } catch (_) {}
//       }
//       if (apiStr.length > 100 && !apiStr.contains(' ')) {
//         try {
//           return MemoryImage(base64Decode(apiStr));
//         } catch (_) {}
//       }
//     }
//     return FileImage(File(localPath));
//   }

//   Map<String, dynamic>? _extractDataMap(Map<String, dynamic>? root) {
//     if (root == null) return null;
//     final data = root['data'];
//     if (data is Map<String, dynamic>) return data;
//     if (data is Map) return Map<String, dynamic>.from(data);
//     return root;
//   }

//   Map<String, dynamic>? _rawSide(Map<String, dynamic>? data, String key) {
//     final v = data == null ? null : data[key];
//     return _asMap(v);
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;
//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);
//     if (obj is String) {
//       try {
//         final decoded = jsonDecode(obj);
//         return _asMap(decoded);
//       } catch (_) {}
//     }
//     try {
//       return _asMap((obj as dynamic).toJson());
//     } catch (_) {}
//     try {
//       return _asMap(jsonDecode(jsonEncode(obj)));
//     } catch (_) {}
//     return null;
//   }

//   Map<String, dynamic>? _asMap(dynamic v) {
//     if (v is Map<String, dynamic>) return v;
//     if (v is Map) return Map<String, dynamic>.from(v);
//     return null;
//   }

//   dynamic _read(dynamic obj, String key) {
//     if (obj == null) return null;
//     if (obj is Map) return obj[key];
//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map) return j[key];
//     } catch (_) {}
//     return null;
//   }

//   String _firstText(List<dynamic> values, {required String fallback}) {
//     for (final v in values) {
//       final s = _asNonEmptyString(v);
//       if (s != null) return s;
//     }
//     return fallback;
//   }

//   String _formatTread(dynamic v) {
//     if (v == null) return 'N/A';
//     if (v is num) return '${v.toStringAsFixed(1)} mm';
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return 'N/A';
//     return s.toLowerCase().contains('mm') ? s : '$s mm';
//   }

//   String _dash(dynamic v) => _asNonEmptyString(v) ?? 'N/A';

//   String? _asNonEmptyString(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return null;
//     return s;
//   }
// }

// class _ReportItem {
//   const _ReportItem({required this.title, required this.shortLabel, required this.image, required this.tyre, required this.isSidewall});
//   final String title;
//   final String shortLabel;
//   final ImageProvider image;
//   final _TyreUi tyre;
//   final bool isSidewall;
// }

// class _VehicleHeaderCard extends StatelessWidget {
//   const _VehicleHeaderCard({required this.s, required this.vehicleId, required this.vin, required this.vehicleType, required this.recordId});
//   final double s;
//   final String vehicleId;
//   final String vin;
//   final String vehicleType;
//   final String recordId;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 0),
//       padding: EdgeInsets.all(14 * s),
//       decoration: _cardDeco(18 * s),
//       child: Column(
//         children: [
//           _infoRow(s, 'Record ID', recordId),
//           _infoRow(s, 'Vehicle ID', vehicleId),
//           _infoRow(s, 'VIN', vin),
//           _infoRow(s, 'Vehicle Type', vehicleType.toUpperCase()),
//         ],
//       ),
//     );
//   }
// }

// class _WheelImageCard extends StatelessWidget {
//   const _WheelImageCard({required this.s, required this.image, required this.label, required this.title, required this.selected, required this.gradient, required this.onTap});
//   final double s;
//   final ImageProvider image;
//   final String label;
//   final String title;
//   final bool selected;
//   final LinearGradient gradient;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         width: 120 * s,
//         padding: EdgeInsets.all(selected ? 3 * s : 0),
//         decoration: BoxDecoration(
//           gradient: selected ? gradient : null,
//           borderRadius: BorderRadius.circular(18 * s),
//         ),
//         child: Container(
//           decoration: _cardDeco(16 * s),
//           child: Column(
//             children: [
//               Expanded(
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(16 * s)),
//                   child: Image(image: image, fit: BoxFit.cover, width: double.infinity),
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 7 * s),
//                 child: Text(
//                   label,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w900, color: selected ? const Color(0xFF7F53FD) : const Color(0xFF111827)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ReportChips extends StatelessWidget {
//   const _ReportChips({required this.s, required this.items, required this.selected, required this.gradient, required this.onSelect});
//   final double s;
//   final List<_ReportItem> items;
//   final int selected;
//   final LinearGradient gradient;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 42 * s,
//       child: ListView.separated(
//         padding: EdgeInsets.symmetric(horizontal: 14 * s),
//         scrollDirection: Axis.horizontal,
//         itemCount: items.length,
//         separatorBuilder: (_, __) => SizedBox(width: 8 * s),
//         itemBuilder: (_, i) {
//           final isSel = i == selected;
//           return InkWell(
//             onTap: () => onSelect(i),
//             borderRadius: BorderRadius.circular(999),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 180),
//               padding: EdgeInsets.symmetric(horizontal: 13 * s, vertical: 9 * s),
//               decoration: BoxDecoration(
//                 gradient: isSel ? gradient : null,
//                 color: isSel ? null : Colors.white,
//                 borderRadius: BorderRadius.circular(999),
//                 border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE8EAF0)),
//                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 6))],
//               ),
//               child: Text(items[i].shortLabel, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13 * s, fontWeight: FontWeight.w900, color: isSel ? Colors.white : const Color(0xFF111827))),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class _SelectedImageCard extends StatelessWidget {
//   const _SelectedImageCard({required this.s, required this.item, required this.gradient});
//   final double s;
//   final _ReportItem item;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: _cardDeco(20 * s),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(children: [
//             _gradIcon(s, item.isSidewall ? Icons.tire_repair_rounded : Icons.straighten_rounded, gradient),
//             SizedBox(width: 10 * s),
//             Expanded(child: Text(item.title, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 17 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
//             _pill(s, item.isSidewall ? 'Sidewall' : 'Tread'),
//           ]),
//           SizedBox(height: 12 * s),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(16 * s),
//             child: AspectRatio(aspectRatio: 16 / 10, child: Image(image: item.image, fit: BoxFit.cover)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MetricGrid extends StatelessWidget {
//   const _MetricGrid({required this.s, required this.tyre, required this.isSidewall, required this.gradient});
//   final double s;
//   final _TyreUi tyre;
//   final bool isSidewall;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return Column(children: [
//       Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Expanded(child: _InfoMetricCard(s: s, title: 'Tread Depth', value: tyre.treadDepth, status: 'Status: ${tyre.tyreStatus}', icon: Icons.straighten_rounded, gradient: gradient)),
//         SizedBox(width: 12 * s),
//         Expanded(child: _InfoMetricCard(s: s, title: 'Tire Pressure', value: tyre.pressureStatus, status: 'Confidence: ${tyre.pressureConfidence}', icon: Icons.speed_rounded, gradient: gradient)),
//       ]),
//       SizedBox(height: 12 * s),
//       _InfoMetricCard(s: s, title: isSidewall ? 'Sidewall Damage' : 'Wear Patterns', value: isSidewall ? tyre.sidewallDamageDescription : tyre.wearPatterns, status: isSidewall ? 'Status: ${tyre.sidewallDamageStatus}' : 'Status: ${tyre.tyreStatus}', icon: Icons.report_gmailerrorred_rounded, gradient: gradient, fullWidth: true),
//       SizedBox(height: 12 * s),
//       _InfoMetricCard(s: s, title: 'Pressure Reason', value: tyre.pressureReason, status: 'Pressure Status: ${tyre.pressureStatus}', icon: Icons.info_outline_rounded, gradient: gradient, fullWidth: true),
//     ]);
//   }
// }

// class _SidewallDetailsCard extends StatelessWidget {
//   const _SidewallDetailsCard({required this.s, required this.tyre, required this.gradient});
//   final double s;
//   final _TyreUi tyre;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     final rows = [
//       ['Is Tire', tyre.sidewallIsTire],
//       ['Brand', tyre.brand],
//       ['Model', tyre.model],
//       ['Size', tyre.size],
//       ['Width', tyre.width],
//       ['Aspect Ratio', tyre.aspectRatio],
//       ['Rim Diameter', tyre.rimDiameter],
//       ['Load Index', tyre.loadIndex],
//       ['Speed Rating', tyre.speedRating],
//       ['Manufacturing Date', tyre.manufacturingDate],
//       ['Damage Status', tyre.sidewallDamageStatus],
//       ['Damage Description', tyre.sidewallDamageDescription],
//       ['Confidence', tyre.sidewallConfidence],
//     ];

//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: _cardDeco(20 * s),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [_gradIcon(s, Icons.tire_repair_rounded, gradient), SizedBox(width: 10 * s), Text('Sidewall Details', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 17 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))]),
//         SizedBox(height: 12 * s),
//         ...rows.map((r) => _infoRow(s, r[0], r[1])),
//       ]),
//     );
//   }
// }

// class _InfoMetricCard extends StatelessWidget {
//   const _InfoMetricCard({required this.s, required this.title, required this.value, required this.status, required this.icon, required this.gradient, this.fullWidth = false});
//   final double s;
//   final String title;
//   final String value;
//   final String status;
//   final IconData icon;
//   final LinearGradient gradient;
//   final bool fullWidth;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: fullWidth ? double.infinity : null,
//       padding: EdgeInsets.all(15 * s),
//       decoration: _cardDeco(18 * s),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [_gradIcon(s, icon, gradient), SizedBox(width: 8 * s), Expanded(child: Text(title, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14.5 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))))]),
//         SizedBox(height: 10 * s),
//         Text(value.trim().isEmpty ? 'N/A' : value, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.5 * s, fontWeight: FontWeight.w700, color: const Color(0xFF111827), height: 1.35)),
//         SizedBox(height: 8 * s),
//         _pill(s, status),
//       ]),
//     );
//   }
// }

// class _ReportSummaryCard extends StatelessWidget {
//   const _ReportSummaryCard({required this.s, required this.gradient, required this.tyre, required this.summary});
//   final double s;
//   final LinearGradient gradient;
//   final _TyreUi tyre;
//   final String summary;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: _cardDeco(20 * s),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [_gradIcon(s, Icons.description_outlined, gradient), SizedBox(width: 10 * s), Expanded(child: Text('Report Summary', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 18 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))))]),
//         SizedBox(height: 10 * s),
//         Text(tyre.label, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14.5 * s, fontWeight: FontWeight.w900, foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 250, 40)))),
//         SizedBox(height: 8 * s),
//         Text(summary, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.5 * s, fontWeight: FontWeight.w600, height: 1.42, color: const Color(0xFF222222))),
//       ]),
//     );
//   }
// }

// class _TyreUi {
//   _TyreUi({
//     required this.label,
//     required this.treadDepth,
//     required this.tyreStatus,
//     required this.wearPatterns,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//     required this.summary,
//     required this.brand,
//     required this.model,
//     required this.size,
//     required this.width,
//     required this.aspectRatio,
//     required this.rimDiameter,
//     required this.loadIndex,
//     required this.speedRating,
//     required this.manufacturingDate,
//     required this.sidewallIsTire,
//     required this.sidewallConfidence,
//     required this.sidewallDamageStatus,
//     required this.sidewallDamageDescription,
//   });

//   final String label;
//   final String treadDepth;
//   final String tyreStatus;
//   final String wearPatterns;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;
//   final String summary;
//   final String brand;
//   final String model;
//   final String size;
//   final String width;
//   final String aspectRatio;
//   final String rimDiameter;
//   final String loadIndex;
//   final String speedRating;
//   final String manufacturingDate;
//   final String sidewallIsTire;
//   final String sidewallConfidence;
//   final String sidewallDamageStatus;
//   final String sidewallDamageDescription;
// }

// class GenerateReportScreen extends StatefulWidget {
//   const GenerateReportScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.frontLeftSidewallPath,
//     required this.frontRightSidewallPath,
//     required this.backLeftSidewallPath,
//     required this.backRightSidewallPath,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     required this.frontLeftTyreId,
//     required this.frontRightTyreId,
//     required this.backLeftTyreId,
//     required this.backRightTyreId,
//     this.vehicleType = 'car',
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;
//   final String frontLeftSidewallPath;
//   final String frontRightSidewallPath;
//   final String backLeftSidewallPath;
//   final String backRightSidewallPath;
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String frontLeftTyreId;
//   final String frontRightTyreId;
//   final String backLeftTyreId;
//   final String backRightTyreId;
//   final String vehicleType;

//   @override
//   State<GenerateReportScreen> createState() => _GenerateReportScreenState();
// }

// class _GenerateReportScreenState extends State<GenerateReportScreen> {
//   bool _fired = false;
//   bool _navigated = false;
//   bool _adPlayStarted = false;
//   fw.ResponseFourWheeler? _apiResponse;
//   VideoPlayerController? _videoCtrl;
//   String _currentUrl = '';

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   void initState() {
//     super.initState();
//     context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
//     _startUpload();
//   }

//   void _startUpload() {
//     if (_fired) return;
//     _fired = true;
//     context.read<AuthBloc>().add(
//       UploadFourWheelerRequested(
//         vehicleId: widget.vehicleId,
//         vehicleType: widget.vehicleType,
//         vin: widget.vin,
//         frontLeftTyreId: widget.frontLeftTyreId,
//         frontRightTyreId: widget.frontRightTyreId,
//         backLeftTyreId: widget.backLeftTyreId,
//         backRightTyreId: widget.backRightTyreId,
//         frontLeftPath: widget.frontLeftPath,
//         frontRightPath: widget.frontRightPath,
//         backLeftPath: widget.backLeftPath,
//         backRightPath: widget.backRightPath,
//         frontLeftSidewallPath: widget.frontLeftSidewallPath,
//         frontRightSidewallPath: widget.frontRightSidewallPath,
//         backLeftSidewallPath: widget.backLeftSidewallPath,
//         backRightSidewallPath: widget.backRightSidewallPath,
//       ),
//     );
//   }

//   Future<void> _playVideo(String url) async {
//     final u = url.trim();
//     if (u.isEmpty) return;
//     if (_currentUrl == u && _videoCtrl != null) return;
//     _currentUrl = u;
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
//     final vc = _videoCtrl;
//     _videoCtrl = null;
//     _currentUrl = '';
//     _adPlayStarted = false;
//     try {
//       vc?.pause();
//     } catch (_) {}
//     vc?.dispose();
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;
//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);
//     if (obj is String) {
//       try {
//         final decoded = jsonDecode(obj);
//         if (decoded is Map<String, dynamic>) return decoded;
//         if (decoded is Map) return Map<String, dynamic>.from(decoded);
//       } catch (_) {}
//     }
//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map<String, dynamic>) return j;
//       if (j is Map) return Map<String, dynamic>.from(j);
//     } catch (_) {}
//     return null;
//   }

//   void _navigateToResult() {
//     if (!mounted || _navigated) return;
//     _navigated = true;
//     _stopVideo();

//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (_) => InspectionResultScreen(
//           frontLeftPath: widget.frontLeftPath,
//           frontRightPath: widget.frontRightPath,
//           backLeftPath: widget.backLeftPath,
//           backRightPath: widget.backRightPath,
//           frontLeftSidewallPath: widget.frontLeftSidewallPath,
//           frontRightSidewallPath: widget.frontRightSidewallPath,
//           backLeftSidewallPath: widget.backLeftSidewallPath,
//           backRightSidewallPath: widget.backRightSidewallPath,
//           vehicleId: widget.vehicleId,
//           userId: widget.userId,
//           token: widget.token,
//           response: _apiResponse,
//           fourWheelerRaw: _safeToJson(_apiResponse),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _stopVideo();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: MultiBlocListener(
//         listeners: [
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) =>
//                 p.selectedAd?.media != c.selectedAd?.media ||
//                 p.adsStatus != c.adsStatus ||
//                 p.fourWheelerStatus != c.fourWheelerStatus,
//             listener: (context, state) {
//               final isUploading = state.fourWheelerStatus == FourWheelerStatus.uploading;
//               final media = state.selectedAd?.media.trim() ?? '';
//               if (isUploading && media.isNotEmpty && !_adPlayStarted) {
//                 _adPlayStarted = true;
//                 _playVideo(media);
//               }
//               if (state.fourWheelerStatus == FourWheelerStatus.success ||
//                   state.fourWheelerStatus == FourWheelerStatus.failure) {
//                 _stopVideo();
//               }
//             },
//           ),
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
//             listener: (context, state) {
//               if (state.fourWheelerStatus == FourWheelerStatus.success) {
//                 _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
//                 _navigateToResult();
//               }
//             },
//           ),
//         ],
//         child: BlocBuilder<AuthBloc, AuthState>(
//           buildWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
//           builder: (context, state) {
//             final st = state.fourWheelerStatus;
//             if (st == FourWheelerStatus.uploading) {
//               return Stack(
//                 children: [
//                   _FullscreenVideoOnly(controller: _videoCtrl),
//                   Positioned(left: 16 * s, right: 16 * s, bottom: 22 * s, child: _GeneratingOverlayModern(s: s)),
//                 ],
//               );
//             }
//             if (st == FourWheelerStatus.failure) {
//               final msg = (state.fourWheelerError ?? '').trim().isEmpty
//                   ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
//                   : state.fourWheelerError!.trim();
//               return _ThemedScanFailedView(
//                 s: s,
//                 message: msg,
//                 gradient: _brandGrad,
//                 onRetake: () => Navigator.of(context).pop('retake'),
//                 onRetry: () {
//                   _stopVideo();
//                   setState(() {
//                     _fired = false;
//                     _navigated = false;
//                   });
//                   _startUpload();
//                 },
//               );
//             }
//             return Stack(
//               children: [
//                 _FullscreenVideoOnly(controller: _videoCtrl),
//                 Positioned(left: 16 * s, right: 16 * s, bottom: 22 * s, child: _GeneratingOverlayModern(s: s)),
//               ],
//             );
//           },
//         ),
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
//       decoration: BoxDecoration(color: Colors.black.withOpacity(.42), borderRadius: BorderRadius.circular(18 * s), border: Border.all(color: Colors.white.withOpacity(.12))),
//       child: Row(children: [
//         const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
//         SizedBox(width: 12 * s),
//         Expanded(child: Text('Generating report… Please wait', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 14 * s, fontWeight: FontWeight.w800, color: Colors.white))),
//       ]),
//     );
//   }
// }

// class _ThemedScanFailedView extends StatelessWidget {
//   const _ThemedScanFailedView({required this.s, required this.message, required this.gradient, required this.onRetake, required this.onRetry});
//   final double s;
//   final String message;
//   final LinearGradient gradient;
//   final VoidCallback onRetake;
//   final VoidCallback onRetry;
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF6F7FA), Color(0xFFF2F6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
//       child: SafeArea(
//         child: Center(
//           child: Padding(
//             padding: EdgeInsets.all(16 * s),
//             child: Container(
//               padding: EdgeInsets.all(18 * s),
//               decoration: _cardDeco(20 * s),
//               child: Column(mainAxisSize: MainAxisSize.min, children: [
//                 Container(width: 64 * s, height: 64 * s, decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient), child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 34 * s)),
//                 SizedBox(height: 12 * s),
//                 Text('Scan Failed', style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 18 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
//                 SizedBox(height: 8 * s),
//                 Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 13.8 * s, fontWeight: FontWeight.w600, height: 1.35, color: const Color(0xFF6B7280))),
//                 SizedBox(height: 16 * s),
//                 Row(children: [
//                   Expanded(child: _GhostButton(s: s, label: 'Retake Images', icon: Icons.refresh_rounded, onTap: onRetake)),
//                   SizedBox(width: 12 * s),
//                   Expanded(child: _GradientButton(s: s, label: 'Retry', icon: Icons.restart_alt_rounded, gradient: gradient, onTap: onRetry)),
//                 ]),
//               ]),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _GradientButton extends StatelessWidget {
//   const _GradientButton({required this.s, required this.label, required this.icon, required this.gradient, required this.onTap});
//   final double s;
//   final String label;
//   final IconData icon;
//   final LinearGradient gradient;
//   final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) => InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14 * s),
//         child: Container(
//           padding: EdgeInsets.symmetric(vertical: 12.5 * s),
//           decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14 * s)),
//           child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20 * s, color: Colors.white), SizedBox(width: 8 * s), Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w900, fontSize: 14.5 * s, color: Colors.white))]),
//         ),
//       );
// }

// class _GhostButton extends StatelessWidget {
//   const _GhostButton({required this.s, required this.label, required this.icon, required this.onTap});
//   final double s;
//   final String label;
//   final IconData icon;
//   final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) => InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14 * s),
//         child: Container(
//           padding: EdgeInsets.symmetric(vertical: 12.5 * s),
//           decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14 * s), border: Border.all(color: const Color(0xFFE5E7EB))),
//           child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20 * s, color: const Color(0xFF111827)), SizedBox(width: 8 * s), Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w900, fontSize: 14.5 * s, color: const Color(0xFF111827)))]),
//         ),
//       );
// }

// class _FullscreenVideoOnly extends StatelessWidget {
//   const _FullscreenVideoOnly({required this.controller});
//   final VideoPlayerController? controller;
//   @override
//   Widget build(BuildContext context) {
//     final c = controller;
//     if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
//     return SizedBox.expand(
//       child: FittedBox(
//         fit: BoxFit.cover,
//         child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
//       ),
//     );
//   }
// }

// BoxDecoration _cardDeco(double r) => BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(r),
//       border: Border.all(color: const Color(0xFFE8EAF0)),
//       boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 22, offset: const Offset(0, 10))],
//     );

// Widget _gradIcon(double s, IconData icon, LinearGradient gradient) => Container(
//       width: 34 * s,
//       height: 34 * s,
//       decoration: BoxDecoration(borderRadius: BorderRadius.circular(12 * s), gradient: gradient),
//       child: Icon(icon, size: 18 * s, color: Colors.white),
//     );

// Widget _pill(double s, String text) => Container(
//       padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 6 * s),
//       decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0xFFF3F4F6), border: Border.all(color: const Color(0xFFE8EAF0))),
//       child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 11.5 * s, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
//     );

// Widget _infoRow(double s, String label, String value) => Padding(
//       padding: EdgeInsets.only(bottom: 7 * s),
//       child: Row(children: [
//         Expanded(flex: 4, child: Text(label, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w800, color: const Color(0xFF6B7280)))),
//         SizedBox(width: 10 * s),
//         Expanded(flex: 6, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12.5 * s, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
//       ]),
//     );










































































































/*

class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    this.frontLeftSidewallPath,
    this.frontRightSidewallPath,
    this.backLeftSidewallPath,
    this.backRightSidewallPath,
    required this.vehicleId,
    required this.userId,
    required this.token,
    this.response,
    this.fourWheelerRaw,
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String? frontLeftSidewallPath;
  final String? frontRightSidewallPath;
  final String? backLeftSidewallPath;
  final String? backRightSidewallPath;

  final String vehicleId;
  final String userId;
  final String token;

  final dynamic response; // can be fw.ResponseFourWheeler OR Map OR json string
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  static const _bg = Color(0xFFF2F2F2);

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  int _selected = 0;

  @override
  void initState() {
    super.initState();

    try {
      final userid = context.read<AuthBloc>().state.profile?.userId.toString();
      if (userid != null && userid.isNotEmpty) {
        context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
    final d = parsed?.data;

    final tyreByChipIndex = <int, _TyreUi>{
      0: _tyreUiFromSide(label: 'Front Left', side: d?.frontLeft),
      1: _tyreUiFromSide(label: 'Front Right', side: d?.frontRight),
      2: _tyreUiFromSide(label: 'Back Left', side: d?.backLeft),
      3: _tyreUiFromSide(label: 'Back Right', side: d?.backRight),
    };

    final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

    final flImg =
        _imgProvider(localPath: widget.frontLeftPath, apiValue: d?.frontLeft?.image);
    final frImg =
        _imgProvider(localPath: widget.frontRightPath, apiValue: d?.frontRight?.image);
    final blImg =
        _imgProvider(localPath: widget.backLeftPath, apiValue: d?.backLeft?.image);
    final brImg =
        _imgProvider(localPath: widget.backRightPath, apiValue: d?.backRight?.image);
    final flsImg = _imgProvider(
      localPath: widget.frontLeftSidewallPath ?? widget.frontLeftPath,
      apiValue: d?.frontLeftSidewall?.image,
    );
    final frsImg = _imgProvider(
      localPath: widget.frontRightSidewallPath ?? widget.frontRightPath,
      apiValue: d?.frontRightSidewall?.image,
    );
    final blsImg = _imgProvider(
      localPath: widget.backLeftSidewallPath ?? widget.backLeftPath,
      apiValue: d?.backLeftSidewall?.image,
    );
    final brsImg = _imgProvider(
      localPath: widget.backRightSidewallPath ?? widget.backRightPath,
      apiValue: d?.backRightSidewall?.image,
    );

    final wheelImages = <_WheelCardData>[
      _WheelCardData(image: flImg, label: 'Front Left'),
      _WheelCardData(image: frImg, label: 'Front Right'),
      _WheelCardData(image: blImg, label: 'Back Left'),
      _WheelCardData(image: brImg, label: 'Back Right'),
      _WheelCardData(image: flsImg, label: 'FL Sidewall'),
      _WheelCardData(image: frsImg, label: 'FR Sidewall'),
      _WheelCardData(image: blsImg, label: 'BL Sidewall'),
      _WheelCardData(image: brsImg, label: 'BR Sidewall'),
    ];

    final summaryText = _composeSelectedSummary(selectedTyre);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => AppShell()),
              (route) => false,
            );
          },
        ),
        centerTitle: true,
        title: Text(
          'Inspection Report112233',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
          child: Column(
            children: [
              SizedBox(
                height: 190 * s,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wheelImages.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12 * s),
                  itemBuilder: (_, i) {
                    final item = wheelImages[i];
                    return _WheelImageCard(
                      s: s,
                      image: item.image,
                      label: item.label,
                      gradient: _brandGrad,
                    );
                  },
                ),
              ),
              SizedBox(height: 10 * s),
              _TyreChips(
                s: s,
                labels: const ['Front Left', 'Front Right', 'Back Left', 'Back Right'],
                selected: _selected,
                gradient: _brandGrad,
                onSelect: (i) => setState(() => _selected = i),
              ),
              SizedBox(height: 12 * s),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BigTreadCard(
                            s: s,
                            gradient: _brandGrad,
                            treadValue: selectedTyre.treadDepth,
                            treadStatus: selectedTyre.tyreStatus,
                            reason: '',
                            confidence: '',
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SmallMetricCardPressure(
                                gradient: _brandGrad,
                                s: s,
                                title: 'Tire Pressure',
                                status: 'Status: ${selectedTyre.pressureStatus}',
                                reason: selectedTyre.pressureReason.trim().isEmpty
                                    ? ''
                                    : 'Reason: ${selectedTyre.pressureReason}',
                                confidence: selectedTyre.pressureConfidence.trim().isEmpty
                                    ? ''
                                    : 'Confidence: ${selectedTyre.pressureConfidence}',
                              ),
                              SizedBox(height: 12 * s),
                              _SmallMetricCard(
                                s: s,
                                gradient: _brandGrad,
                                title: 'Damage Check',
                                value: 'Value: ${selectedTyre.damageValue}',
                                status: 'Status: ${selectedTyre.damageStatus}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16 * s),
                    _ReportSummaryCard(
                      s: s,
                      gradient: _brandGrad,
                      tyre: selectedTyre,
                      summary: summaryText,
                    ),
                    SizedBox(height: 6 * s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TyreUi _tyreUiFromSide({
    required String label,
    required fw.FourWheelerTyreSide? side,
  }) {
    if (side != null && side.isTire == false) {
      final msg = (side.summary ?? '').trim().isNotEmpty
          ? side.summary!.trim()
          : 'Uploaded image does not contain a vehicle tire.';
      final tp = side.pressure;
      final pressureStatus = (tp?.status ?? '').trim().isEmpty ? 'N/A' : tp!.status.trim();

      return _TyreUi(
        label: label,
        treadDepth: '—',
        tyreStatus: 'Not a tyre',
        damageValue: '—',
        damageStatus: '—',
        pressureValue: pressureStatus,
        pressureStatus: pressureStatus,
        pressureReason: (tp?.reason ?? '').trim(),
        pressureConfidence: (tp?.confidence ?? '').trim(),
        summary: msg,
      );
    }

    final condition = (side?.condition ?? '').trim();
    final tread = side?.treadDepth;
    final wear = (side?.wearPatterns ?? '').trim();
    final tp = side?.pressure;
    final summary = (side?.summary ?? '').trim();

    final status = condition.isEmpty ? '—' : condition;
    final treadStr = (tread == null) ? '—' : '${tread.toStringAsFixed(1)} mm';
    final pressureStatus = (tp?.status ?? '').trim().isEmpty ? '—' : tp!.status.trim();
    final pressureValue = pressureStatus;

    return _TyreUi(
      label: label,
      treadDepth: treadStr,
      tyreStatus: status,
      damageValue: wear.isEmpty ? '—' : wear,
      damageStatus: status,
      pressureValue: pressureValue,
      pressureStatus: pressureStatus,
      pressureReason: (tp?.reason ?? '').trim(),
      pressureConfidence: (tp?.confidence ?? '').trim(),
      summary: summary.isEmpty ? '—' : summary,
    );
  }

  String _composeSelectedSummary(_TyreUi t) {
    final parts = <String>[];

    if (t.summary.trim().isNotEmpty && t.summary != '—') {
      parts.add(t.summary.trim());
    }

    if (t.pressureStatus != '—' ||
        t.pressureReason.trim().isNotEmpty ||
        t.pressureConfidence.trim().isNotEmpty) {
      parts.add([
        'Tire pressure:',
        '• Status: ${t.pressureStatus}',
        if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
        if (t.pressureConfidence.trim().isNotEmpty)
          '• Confidence: ${t.pressureConfidence}',
      ].join('\n'));
    }

    return parts.isEmpty ? '—' : parts.join('\n\n');
  }

  fw.ResponseFourWheeler? _parseFourWheeler(
    Map<String, dynamic>? rawOverride,
    dynamic response,
  ) {
    try {
      if (response is fw.ResponseFourWheeler) return response;

      final raw = rawOverride ?? _safeToJson(response);
      if (raw == null) return null;

      if (raw.containsKey('data') && !raw.containsKey('message')) {
        return fw.ResponseFourWheeler.fromJson({'data': raw['data'], 'message': ''});
      }

      return fw.ResponseFourWheeler.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
    final apiStr = _asNonEmptyString(apiValue);

    if (apiStr != null) {
      if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
        return NetworkImage(apiStr);
      }
      if (apiStr.startsWith('data:image')) {
        try {
          final base64Part = apiStr.split(',').last;
          final bytes = base64Decode(base64Part);
          return MemoryImage(bytes);
        } catch (_) {}
      }
      if (apiStr.length > 100 && !apiStr.contains(' ')) {
        try {
          final bytes = base64Decode(apiStr);
          return MemoryImage(bytes);
        } catch (_) {}
      }
    }

    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;

    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);

    if (obj is String) {
      try {
        final decoded = jsonDecode(obj);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    try {
      final j = (obj as dynamic).toJson();
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}

    try {
      final encoded = jsonEncode(obj);
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return null;
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
}

// =============================
// UI WIDGETS (unchanged)
// =============================

class _WheelCardData {
  const _WheelCardData({required this.image, required this.label});
  final ImageProvider image;
  final String label;
}

class _WheelImageCard extends StatelessWidget {
  const _WheelImageCard({
    required this.s,
    required this.image,
    required this.label,
    required this.gradient,
  });

  final double s;
  final ImageProvider image;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120 * s,
      child: Column(
        children: [
          Container(
            height: 140 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * s),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18 * s),
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 10 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8 * s),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10 * s),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 14 * s,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreChips extends StatelessWidget {
  const _TyreChips({
    super.key,
    required this.s,
    required this.labels,
    required this.selected,
    required this.gradient,
    required this.onSelect,
  });

  final double s;
  final List<String> labels;
  final int selected;
  final LinearGradient gradient;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isSel = i == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(12 * s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10 * s),
                decoration: BoxDecoration(
                  gradient: isSel ? gradient : null,
                  color: isSel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSel ? .10 : .05),
                      blurRadius: isSel ? 16 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.5 * s,
                      fontWeight: FontWeight.w900,
                      color: isSel ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BigTreadCard extends StatelessWidget {
  const _BigTreadCard({
    required this.s,
    required this.gradient,
    required this.treadValue,
    required this.treadStatus,
    required this.reason,
    required this.confidence,
  });

  final double s;
  final LinearGradient gradient;
  final String treadValue;
  final String treadStatus;
  final String reason;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset(
                  "assets/thread_depth.png",
                  height: 26 * s,
                  width: 26 * s,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 3 * s),
              Text(
                'Thread Depth',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 19 * s,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..shader =
                        gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            'Value: $treadValue',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            'Status: $treadStatus',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallMetricCardPressure extends StatelessWidget {
  const _SmallMetricCardPressure({
    required this.s,
    required this.title,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.gradient,
  });

  final double s;
  final String title;
  final String status;
  final String reason;
  final String confidence;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.gradient,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.s,
    required this.gradient,
    required this.tyre,
    required this.summary,
  });

  final double s;
  final LinearGradient gradient;
  final _TyreUi tyre;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46 * s,
                height: 46 * s,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                child: Icon(Icons.description_outlined, color: Colors.white, size: 24 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  'Report Summary',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 22 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreUi {
  _TyreUi({
    required this.label,
    required this.treadDepth,
    required this.tyreStatus,
    required this.damageValue,
    required this.damageStatus,
    required this.pressureValue,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
  });

  final String label;
  final String treadDepth;
  final String tyreStatus;

  final String damageValue;
  final String damageStatus;

  final String pressureValue;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;

  final String summary;
}

// ======================================================
// ✅ GenerateReportScreen (UPDATED: failure UI themed)
// ======================================================

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.frontLeftSidewallPath,
    required this.frontRightSidewallPath,
    required this.backLeftSidewallPath,
    required this.backRightSidewallPath,
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = 'car',
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String frontLeftSidewallPath;
  final String frontRightSidewallPath;
  final String backLeftSidewallPath;
  final String backRightSidewallPath;

  final String userId;
  final String vehicleId;
  final String token;

  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String vehicleType;

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  bool _fired = false;
  bool _navigated = false;

  fw.ResponseFourWheeler? _apiResponse;

  VideoPlayerController? _videoCtrl;
  String _currentUrl = '';

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
    _startUpload();
  }

  void _startUpload() {
    if (_fired) return;
    _fired = true;

    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,
        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backRightTyreId,
        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
        frontLeftSidewallPath: widget.frontLeftSidewallPath,
        frontRightSidewallPath: widget.frontRightSidewallPath,
        backLeftSidewallPath: widget.backLeftSidewallPath,
        backRightSidewallPath: widget.backRightSidewallPath,
      ),
    );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentUrl == u && _videoCtrl != null) return;

    _currentUrl = u;

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

  void _navigateToResult() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          frontLeftPath: widget.frontLeftPath,
          frontRightPath: widget.frontRightPath,
          backLeftPath: widget.backLeftPath,
          backRightPath: widget.backRightPath,
          frontLeftSidewallPath: widget.frontLeftSidewallPath,
          frontRightSidewallPath: widget.frontRightSidewallPath,
          backLeftSidewallPath: widget.backLeftSidewallPath,
          backRightSidewallPath: widget.backRightSidewallPath,
          vehicleId: widget.vehicleId,
          userId: widget.userId,
          token: widget.token,
          response: _apiResponse,
        ),
      ),
    );
  }

  @override
  void dispose() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media || p.adsStatus != c.adsStatus,
            listener: (context, state) {
              final media = state.selectedAd?.media ?? '';
              if (media.trim().isNotEmpty) {
                _playVideo(media);
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
                _navigateToResult();
              }
            },
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
          builder: (context, state) {
            final st = state.fourWheelerStatus;

            if (st == FourWheelerStatus.uploading) {
              return _FullscreenVideoOnly(controller: _videoCtrl);
            }

            if (st == FourWheelerStatus.failure) {
              final msg = (state.fourWheelerError ?? '').trim().isEmpty
                  ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                  : state.fourWheelerError!.trim();

              return _ThemedScanFailedView(
                s: s,
                message: msg,
                gradient: _brandGrad,
                onRetake: () => Navigator.of(context).pop('retake'),
                onRetry: () {
                  setState(() {
                    _fired = false;
                    _navigated = false;
                  });
                  _startUpload();
                },
              );
            }

            return _FullscreenVideoOnly(controller: _videoCtrl);
          },
        ),
      ),
    );
  }
}

// ==============================
// ✅ NEW: Themed failure view
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
        // soft background like your app (light + clean)
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

                      // Buttons row (same vibe as your Download dialog)
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

                // Gradient icon bubble (top)
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

// ==============================
// Buttons (matching your theme)
// ==============================
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

// ==============================
// Fullscreen video widget (same)
// ==============================
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





*/










// class InspectionResultScreen extends StatefulWidget {
//   const InspectionResultScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.vehicleId,
//     required this.userId,
//     required this.token,
//     this.response,
//     this.fourWheelerRaw,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final dynamic response; // can be fw.ResponseFourWheeler OR Map OR json string
//   final Map<String, dynamic>? fourWheelerRaw;

//   @override
//   State<InspectionResultScreen> createState() => _InspectionResultScreenState();
// }

// class _InspectionResultScreenState extends State<InspectionResultScreen> {
//   static const _bg = Color(0xFFF2F2F2);

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   int _selected = 0;

//   @override
//   void initState() {
//     super.initState();

//     // Keeping your existing behavior
//     try {
//       final userid = context.read<AuthBloc>().state.profile?.userId.toString();
//       if (userid != null && userid.isNotEmpty) {
//         context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
//       }
//     } catch (_) {}
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     // ✅ Parse response into STRONGLY-TYPED model (fixes pressure showing "—")
//     final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
//     final d = parsed?.data;

//     // ✅ chip order: Front Left, Front Right, Back Left, Back Right
//     // NEW backend response has nested objects with `is_tire`.
//     final tyreByChipIndex = <int, _TyreUi>{
//       0: _tyreUiFromSide(label: 'Front Left', side: d?.frontLeft),
//       1: _tyreUiFromSide(label: 'Front Right', side: d?.frontRight),
//       2: _tyreUiFromSide(label: 'Back Left', side: d?.backLeft),
//       3: _tyreUiFromSide(label: 'Back Right', side: d?.backRight),
//     };

//     final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

//     // ✅ Images: NEW response can return `image` as base64/data-uri/url.
//     final flImg = _imgProvider(localPath: widget.frontLeftPath, apiValue: d?.frontLeft?.image);
//     final frImg = _imgProvider(localPath: widget.frontRightPath, apiValue: d?.frontRight?.image);
//     final blImg = _imgProvider(localPath: widget.backLeftPath, apiValue: d?.backLeft?.image);
//     final brImg = _imgProvider(localPath: widget.backRightPath, apiValue: d?.backRight?.image);

//     final wheelImages = <_WheelCardData>[
//       _WheelCardData(image: flImg, label: 'Front Left'),
//       _WheelCardData(image: frImg, label: 'Front Right'),
//       _WheelCardData(image: blImg, label: 'Back Left'),
//       _WheelCardData(image: brImg, label: 'Back Right'),
//     ];

//     final summaryText = _composeSelectedSummary(selectedTyre);

//     return Scaffold(
//       backgroundColor: _bg,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             size: 22,
//             color: Colors.black,
//           ),
//           onPressed: () {
//             Navigator.of(context).pushAndRemoveUntil(
//               MaterialPageRoute(builder: (_) => AppShell()),
//               (route) => false,
//             );
//           },
//         ),
//         centerTitle: true,
//         title: Text(
//           'Inspection Report',
//           style: TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontSize: 20 * s,
//             fontWeight: FontWeight.w800,
//             color: Colors.black,
//           ),
//         ),
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
//           child: Column(
//             children: [
//               SizedBox(
//                 height: 190 * s,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: wheelImages.length,
//                   separatorBuilder: (_, __) => SizedBox(width: 12 * s),
//                   itemBuilder: (_, i) {
//                     final item = wheelImages[i];
//                     return _WheelImageCard(
//                       s: s,
//                       image: item.image,
//                       label: item.label,
//                       gradient: _brandGrad,
//                     );
//                   },
//                 ),
//               ),

//               SizedBox(height: 10 * s),

//               _TyreChips(
//                 s: s,
//                 labels: const ['Front Left', 'Front Right', 'Back Left', 'Back Right'],
//                 selected: _selected,
//                 gradient: _brandGrad,
//                 onSelect: (i) => setState(() => _selected = i),
//               ),

//               SizedBox(height: 12 * s),

//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     // ✅ FIX: No stretch (infinite height inside ListView)
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           child: _BigTreadCard(
//                             s: s,
//                             gradient: _brandGrad,
//                             treadValue: selectedTyre.treadDepth,
//                             treadStatus: selectedTyre.tyreStatus,
//                             reason: '',
//                             confidence: '',
//                           ),
//                         ),
//                         SizedBox(width: 12 * s),
//                         Expanded(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min, // ✅ important in scroll
//                             children: [
//                               _SmallMetricCardPressure(
//                                 gradient: _brandGrad,
//                                 s: s,
//                                 title: 'Tire Pressure',
//                                 status: 'Status: ${selectedTyre.pressureStatus}',
//                                 reason: selectedTyre.pressureReason.trim().isEmpty
//                                     ? ''
//                                     : 'Reason: ${selectedTyre.pressureReason}',
//                                 confidence: selectedTyre.pressureConfidence.trim().isEmpty
//                                     ? ''
//                                     : 'Confidence: ${selectedTyre.pressureConfidence}',
//                               ),
//                               SizedBox(height: 12 * s),
//                               _SmallMetricCard(
//                                 s: s,
//                                 gradient: _brandGrad,
//                                 title: 'Damage Check',
//                                 value: 'Value: ${selectedTyre.damageValue}',
//                                 status: 'Status: ${selectedTyre.damageStatus}',
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),

//                     SizedBox(height: 16 * s),

//                     _ReportSummaryCard(
//                       s: s,
//                       gradient: _brandGrad,
//                       tyre: selectedTyre,
//                       summary: summaryText,
//                     ),

//                     SizedBox(height: 6 * s),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // -----------------------------
//   // ✅ Convert model to UI holder
//   // -----------------------------
//   _TyreUi _tyreUiFromSide({
//     required String label,
//     required fw.FourWheelerTyreSide? side,
//   }) {
//     // When backend says it's not a tyre, show a clear status.
//     if (side != null && side.isTire == false) {
//       final msg = (side.summary ?? '').trim().isNotEmpty
//           ? side.summary!.trim()
//           : 'Uploaded image does not contain a vehicle tire.';
//       final tp = side.pressure;
//       final pressureStatus = (tp?.status ?? '').trim().isEmpty ? 'N/A' : tp!.status.trim();

//       return _TyreUi(
//         label: label,
//         treadDepth: '—',
//         tyreStatus: 'Not a tyre',
//         damageValue: '—',
//         damageStatus: '—',
//         pressureValue: pressureStatus,
//         pressureStatus: pressureStatus,
//         pressureReason: (tp?.reason ?? '').trim(),
//         pressureConfidence: (tp?.confidence ?? '').trim(),
//         summary: msg,
//       );
//     }

//     final condition = (side?.condition ?? '').trim();
//     final tread = side?.treadDepth;
//     final wear = (side?.wearPatterns ?? '').trim();
//     final tp = side?.pressure;
//     final summary = (side?.summary ?? '').trim();

//     final status = condition.isEmpty ? '—' : condition;
//     final treadStr = (tread == null) ? '—' : '${tread.toStringAsFixed(1)} mm';
//     final pressureStatus = (tp?.status ?? '').trim().isEmpty ? '—' : tp!.status.trim();

//     // If your backend doesn't provide PSI, we show status as "Value".
//     final pressureValue = pressureStatus;

//     return _TyreUi(
//       label: label,
//       treadDepth: treadStr,
//       tyreStatus: status,
//       damageValue: wear.isEmpty ? '—' : wear,
//       damageStatus: status,
//       pressureValue: pressureValue,
//       pressureStatus: pressureStatus,
//       pressureReason: (tp?.reason ?? '').trim(),
//       pressureConfidence: (tp?.confidence ?? '').trim(),
//       summary: summary.isEmpty ? '—' : summary,
//     );
//   }

//   String _composeSelectedSummary(_TyreUi t) {
//     final parts = <String>[];

//     if (t.summary.trim().isNotEmpty && t.summary != '—') {
//       parts.add(t.summary.trim());
//     }

//     if (t.pressureStatus != '—' ||
//         t.pressureReason.trim().isNotEmpty ||
//         t.pressureConfidence.trim().isNotEmpty) {
//       parts.add([
//         'Tire pressure:',
//         '• Status: ${t.pressureStatus}',
//         if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
//         if (t.pressureConfidence.trim().isNotEmpty)
//           '• Confidence: ${t.pressureConfidence}',
//       ].join('\n'));
//     }

//     return parts.isEmpty ? '—' : parts.join('\n\n');
//   }

//   // -----------------------------
//   // ✅ Parse response safely
//   // -----------------------------
//   fw.ResponseFourWheeler? _parseFourWheeler(
//     Map<String, dynamic>? rawOverride,
//     dynamic response,
//   ) {
//     try {
//       if (response is fw.ResponseFourWheeler) return response;

//       final raw = rawOverride ?? _safeToJson(response);
//       if (raw == null) return null;

//       // Sometimes you may pass only {"data":{...}} without "message"
//       if (raw.containsKey('data') && !raw.containsKey('message')) {
//         return fw.ResponseFourWheeler.fromJson({'data': raw['data'], 'message': ''});
//       }

//       return fw.ResponseFourWheeler.fromJson(raw);
//     } catch (_) {
//       return null;
//     }
//   }

//   ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
//     final apiStr = _asNonEmptyString(apiValue);

//     if (apiStr != null) {
//       if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
//         return NetworkImage(apiStr);
//       }
//       if (apiStr.startsWith('data:image')) {
//         try {
//           final base64Part = apiStr.split(',').last;
//           final bytes = base64Decode(base64Part);
//           return MemoryImage(bytes);
//         } catch (_) {}
//       }

//       // ✅ raw base64 (no data-uri)
//       if (apiStr.length > 100 && !apiStr.contains(' ')) {
//         try {
//           final bytes = base64Decode(apiStr);
//           return MemoryImage(bytes);
//         } catch (_) {}
//       }
//     }

//     // fallback to local file
//     return FileImage(File(localPath));
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;

//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);

//     if (obj is String) {
//       try {
//         final decoded = jsonDecode(obj);
//         if (decoded is Map<String, dynamic>) return decoded;
//         if (decoded is Map) return Map<String, dynamic>.from(decoded);
//       } catch (_) {}
//     }

//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map<String, dynamic>) return j;
//       if (j is Map) return Map<String, dynamic>.from(j);
//     } catch (_) {}

//     try {
//       final encoded = jsonEncode(obj);
//       final decoded = jsonDecode(encoded);
//       if (decoded is Map<String, dynamic>) return decoded;
//       if (decoded is Map) return Map<String, dynamic>.from(decoded);
//     } catch (_) {}

//     return null;
//   }

//   String? _asNonEmptyString(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return null;
//     return s;
//   }
// }

// // =============================
// // UI WIDGETS
// // =============================

// class _WheelCardData {
//   const _WheelCardData({required this.image, required this.label});
//   final ImageProvider image;
//   final String label;
// }

// class _WheelImageCard extends StatelessWidget {
//   const _WheelImageCard({
//     required this.s,
//     required this.image,
//     required this.label,
//     required this.gradient,
//   });

//   final double s;
//   final ImageProvider image;
//   final String label;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 120 * s,
//       child: Column(
//         children: [
//           Container(
//             height: 140 * s,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(18 * s),
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(18 * s),
//               child: Image(image: image, fit: BoxFit.cover),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.symmetric(vertical: 8 * s),
//             decoration: BoxDecoration(
//               gradient: gradient,
//               borderRadius: BorderRadius.circular(10 * s),
//             ),
//             child: Center(
//               child: Text(
//                 label,
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w900,
//                   fontSize: 14 * s,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreChips extends StatelessWidget {
//   const _TyreChips({
//     super.key,
//     required this.s,
//     required this.labels,
//     required this.selected,
//     required this.gradient,
//     required this.onSelect,
//   });

//   final double s;
//   final List<String> labels;
//   final int selected;
//   final LinearGradient gradient;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: List.generate(labels.length, (i) {
//         final isSel = i == selected;
//         return Expanded(
//           child: Padding(
//             padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
//             child: InkWell(
//               onTap: () => onSelect(i),
//               borderRadius: BorderRadius.circular(12 * s),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding: EdgeInsets.symmetric(vertical: 10 * s),
//                 decoration: BoxDecoration(
//                   gradient: isSel ? gradient : null,
//                   color: isSel ? null : Colors.white,
//                   borderRadius: BorderRadius.circular(12 * s),
//                   border: Border.all(
//                     color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(isSel ? .10 : .05),
//                       blurRadius: isSel ? 16 : 10,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     labels[i],
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 13.5 * s,
//                       fontWeight: FontWeight.w900,
//                       color: isSel ? Colors.white : const Color(0xFF111827),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

// class _BigTreadCard extends StatelessWidget {
//   const _BigTreadCard({
//     required this.s,
//     required this.gradient,
//     required this.treadValue,
//     required this.treadStatus,
//     required this.reason,
//     required this.confidence,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final String treadValue;
//   final String treadStatus;
//   final String reason;
//   final String confidence;

//   @override
//   Widget build(BuildContext context) {
//     final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
//     final hasConfidence =
//         confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             children: [
//               ShaderMask(
//                 shaderCallback: (r) => gradient.createShader(r),
//                 child: Image.asset(
//                   "assets/thread_depth.png",
//                   height: 26 * s,
//                   width: 26 * s,
//                   color: Colors.white,
//                 ),
//               ),
//               SizedBox(width: 3 * s),
//               Text(
//                 'Thread Depth',
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontSize: 19 * s,
//                   fontWeight: FontWeight.w900,
//                   foreground: Paint()
//                     ..shader =
//                         gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Value: $treadValue',
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Status: $treadStatus',
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           if (hasReason) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               reason,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 height: 1.25,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//           if (hasConfidence) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               confidence,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class _SmallMetricCardPressure extends StatelessWidget {
//   const _SmallMetricCardPressure({
//     required this.s,
//     required this.title,
//     required this.status,
//     required this.reason,
//     required this.confidence,
//     required this.gradient,
//   });

//   final double s;
//   final String title;
//   final String status;
//   final String reason;
//   final String confidence;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
//     final hasConfidence =
//         confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 22 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()
//                 ..shader = gradient.createShader(
//                   const Rect.fromLTWH(0, 0, 200, 40),
//                 ),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           if (hasReason) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               reason,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 height: 1.25,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//           if (hasConfidence) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               confidence,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class _SmallMetricCard extends StatelessWidget {
//   const _SmallMetricCard({
//     required this.s,
//     required this.title,
//     required this.value,
//     required this.status,
//     required this.gradient,
//   });

//   final double s;
//   final String title;
//   final String value;
//   final String status;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 22 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()
//                 ..shader = gradient.createShader(
//                   const Rect.fromLTWH(0, 0, 200, 40),
//                 ),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             value,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ReportSummaryCard extends StatelessWidget {
//   const _ReportSummaryCard({
//     required this.s,
//     required this.gradient,
//     required this.tyre,
//     required this.summary,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final _TyreUi tyre;
//   final String summary;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 46 * s,
//                 height: 46 * s,
//                 decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
//                 child: Icon(Icons.description_outlined, color: Colors.white, size: 24 * s),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: Text(
//                   'Report Summary',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 22 * s,
//                     fontWeight: FontWeight.w900,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             tyre.label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()
//                 ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w600,
//               height: 1.35,
//               color: const Color(0xFF222222),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreUi {
//   _TyreUi({
//     required this.label,
//     required this.treadDepth,
//     required this.tyreStatus,
//     required this.damageValue,
//     required this.damageStatus,
//     required this.pressureValue,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//     required this.summary,
//   });

//   final String label;
//   final String treadDepth;
//   final String tyreStatus;

//   final String damageValue;
//   final String damageStatus;

//   final String pressureValue;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;

//   final String summary;
// }

// // ======================================================
// // ✅ GenerateReportScreen (fixed: backRightTyreId + same file)
// // ======================================================

// class GenerateReportScreen extends StatefulWidget {
//   const GenerateReportScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     required this.frontLeftTyreId,
//     required this.frontRightTyreId,
//     required this.backLeftTyreId,
//     required this.backRightTyreId,
//     this.vehicleType = 'car',
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String userId;
//   final String vehicleId;
//   final String token;

//   final String vin;

//   final String frontLeftTyreId;
//   final String frontRightTyreId;
//   final String backLeftTyreId;
//   final String backRightTyreId;

//   final String vehicleType;

//   @override
//   State<GenerateReportScreen> createState() => _GenerateReportScreenState();
// }

// class _GenerateReportScreenState extends State<GenerateReportScreen> {
//   bool _fired = false;
//   bool _navigated = false;

//   fw.ResponseFourWheeler? _apiResponse;

//   VideoPlayerController? _videoCtrl;
//   String _currentUrl = '';

//   @override
//   void initState() {
//     super.initState();

//     context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
//     _startUpload();
//   }

//   void _startUpload() {
//     if (_fired) return;
//     _fired = true;

//     context.read<AuthBloc>().add(
//       UploadFourWheelerRequested(
//         vehicleId: widget.vehicleId,
//         vehicleType: widget.vehicleType,
//         vin: widget.vin,
//         frontLeftTyreId: widget.frontLeftTyreId,
//         frontRightTyreId: widget.frontRightTyreId,
//         backLeftTyreId: widget.backLeftTyreId,
//         backRightTyreId: widget.backRightTyreId, // ✅ FIXED
//         frontLeftPath: widget.frontLeftPath,
//         frontRightPath: widget.frontRightPath,
//         backLeftPath: widget.backLeftPath,
//         backRightPath: widget.backRightPath,
//       ),
//     );
//   }

//   Future<void> _playVideo(String url) async {
//     final u = url.trim();
//     if (u.isEmpty) return;
//     if (_currentUrl == u && _videoCtrl != null) return;

//     _currentUrl = u;

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

//   void _navigateToResult() {
//     if (!mounted || _navigated) return;
//     _navigated = true;

//     final vc = _videoCtrl;
//     _videoCtrl = null;
//     vc?.dispose();

//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (_) => InspectionResultScreen(
//           frontLeftPath: widget.frontLeftPath,
//           frontRightPath: widget.frontRightPath,
//           backLeftPath: widget.backLeftPath,
//           backRightPath: widget.backRightPath,
//           vehicleId: widget.vehicleId,
//           userId: widget.userId,
//           token: widget.token,
//           response: _apiResponse,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     final vc = _videoCtrl;
//     _videoCtrl = null;
//     vc?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: MultiBlocListener(
//         listeners: [
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) =>
//                 p.selectedAd?.media != c.selectedAd?.media || p.adsStatus != c.adsStatus,
//             listener: (context, state) {
//               final media = state.selectedAd?.media ?? '';
//               if (media.trim().isNotEmpty) {
//                 _playVideo(media);
//               }
//             },
//           ),
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
//             listener: (context, state) {
//               if (state.fourWheelerStatus == FourWheelerStatus.success) {
//                 _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
//                 _navigateToResult();
//               }
//             },
//           ),
//         ],
//         child: BlocBuilder<AuthBloc, AuthState>(
//           buildWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
//           builder: (context, state) {
//             final st = state.fourWheelerStatus;

//             // ✅ uploading: keep fullscreen ad video
//             if (st == FourWheelerStatus.uploading) {
//               return _FullscreenVideoOnly(controller: _videoCtrl);
//             }

//             // ✅ failure: show error + retry/back
//             if (st == FourWheelerStatus.failure) {
//               final msg = (state.fourWheelerError ?? '').trim().isEmpty
//                   ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
//                   : state.fourWheelerError!.trim();

//               return Container(
//                 color: Colors.black,
//                 child: SafeArea(
//                   child: Center(
//                     child: Padding(
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           const Icon(Icons.error_outline, color: Colors.white, size: 54),
//                           const SizedBox(height: 12),
//                           Text(
//                             'Scan failed',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             msg,
//                             textAlign: TextAlign.center,
//                             style: TextStyle(color: Colors.white.withOpacity(.85)),
//                           ),
//                           const SizedBox(height: 16),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: OutlinedButton(
//                                   style: OutlinedButton.styleFrom(
//                                     foregroundColor: Colors.white,
//                                     side: const BorderSide(color: Colors.white70),
//                                   ),
//                                   onPressed: () => Navigator.of(context).pop('retake'),
//                                   child: const Text('Retake Images'),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: ElevatedButton(
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.white,
//                                     foregroundColor: Colors.black,
//                                   ),
//                                   onPressed: () {
//                                     // just retry upload with same images
//                                     setState(() {
//                                       _fired = false;
//                                       _navigated = false;
//                                     });
//                                     _startUpload();
//                                   },
//                                   child: const Text('Retry'),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             }

//             // idle/success will be handled by listeners (navigation)
//             return _FullscreenVideoOnly(controller: _videoCtrl);
//           },
//         ),
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

