import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';


enum _Filter { all, today, last7, thisMonth }
enum _VehicleTab { all, car, bike }

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  _Filter _filter = _Filter.all;
  _VehicleTab _vehicleTab = _VehicleTab.all;

  final Map<int, bool> _downloaded = <int, bool>{};
  final Map<int, bool> _downloading = <int, bool>{};

  // Persist downloaded report paths: recordId -> savedPath
  final Map<int, String> _savedPaths = <int, String>{};
  final GetStorage _store = GetStorage();

  // bump to force persistence key refresh if needed
  static const int _pdfDesignVersion = 9;
  static const String _storeKeyPaths = 'report_download_paths_v9';

  @override
  void initState() {
    super.initState();
    _restoreDownloadedState();

    final bloc = context.read<AuthBloc>();
    final st = bloc.state;

    final userId = (st.profile?.userId?.toString() ?? '').trim();
    if (userId.isNotEmpty && st.tyreHistoryStatus == TyreHistoryStatus.initial) {
      bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
    }
  }

  Future<void> _restoreDownloadedState() async {
    try {
      final raw = _store.read(_storeKeyPaths);

      if (raw is Map) {
        for (final entry in raw.entries) {
          final k = int.tryParse(entry.key.toString());
          final v = entry.value?.toString();
          if (k != null && v != null && v.trim().isNotEmpty) {
            _savedPaths[k] = v.trim();
          }
        }

        // Remove paths that no longer exist
        for (final e in _savedPaths.entries.toList()) {
          final exists = await File(e.value).exists();
          if (!exists) _savedPaths.remove(e.key);
        }

        if (!mounted) return;
        setState(() {
          _downloaded.clear();
          for (final id in _savedPaths.keys) {
            _downloaded[id] = true;
          }
        });

        _persistDownloadedPaths();
      }
    } catch (_) {
      // ignore
    }
  }

  void _persistDownloadedPaths() {
    final out = <String, String>{};
    for (final e in _savedPaths.entries) {
      out[e.key.toString()] = e.value;
    }
    _store.write(_storeKeyPaths, out);
  }

  /* ============================ Filters ============================ */

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  List<TyreRecord> _applyTimeFilter(List<TyreRecord> all) {
    final now = DateTime.now();

    switch (_filter) {
      case _Filter.all:
        return all;

      case _Filter.today:
        final start = _startOfDay(now);
        final end = start.add(const Duration(days: 1));
        return all.where((e) => e.uploadedAt.isAfter(start) && e.uploadedAt.isBefore(end)).toList();

      case _Filter.last7:
        final start = now.subtract(const Duration(days: 7));
        return all.where((e) => e.uploadedAt.isAfter(start)).toList();

      case _Filter.thisMonth:
        final start = _startOfMonth(now);
        final end = DateTime(now.year, now.month + 1, 1);
        return all.where((e) => e.uploadedAt.isAfter(start) && e.uploadedAt.isBefore(end)).toList();
    }
  }

  String _prettyDate(DateTime d) {
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final am = d.hour >= 12 ? 'PM' : 'AM';
    return '${DateFormat('dd MMM, yyyy').format(d)}  —  $hh:$mm $am';
  }

  /* ============================ File names ============================ */

  // ✅ sanitize filename so Android/iOS never fail
  String _cleanFileNamePart(String v, {String fallback = 'Vehicle_Model'}) {
    final t = v.trim().isEmpty ? fallback : v.trim();
    return t.replaceAll(RegExp(r'[^\w\-]+'), '_');
  }

  // ✅ REQUIRED: filename should be "Vehicle Model"
  // Example: BMW_i7.pdf
  // NOTE: will overwrite if same model downloaded again.
  String _safeFileName(TyreRecord r) {
    final model = _cleanFileNamePart(r.vehicleModel, fallback: 'Vehicle_Model');
    return '$model.pdf';
  }

  Future<Directory> _reportsDir() async {
    // iOS: Documents
    // Android: external app dir if available, else documents
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, 'Reports'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Reports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _tempShareDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'tyre_reports_share'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _savePdfTempForShare(TyreRecord record) async {
    final dir = await _tempShareDir();
    final path = p.join(dir.path, _safeFileName(record));
    final bytes = await _ModernPdfReport.build(record);

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String?> _savePdfToPersistent(TyreRecord record) async {
    try {
      final dir = await _reportsDir();
      final path = p.join(dir.path, _safeFileName(record));

      final bytes = await _ModernPdfReport.build(record);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (!await file.exists()) return null;
      return path;
    } catch (e, st) {
      debugPrint('PDF save failed: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<void> _downloadPdf(TyreRecord record) async {
    final id = record.recordId;
    if (_downloading[id] == true) return;

    setState(() => _downloading[id] = true);

    try {
      final savedPath = await _savePdfToPersistent(record);

      if (!mounted) return;
      setState(() => _downloading[id] = false);

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed: Unable to save file')),
        );
        return;
      }

      _savedPaths[id] = savedPath;
      _persistDownloadedPaths();

      if (!mounted) return;
      setState(() => _downloaded[id] = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${p.basename(savedPath)}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(savedPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading[id] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _viewPdf(TyreRecord record) async {
    final path = _savedPaths[record.recordId];
    if (path == null || path.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found. Please download again.')),
      );
      return;
    }

    final exists = await File(path).exists();
    if (!exists) {
      _savedPaths.remove(record.recordId);
      _downloaded[record.recordId] = false;
      _persistDownloadedPaths();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File was removed. Please download again.')),
      );
      return;
    }

    await OpenFilex.open(path);
  }

  Future<void> _sharePdf(TyreRecord record, {Rect? shareOrigin}) async {
    try {
      File file;

      // ✅ if already downloaded, share saved file (no re-generate)
      final saved = _savedPaths[record.recordId];
      if (saved != null && saved.trim().isNotEmpty && await File(saved).exists()) {
        file = File(saved);
      } else {
        file = await _savePdfTempForShare(record);
      }

      if (!mounted) return;

      final fallback = const Rect.fromLTWH(1, 1, 1, 1);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tyre Inspection Report (${record.vehicleBrand} ${record.vehicleModel})',
        sharePositionOrigin: shareOrigin ?? fallback,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  // ✅ FIX: popup now changes based on downloaded state
  void _openDownloadSheet(TyreRecord record) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    final downloaded = _downloaded[record.recordId] == true &&
        (_savedPaths[record.recordId] != null);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _DownloadDialog(
            s: s,
            downloaded: downloaded,
            onDownload: () async {
              Navigator.of(context).pop();
              await _downloadPdf(record);
            },
            onView: () async {
              Navigator.of(context).pop();
              await _viewPdf(record);
            },
            onShare: (Rect origin) async {
              Navigator.of(context).pop();
              await _sharePdf(record, shareOrigin: origin);
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

  Color _statusColorUi(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return const Color(0xFFEF4444);
    if (t.contains('warning')) return const Color(0xFFF59E0B);
    if (t.contains('safe')) return const Color(0xFF22C55E);
    return const Color(0xFF10B981);
  }

  String _summaryStatus(TyreRecord r) {
    final vt = r.vehicleType.toLowerCase().trim();

    if (vt == 'bike') {
      final s = <String>[r.bikeFrontStatus, r.bikeBackStatus].map((e) => e.toLowerCase()).toList();
      if (s.any((x) => x.contains('danger'))) return 'Danger';
      if (s.any((x) => x.contains('warning'))) return 'Warning';
      if (s.any((x) => x.contains('safe'))) return 'Safe';
      return 'Completed';
    }

    final statuses = <String>[r.frontLeftStatus, r.frontRightStatus, r.backLeftStatus, r.backRightStatus]
        .map((e) => e.toLowerCase())
        .toList();

    if (statuses.any((s) => s.contains('danger'))) return 'Danger';
    if (statuses.any((s) => s.contains('warning'))) return 'Warning';
    if (statuses.any((s) => s.contains('safe'))) return 'Safe';
    return 'Completed';
  }

  /* ============================ UI (NO DESIGN CHANGE) ============================ */

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            List<TyreRecord> all;
            switch (_vehicleTab) {
              case _VehicleTab.all:
                all = state.allTyreRecords;
                break;
              case _VehicleTab.car:
                all = state.carRecords;
                break;
              case _VehicleTab.bike:
                all = state.bikeRecords;
                break;
            }

            final filtered = _applyTimeFilter(all);

            return ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 28 * s),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 30.0),
                      child: Text(
                        'Report History',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                SizedBox(height: 10 * s),
                _VehicleTabs(
                  s: s,
                  active: _vehicleTab,
                  onChanged: (v) => setState(() => _vehicleTab = v),
                ),
                SizedBox(height: 12 * s),
                _FiltersBar(
                  s: s,
                  active: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                SizedBox(height: 16 * s),

                if (state.tyreHistoryStatus == TyreHistoryStatus.loading)
                  Padding(
                    padding: EdgeInsets.only(top: 20 * s),
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                if (state.tyreHistoryStatus == TyreHistoryStatus.failure)
                  Container(
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12 * s),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: Text(
                            state.tyreHistoryError ?? 'Failed to load history',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: const Color(0xFF111827),
                              fontSize: 13 * s,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final userId = (state.profile?.userId?.toString() ?? '').trim();
                            if (userId.isEmpty) return;
                            context.read<AuthBloc>().add(
                                  FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"),
                                );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                if (state.tyreHistoryStatus == TyreHistoryStatus.success && filtered.isEmpty)
                  Container(
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12 * s),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        )
                      ],
                    ),
                    child: Text(
                      'No reports found.',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: const Color(0xFF111827),
                        fontSize: 13.5 * s,
                      ),
                    ),
                  ),

                ...filtered.map((it) {
                  final downloading = _downloading[it.recordId] == true;
                  final downloaded = _downloaded[it.recordId] == true;
                  final statusSummary = _summaryStatus(it);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12 * s),
                    child: _ReportCard(
                      vehicleModel: it.vehicleModel,
                      s: s,
                      dateText: _prettyDate(it.uploadedAt),
                      vehicleType: it.vehicleType,
                      vehicleId: it.vehicleId,
                      completed: true,
                      downloaded: downloaded,
                      downloading: downloading,
                      onDownload: () => _openDownloadSheet(it),
                      statusSummary: statusSummary,
                      statusColor: _statusColorUi(statusSummary),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ============================ PDF (TREAD RULE + TYRE PRESSURE) ============================ */

class _ModernPdfReport {
  static const PdfColor _card = PdfColors.white;
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

  static const PdfColor _g1 = PdfColor.fromInt(0xFF4F46E5);
  static const PdfColor _g2 = PdfColor.fromInt(0xFF6366F1);

  static String _dash(String v) => v.trim().isEmpty ? '—' : v.trim();

  /* ============================ JSON parsing helper ============================ */

  // Handles: Map, stringified JSON, null
  static Map<String, dynamic>? _asMap(dynamic v) {
    try {
      if (v == null) return null;

      if (v is Map<String, dynamic>) return v;

      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val));
      }

      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return null;

        if (s.startsWith('{') && s.endsWith('}')) {
          final decoded = jsonDecode(s);
          if (decoded is Map) {
            return decoded.map((k, val) => MapEntry(k.toString(), val));
          }
        }
        return null;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /* ============================ NEW: Tread rule helpers ============================ */

  // supports:
  // - "8/32" => converts to mm
  // - "6.5mm" / "6.5 mm" => mm
  // - "6.5" => assumes mm
  // - null/empty => null
  static double? _treadMmFromString(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;

    // like "8/32"
    final frac = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*\/\s*([0-9]+(?:\.[0-9]+)?)\s*$');
    final m1 = frac.firstMatch(s);
    if (m1 != null) {
      final num = double.tryParse(m1.group(1) ?? '');
      final den = double.tryParse(m1.group(2) ?? '');
      if (num == null || den == null || den == 0) return null;

      final mm = (num / den) * 25.4; // inches -> mm
      return mm.isFinite ? mm : null;
    }

    // like "6.5 mm" / "6.5mm"
    final mmMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*mm').firstMatch(s);
    if (mmMatch != null) {
      return double.tryParse(mmMatch.group(1) ?? '');
    }

    // first number (assume mm)
    final firstNum = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(s);
    if (firstNum != null) {
      return double.tryParse(firstNum.group(1) ?? '');
    }

    return null;
  }

  // ✅ YOUR REQUIRED CONDITION:
  // >= 7.0 => Safe / Good
  // 4.0 - 6.9 => Warning
  // < 4.0 => Danger
  // < 1.6 => Critical
  static String _treadStatusFromMm(double? mm) {
    if (mm == null) return '—';
    if (mm < 1.6) return 'Critical';
    if (mm < 4.0) return 'Danger';
    if (mm < 7.0) return 'Warning';
    return 'Safe / Good';
  }

  static String _treadMeaning(String status) {
    final t = status.toLowerCase();
    if (t.contains('safe')) return 'Like new tire';
    if (t.contains('warning')) return 'Wearing but usable';
    if (t.contains('danger')) return 'Replace soon';
    if (t.contains('critical')) return 'Illegal in many countries';
    return '—';
  }

  static PdfColor _treadStatusColor(String status) {
    final t = status.toLowerCase();
    if (t.contains('critical')) return PdfColor.fromInt(0xFF991B1B); // dark red
    if (t.contains('danger')) return PdfColor.fromInt(0xFFEF4444); // red
    if (t.contains('warning')) return PdfColor.fromInt(0xFFF59E0B); // amber
    if (t.contains('safe')) return PdfColor.fromInt(0xFF22C55E); // green
    return _text;
  }

  static String _fmtMm(double? mm) {
    if (mm == null) return '—';
    return '${mm.toStringAsFixed(1)} mm';
  }

  /* ============================ Tyre status + pressure parsing ============================ */

  static String _conditionOnly(dynamic status) {
    final m = _asMap(status);
    final v = (m?['condition']?.toString() ?? '').trim();
    if (v.isNotEmpty) return v;
    if (status is String && status.trim().isNotEmpty) return status.trim();
    return '—';
  }

  static String _pressureStatus(dynamic pressure) {
    final m = _asMap(pressure);
    final v = (m?['status']?.toString() ?? '').trim();
    return v.isEmpty ? '—' : v;
  }

  static String _pressureReason(dynamic pressure) {
    final m = _asMap(pressure);
    final v = (m?['reason']?.toString() ?? '').trim();
    return v.isEmpty ? '—' : v;
  }

  static String _pressureConfidence(dynamic pressure) {
    final m = _asMap(pressure);
    final v = (m?['confidence']?.toString() ?? '').trim();
    return v.isEmpty ? '—' : v;
  }

  /* ============================ Image ============================ */

  static Future<pw.ImageProvider?> _netImg(String url) async {
    try {
      if (!url.startsWith('http')) return null;
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return null;
      return pw.MemoryImage(r.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  /* ============================ UI blocks ============================ */

  static pw.Widget _kv(String k, String v, {PdfColor? vColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 10.2,
                color: vColor ?? _text,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tyreTile(_WheelData w) {
    // ✅ tread conversion + rule
    final treadMm = _treadMmFromString(w.tread);
    final treadStatus = _treadStatusFromMm(treadMm);
    final treadMeaning = _treadMeaning(treadStatus);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            w.title,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Container(
            height: 110,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: w.image == null
                ? pw.Center(
                    child: pw.Text(
                      'No image',
                      style: pw.TextStyle(fontSize: 9.5, color: _muted),
                    ),
                  )
                : pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(w.image!, fit: pw.BoxFit.cover),
                  ),
          ),

          pw.SizedBox(height: 10),

          // ✅ Keep your AI status as well
          _kv('AI Tyre Status', _conditionOnly(w.status)),
          _kv('Wear', _dash(w.wear)),

          pw.Divider(color: _border),

          // ✅ REQUIRED: Tread rule output
          _kv('Tread Depth', _fmtMm(treadMm)),
          _kv('Tread Status', treadStatus, vColor: _treadStatusColor(treadStatus)),
          _kv('Meaning', treadMeaning),

          pw.Divider(color: _border),

          // ✅ Tyre pressure from your JSON string/map
          pw.Text(
            'Tyre Pressure',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 6),
          _kv('Status', _pressureStatus(w.pressure)),
          _kv('Reason', _pressureReason(w.pressure)),
          _kv('Confidence', _pressureConfidence(w.pressure)),

          pw.Divider(color: _border),

          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _dash(w.summary),
            style: pw.TextStyle(fontSize: 10, color: _text, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Future<List<int>> build(TyreRecord r) async {
    final wheels = <_WheelData>[];

    if (r.vehicleType.toLowerCase() == 'car') {
      wheels.addAll([
        _WheelData.fromWheel(
          title: 'Front Left',
          status: r.frontLeftStatus,
          tread: (r.frontLeftTread ?? '').toString(),
          wear: r.frontLeftWearPatterns,
          pressure: r.frontLeftPressure, // ✅ JSON string like your sample
          summary: r.frontLeftSummary,
          imageUrl: r.frontLeftWheel,
        ),
        _WheelData.fromWheel(
          title: 'Front Right',
          status: r.frontRightStatus,
          tread: (r.frontRightTread ?? '').toString(),
          wear: r.frontRightWearPatterns,
          pressure: r.frontRightPressure,
          summary: r.frontRightSummary,
          imageUrl: r.frontRightWheel,
        ),
        _WheelData.fromWheel(
          title: 'Back Left',
          status: r.backLeftStatus,
          tread: (r.backLeftTread ?? '').toString(),
          wear: r.backLeftWearPatterns,
          pressure: r.backLeftPressure,
          summary: r.backLeftSummary,
          imageUrl: r.backLeftWheel,
        ),
        _WheelData.fromWheel(
          title: 'Back Right',
          status: r.backRightStatus,
          tread: (r.backRightTread ?? '').toString(),
          wear: r.backRightWearPatterns,
          pressure: r.backRightPressure,
          summary: r.backRightSummary,
          imageUrl: r.backRightWheel,
        ),
      ]);
    } else {
      // ✅ bike (2 wheels)
      wheels.addAll([
        _WheelData.fromWheel(
          title: 'Front Tyre',
          status: r.bikeFrontStatus,
          tread: (r.bikeFrontTread ?? '').toString(),
          wear: r.bikeFrontWearPatterns,
          pressure: r.bikeFrontPressure,
          summary: r.bikeFrontSummary,
          imageUrl: r.bikeFrontWheel,
        ),
        _WheelData.fromWheel(
          title: 'Back Tyre',
          status: r.bikeBackStatus,
          tread: (r.bikeBackTread ?? '').toString(),
          wear: r.bikeBackWearPatterns,
          pressure: r.bikeBackPressure,
          summary: r.bikeBackSummary,
          imageUrl: r.bikeBackWheel,
        ),
      ]);
    }

    for (final w in wheels) {
      w.image = await _netImg(w.imageUrl);
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        build: (_) => [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Tyre ',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _g1,
                  ),
                ),
                pw.TextSpan(
                  text: 'Inspection Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _g2,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _card,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Uploaded', DateFormat('dd MMM, yyyy  -  hh:mm a').format(r.uploadedAt)),
                _kv('Vehicle Type', _dash(r.vehicleType.toUpperCase())),
                _kv('Vehicle Brand', _dash(r.vehicleBrand)),
                _kv('Vehicle Model', _dash(r.vehicleModel)),
                _kv('Vehicle License', _dash(r.vehicleLicense)),
                _kv('Tyre Brand', _dash(r.vehicleTyreBrand)),
                _kv('Tyre Dimension', _dash(r.vehicleTyreDimension)),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: wheels.map((w) => pw.SizedBox(width: 260, child: _tyreTile(w))).toList(),
          ),

          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text(
              'Generated by TireTest AI',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}

class _WheelData {
  _WheelData({
    required this.title,
    required this.status,
    required this.tread,
    required this.wear,
    required this.pressure,
    required this.summary,
    required this.imageUrl,
  });

  factory _WheelData.fromWheel({
    required String title,
    required dynamic status,
    required String tread,
    required String wear,
    required dynamic pressure,
    required String summary,
    required String imageUrl,
  }) {
    return _WheelData(
      title: title,
      status: status,
      tread: tread,
      wear: wear,
      pressure: pressure,
      summary: summary,
      imageUrl: imageUrl,
    );
  }

  final String title;
  final dynamic status;

  // can be "8/32", "6.5 mm", "", null converted to ""
  final String tread;

  final String wear;

  final dynamic pressure;

  final String summary;
  final String imageUrl;

  pw.ImageProvider? image;
}


class _VehicleTabs extends StatelessWidget {
  const _VehicleTabs({
    required this.s,
    required this.active,
    required this.onChanged,
  });

  final double s;
  final _VehicleTab active;
  final ValueChanged<_VehicleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(_VehicleTab t, String label, IconData icon) {
      final isActive = t == active;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * s),
              gradient: isActive
                  ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
                  : null,
              color: isActive ? null : const Color(0xFFEFF2F8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18 * s,
                  color: isActive ? Colors.white : const Color(0xFF111827),
                ),
                SizedBox(width: 6 * s),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : const Color(0xFF111827),
                    fontSize: 13 * s,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          tab(_VehicleTab.all, 'All', Icons.dashboard_rounded),
          SizedBox(width: 8 * s),
          tab(_VehicleTab.car, 'Car', Icons.directions_car_filled_rounded),
          SizedBox(width: 8 * s),
          tab(_VehicleTab.bike, 'Bike', Icons.two_wheeler_rounded),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.s,
    required this.active,
    required this.onChanged,
  });

  final double s;
  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_Filter f, String label) {
      final isActive = f == active;
      return GestureDetector(
        onTap: () => onChanged(f),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive
                ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
                : null,
            color: isActive ? null : const Color(0xFFEFF2F8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : const Color(0xFF111827),
              fontSize: 13 * s,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          chip(_Filter.all, 'All'),
          chip(_Filter.today, 'Today'),
          chip(_Filter.last7, 'Last 7 Days'),
          chip(_Filter.thisMonth, 'This Month'),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.s,
    required this.dateText,
    required this.vehicleType,
    required this.vehicleId,
    required this.vehicleModel,
    required this.completed,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.statusSummary,
    required this.statusColor,
  });

  final double s;
  final String dateText;
  final String vehicleType;
  final String vehicleModel;
  final String vehicleId;
  final bool completed;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final String statusSummary;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final isBike = vehicleType.toLowerCase().trim() == 'bike';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9 * s,
            height: 131 * s,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              gradient: LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 10 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Report Generated',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            fontSize: 16 * s,
                          ),
                        ),
                      ),
                      _DownloadPill(
                        s: s,
                        enabled: completed,
                        downloaded: downloaded,
                        downloading: downloading,
                        onTap: onDownload,
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 16 * s, color: const Color(0xFF6B7280)),
                      SizedBox(width: 6 * s),
                      Text(
                        dateText,
                        style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(
                        isBike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
                        size: 16 * s,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6 * s),
                      Flexible(
                        child: Text(
                          'Vehicle: ${vehicleType.toUpperCase()} • ${vehicleModel.trim().isEmpty ? "—" : vehicleModel.trim()}',
                          style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10 * s, color: statusColor),
                      SizedBox(width: 6 * s),
                      Text(
                        'Status: $statusSummary',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12.5 * s,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _DownloadPill extends StatelessWidget {
  const _DownloadPill({
    required this.s,
    required this.enabled,
    required this.downloaded,
    required this.downloading,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = downloading
        ? 'Downloading...'
        : (downloaded ? 'Downloaded' : 'Download\nFull Report');

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * s),
        color: enabled ? null : const Color(0xFFF1F5F9),
        gradient: enabled
            ? const LinearGradient(colors: [Color(0xFFEEF6FF), Color(0xFFEFF1FF)])
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30 * s,
            height: 30 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]) : null,
              color: enabled ? null : const Color(0xFFE2E8F0),
            ),
            child: downloading
                ? Padding(
                    padding: EdgeInsets.all(6 * s),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 19 * s,
                    color: enabled ? Colors.white : const Color(0xFF6B7280),
                  ),
          ),
          SizedBox(width: 8 * s),
          Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              fontSize: 11.5 * s,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : .5,
      child: GestureDetector(
        onTap: enabled && !downloading ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: pill,
      ),
    );
  }
}

/* ============================ Dialog (FIXED) ============================ */

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({
    required this.s,
    required this.downloaded,
    required this.onDownload,
    required this.onView,
    required this.onShare,
  });

  final double s;
  final bool downloaded;
  final VoidCallback onDownload;
  final VoidCallback onView;
  final void Function(Rect shareOrigin) onShare;

  Rect _rectFromContext(BuildContext ctx) {
    final render = ctx.findRenderObject();
    if (render is RenderBox) {
      final origin = render.localToGlobal(Offset.zero);
      final size = render.size;
      if (size.width > 0 && size.height > 0) {
        return origin & size;
      }
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

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
              boxShadow: const [
                BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  downloaded ? 'Report Ready' : 'Ready to Download?',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 18 * s,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  downloaded
                      ? 'This PDF is already saved. You can view or share it.'
                      : 'Get a detailed PDF of your scan. You can also share it directly.',
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

                // ✅ FIX: if downloaded => show VIEW button instead of DOWNLOAD
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: downloaded ? onView : onDownload,
                    icon: Icon(downloaded ? Icons.visibility_rounded : Icons.download_rounded, size: 25),
                    label: Text(
                      downloaded ? 'View PDF' : 'Download PDF',
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

                Builder(
                  builder: (btnCtx) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final rect = _rectFromContext(btnCtx);
                          onShare(rect);
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 23),
                        label: Text(
                          'Share Report',
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
                    );
                  },
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
