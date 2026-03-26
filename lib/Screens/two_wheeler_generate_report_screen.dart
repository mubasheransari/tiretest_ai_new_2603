import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'two_wheeler_report_result_screen.dart'; 

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';

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
  final String backPath;

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
    required this.backPath,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState
    extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;
  _BikeTyrePos _active = _BikeTyrePos.front;

  // ✅ VIDEO STATE (ad video while generating)
  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
            backPath: widget.backPath,
            frontTyreId: widget.frontTyreId,
            backTyreId: widget.backTyreId,
          ),
        );
  }

  void _retryUpload() {
    setState(() => _dispatched = false);
    _upload();
  }

  // ✅ SAME "SCAN FAILED" CONDITION as 4-wheeler:
  // - If API returns success but any side has isTire == false -> show scan failed screen
  bool _anySideNotTyre(TwoWheelerTyreUploadResponse? resp) {
    final d = resp?.data;
    final f = d?.front;
    final b = d?.back;

    final frontNotTyre = (f != null && f.isTire == false);
    final backNotTyre = (b != null && b.isTire == false);

    return frontNotTyre || backNotTyre;
  }

  String _scanFailedMessage(TwoWheelerTyreUploadResponse? resp) {
    String clean(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return '';
      return s;
    }

    final d = resp?.data;
    final f = d?.front;
    final b = d?.back;

    final parts = <String>[];

    if (f != null && f.isTire == false) {
      final msg = clean(f.summary);
      parts.add(msg.isNotEmpty
          ? msg
          : 'Uploaded front image does not contain a tyre.');
    }

    if (b != null && b.isTire == false) {
      final msg = clean(b.summary);
      parts.add(msg.isNotEmpty
          ? msg
          : 'Uploaded back image does not contain a tyre.');
    }

    if (parts.isEmpty) {
      return 'Uploaded image is not a tyre. Please upload clear tyre photos.';
    }

    return parts.join('\n');
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
          // ✅ KEEP UI SAME
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
                final loading =
                    state.twoWheelerStatus == TwoWheelerStatus.uploading;

                // ✅ SHOW FULLSCREEN VIDEO DURING LOADING (UNCHANGED)
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

                // ✅ APPLY "SCAN FAILED" CONDITION LIKE FOUR WHEELER
                if (state.twoWheelerStatus == TwoWheelerStatus.failure) {
                  final msg = (state.twoWheelerError ?? '').toString().trim();
                  return _ThemedScanFailedView(
                    s: s,
                    message: msg.isEmpty
                        ? 'Uploaded image is not a tyre. Please upload clear tyre photos.'
                        : msg,
                    gradient: _brandGrad,
                    onRetake: () => Navigator.of(context).pop('retake'),
                    onRetry: _retryUpload,
                  );
                }

                final resp = state.twoWheelerResponse;

                // ✅ success but any side not tyre => Scan Failed view
                if (state.twoWheelerStatus == TwoWheelerStatus.success &&
                    _anySideNotTyre(resp)) {
                  return _ThemedScanFailedView(
                    s: s,
                    message: _scanFailedMessage(resp),
                    gradient: _brandGrad,
                    onRetake: () => Navigator.of(context).pop('retake'),
                    onRetry: _retryUpload,
                  );
                }

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

// ✅ Modern overlay (UNCHANGED)
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
// ✅ REPORT SECTION (UNCHANGED UI)
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
          subtitle: (t.conditionText.trim().isEmpty)
              ? null
              : t.conditionText.replaceFirst("Status:", "Status"),
        ),
        SizedBox(height: 12 * s),
        SizedBox(height: 2 * s),

        Row(
          children: [
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText,
                icon: Icons.straighten_rounded,
                minHeight: 190 * s,
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

    // ✅ Keep UI SAME (this is for normal UI if side rendered)
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
        pressureStatusText: status.isEmpty ? "" : status,
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
// ✅ MODERN DESIGN TOKENS (UNCHANGED)
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
// ✅ UI WIDGETS (UNCHANGED)
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

    if (url.length > 100 && !url.contains(' ') && !url.startsWith('http')) {
      try {
        final bytes = base64Decode(url);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
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
        mainAxisSize: MainAxisSize.min,
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
              Icon(
                Icons.chevron_right_rounded,
                color: _Ui.subInk,
                size: 22 * s,
              ),
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

// =====================================================
// ✅ ADDED ONLY FOR SCAN FAILED SCREEN (same as 4W)
// (does not change your normal UI at all)
// =====================================================

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

// NOTE: Your existing _TyreImageCardModern, _MetricTile, _MetricCardModern,
// _SummaryCardModern classes remain unchanged from your current code.
// Keep them as-is below this point.

// enum TwoTyrePos { front, back }

// class TwoWheelerGenerateReportScreen extends StatefulWidget {
//   final String title;

//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

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
//   XFile? _back;

//   TwoTyrePos _active = TwoTyrePos.front;

//   String? _error;
//   bool _navigated = false;

//   final ImagePicker _picker = ImagePicker();

//   bool get _bothCaptured => _front != null && _back != null;

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
//         imageFormatGroup: ImageFormatGroup.yuv420,
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
//         _active = TwoTyrePos.back;
//         return;
//       }

//       if (_back == null) {
//         _back = file;
//         _active = TwoTyrePos.back;
//         return;
//       }

//       // ✅ if both exist and user picks again, replace active slot
//       if (_active == TwoTyrePos.front) {
//         _front = file;
//       } else {
//         _back = file;
//       }
//     });
//   }

//   Future<void> _capture() async {
//     if (_stopping) return;

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
//     if (_navigated) return;
//     if (_front == null || _back == null) return;

//     _navigated = true;

//     await _stopCameraSafely();
//     if (!mounted) return;

//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => TwoWheelerReportResultScreen(
//           frontPath: _front!.path,
//           backPath: _back!.path,
//           userId: widget.userId,
//           vehicleId: widget.vehicleId,
//           token: widget.token,
//           vin: widget.vin,
//           vehicleType: widget.vehicleType,
//           frontTyreId: widget.frontTyreId,
//           backTyreId: widget.backTyreId,
//         ),
//       ),
//     );

//     // ✅ after coming back, allow scanning again
//     _navigated = false;

//     if (mounted) {
//       setState(() {
//         _front = null;
//         _back = null;
//         _active = TwoTyrePos.front;
//         _error = null;
//       });
//     }

//     if (mounted) _initCam();
//   }

//   void _retake(TwoTyrePos pos) {
//     setState(() {
//       if (pos == TwoTyrePos.front) {
//         _front = null;
//         _back = null;
//         _active = TwoTyrePos.front;
//       } else {
//         _back = null;
//         _active = TwoTyrePos.back;
//       }
//       _error = null;
//     });
//   }

//   String _stepText() {
//     if (_bothCaptured) return 'Both tyres selected ✅';
//     if (_front == null) return 'Select FRONT tyre image';
//     return 'Now select BACK tyre image';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;
//     final canPreview = _ready && _controller != null && !_stopping;

//     return Scaffold(
//       body: Stack(
//         children: [
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

//           // keep if exists
//           const ScanOverlay(),

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

//           Positioned(
//             top: 175,
//             left: 16 * s,
//             right: 16 * s,
//             child: _CapturedTwoThumbsRow(
//               s: s,
//               active: _active,
//               front: _front,
//               back: _back,
//               onSelect: (pos) => setState(() => _active = pos),
//               onDelete: _retake,
//             ),
//           ),

//           Positioned(
//             left: 16 * s,
//             right: 16 * s,
//             bottom: 14 * s,
//             child: BottomActionBar(
//               enabled: !_stopping,
//               onPickGallery: _pickFromGallery,
//               onCapture: _capture,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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
//           width: previewSize.height,
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
//     required this.back,
//     required this.onSelect,
//     required this.onDelete,
//   });

//   final double s;
//   final TwoTyrePos active;
//   final XFile? front;
//   final XFile? back;

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
//           Expanded(child: _thumb("BACK", TwoTyrePos.back, back)),
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
