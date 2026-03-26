import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';

class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontPath,
    required this.backPath,
    this.response,
  });

  final String frontPath;
  final String backPath;
  final TyreUploadResponse? response;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  @override
  void initState() {
    super.initState();
    var userid = context.read<AuthBloc>().state.profile!.userId.toString();
    context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393; 
    final data = widget.response?.data;

    // images
    final frontImg =
        (data?.frontWheelUrl != null && data!.frontWheelUrl!.isNotEmpty)
        ? NetworkImage(data.frontWheelUrl!)
        : FileImage(File(widget.frontPath)) as ImageProvider;

    final backImg =
        (data?.backWheelUrl != null && data!.backWheelUrl!.isNotEmpty)
        ? NetworkImage(data.backWheelUrl!)
        : FileImage(File(widget.backPath)) as ImageProvider;

    final extraImg = const AssetImage('assets/bike_wheel.png');

    // text data
    final treadDepth = data?.treadDepth ?? '7.2 mm';
    final treadStatus = data?.treadStatus ?? 'Good';

    final tyrePressure = data?.tyrePressure?.toString() ?? '32 psi';
    final tyrePressureStatus = data?.tyrePressureStatus ?? 'Optimal';

    final damageCheck = data?.damageCheck ?? 'No cracks';
    final damageStatus = data?.damageStatus ?? 'Safe';

    final summary =
        widget.response?.message ??
        'Your wheel is in good condition with optimal tread depth and balanced pressure. '
            'No major wear or cracks detected.';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F8),
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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * s, 30 * s, 16 * s, 28 * s),
        children: [
          // top images
          /*  Row(
            children: [
              _PhotoCard(
                s: s,
                image: frontImg,
                label: 'left',
            
              ),
              SizedBox(width: 12 * s),
              _PhotoCard(
                s: s,
                image: backImg,
                label: 'gvbr',

              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: _PhotoCard(
                  s: s,
                  image: extraImg,
                  label: 'middle',
        
                ),
              ),
            ],
          ),*/
          SizedBox(height: 18 * s),

          // metrics area like mock
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // big left card: Tread Depth
              Expanded(
                flex: 14,
                child: _BigMetricCard(
                  s: s,
                  iconBg: const LinearGradient(
                    colors: [Color(0xFF4F7BFF), Color(0xFFA6C8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.sync, // use tyre icon if you have
                  title: 'Tread Depth',
                  value: 'Value: $treadDepth',
                  status: 'Status: $treadStatus',
                ),
              ),
              SizedBox(width: 14 * s),
              // right column: 2 small cards
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    _SmallMetricCard(
                      s: s,
                      title: 'Tire Pressure',
                      value: 'Value: $tyrePressure',
                      status: 'Status: $tyrePressureStatus',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F7BFF), Color(0xFF80B3FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    _SmallMetricCard(
                      s: s,
                      title: 'Damage Check',
                      value: 'Value: $damageCheck',
                      status: 'Status: $damageStatus',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF69A3FF), Color(0xFF9C7FFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * s),

          // report summary card
          _ReportSummaryCard(s: s, title: 'Report Summary:', summary: summary),
          SizedBox(height: 18 * s),

          // actions (keep your buttons)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB8C1D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14 * s),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF4F7BFF),
                  ),
                  label: Text(
                    'Share Report',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F7BFF),
                    ),
                  ),
                  onPressed: () => _toast(context, 'Share pressed'),
                ),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F7BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15 * s),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download PDF',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 14 * s,
                    ),
                  ),
                  onPressed: () => _toast(context, 'Download pressed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}

/* ====== widgets ====== */

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.s,
    required this.image,
    required this.label,
    // required this.gradient,
  });

  final double s;
  final ImageProvider image;
  final String label;
  // final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 103 * s,
      // decoration: BoxDecoration(
      //   borderRadius: BorderRadius.circular(18 * s),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(.04),
      //       blurRadius: 8 * s,
      //       offset: Offset(0, 3 * s),
      //     ),
      //   ],
      // ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18 * s),
            child: AspectRatio(
              aspectRatio: 0.9,
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 8 * s),
          Container(
            height: 28 * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7BFF), Color(0xFF5FD1FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7BFF).withOpacity(.35),
                  blurRadius: 14 * s,
                  offset: Offset(0, 6 * s),
                ),
              ],
            ),
            child: Text(
              'gtgt',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13 * s,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigMetricCard extends StatelessWidget {
  const _BigMetricCard({
    required this.s,
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });

  final double s;
  final Gradient iconBg;
  final IconData icon;
  final String title;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 195 * s,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14 * s,
            offset: Offset(0, 8 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // icon
          Container(
            width: 50 * s,
            height: 50 * s,
            decoration: BoxDecoration(
              gradient: iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B9BFF).withOpacity(.35),
                  blurRadius: 12 * s,
                  offset: Offset(0, 5 * s),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26 * s),
          ),
          SizedBox(height: 12 * s),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 20 * s,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4F7BFF),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 15 * s,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            status,
            style: TextStyle(
              color: Colors.black.withOpacity(.8),
              fontSize: 14 * s,
            ),
          ),
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
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(13 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: const Color(0xFFE8E9F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 9 * s,
            offset: Offset(0, 5 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (r) => gradient.createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w800,
                fontSize: 17 * s,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 14.5 * s,
              color: const Color(0xFF111826),
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            status,
            style: TextStyle(
              color: Colors.black.withOpacity(.5),
              fontSize: 13 * s,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // left icon circle
          Container(
            width: 54 * s,
            height: 54 * s,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7BFF), Color(0xFF5FD1FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7BFF).withOpacity(.35),
                  blurRadius: 14 * s,
                  offset: Offset(0, 6 * s),
                ),
              ],
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 26 * s,
            ),
          ),
          SizedBox(width: 14 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 18 * s,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black,
                      size: 24 * s,
                    ),
                  ],
                ),
                SizedBox(height: 6 * s),
                Text(
                  summary,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14.5 * s,
                    color: Colors.black.withOpacity(.75),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ====== dummy model so code compiles ====== */
class TyreUploadResponse {
  final String? message;
  final TyreData? data;
  TyreUploadResponse({this.message, this.data});
}

class TyreData {
  final String? frontWheelUrl;
  final String? backWheelUrl;
  final String? frontTyreStatus;
  final String? backTyreStatus;
  final String? vehicleId;
  final String? vehicleType;
  final String? recordId;
  final String? vin;
  final String? treadDepth;
  final String? treadStatus;
  final num? tyrePressure;
  final String? tyrePressureStatus;
  final String? damageCheck;
  final String? damageStatus;
  TyreData({
    this.frontWheelUrl,
    this.backWheelUrl,
    this.frontTyreStatus,
    this.backTyreStatus,
    this.vehicleId,
    this.vehicleType,
    this.recordId,
    this.vin,
    this.treadDepth,
    this.treadStatus,
    this.tyrePressure,
    this.tyrePressureStatus,
    this.damageCheck,
    this.damageStatus,
  });
}
