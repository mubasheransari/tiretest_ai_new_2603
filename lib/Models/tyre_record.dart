import 'package:equatable/equatable.dart';

// class TyreRecord extends Equatable {
//   final String userId;
//   final int recordId;
//   final String vehicleType; // "car" | "bike"
//   final String vehicleId;

//   final String frontLeftStatus;
//   final String frontRightStatus;
//   final String backLeftStatus;
//   final String backRightStatus;

//   final DateTime uploadedAt;

//   final String frontLeftWheelFile;
//   final String frontRightWheelFile;
//   final String backLeftWheelFile;
//   final String backRightWheelFile;

//   final String vin;

//   const TyreRecord({
//     required this.userId,
//     required this.recordId,
//     required this.vehicleType,
//     required this.vehicleId,
//     required this.frontLeftStatus,
//     required this.frontRightStatus,
//     required this.backLeftStatus,
//     required this.backRightStatus,
//     required this.uploadedAt,
//     required this.frontLeftWheelFile,
//     required this.frontRightWheelFile,
//     required this.backLeftWheelFile,
//     required this.backRightWheelFile,
//     required this.vin,
//   });

//   /// Your API uses keys with spaces & mixed case. We map safely.
//   factory TyreRecord.fromJson(Map<String, dynamic> json) {
//     String s(dynamic v) => (v ?? '').toString();

//     DateTime parseDate(dynamic v) {
//       final raw = s(v);
//       // API example: "2025-12-31T15:16:23"
//       final dt = DateTime.tryParse(raw);
//       return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
//     }

//     return TyreRecord(
//       userId: s(json['User ID']),
//       recordId: int.tryParse(s(json['Record ID'])) ?? 0,
//       vehicleType: s(json['Vehicle type']).toLowerCase().trim(),
//       vehicleId: s(json['Vehicle ID']),
//       frontLeftStatus: s(json['Front Left Tyre status']),
//       frontRightStatus: s(json['Front Right Tyre status']),
//       backLeftStatus: s(json['Back Left Tyre status']),
//       backRightStatus: s(json['Back Right Tyre status']),
//       uploadedAt: parseDate(json['Uploaded Datetime']),
//       frontLeftWheelFile: s(json['Front Left Wheel']),
//       frontRightWheelFile: s(json['Front Right Wheel']),
//       backLeftWheelFile: s(json['Back Left Wheel']),
//       backRightWheelFile: s(json['Back Right Wheel']),
//       vin: s(json['Vin']),
//     );
//   }

//   @override
//   List<Object?> get props => [
//         userId,
//         recordId,
//         vehicleType,
//         vehicleId,
//         frontLeftStatus,
//         frontRightStatus,
//         backLeftStatus,
//         backRightStatus,
//         uploadedAt,
//         frontLeftWheelFile,
//         frontRightWheelFile,
//         backLeftWheelFile,
//         backRightWheelFile,
//         vin,
//       ];
// }
// tyre_record.dart






// tyre_record.dart
class TyreRecord {
  // common
  final String userId;
  final int recordId;
  final String vehicleType;
  final String vehicleId;
  final String vin;
  final DateTime uploadedAt;

  // ✅ NEW vehicle meta (from your sample)
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleTyreBrand;
  final String vehicleTyreDimension;
  final String vehicleLicense;

  // car images
  final String frontLeftWheel;
  final String frontRightWheel;
  final String backLeftWheel;
  final String backRightWheel;

  // bike images
  final String bikeFrontWheel;
  final String bikeBackWheel;

  // bike fields
  final String bikeFrontStatus;
  final String bikeFrontTread;
  final String bikeFrontWearPatterns;
  final dynamic bikeFrontPressure;
  final String bikeFrontSummary;

  final String bikeBackStatus;
  final String bikeBackTread;
  final String bikeBackWearPatterns;
  final dynamic bikeBackPressure;
  final String bikeBackSummary;

  // car fields
  final String frontLeftStatus;
  final String frontLeftTread;
  final String frontLeftWearPatterns;
  final dynamic frontLeftPressure;
  final String frontLeftSummary;

  final String frontRightStatus;
  final String frontRightTread;
  final String frontRightWearPatterns;
  final dynamic frontRightPressure;
  final String frontRightSummary;

  final String backLeftStatus;
  final String backLeftTread;
  final String backLeftWearPatterns;
  final dynamic backLeftPressure;
  final String backLeftSummary;

  final String backRightStatus;
  final String backRightTread;
  final String backRightWearPatterns;
  final dynamic backRightPressure;
  final String backRightSummary;

  TyreRecord({
    required this.userId,
    required this.recordId,
    required this.vehicleType,
    required this.vehicleId,
    required this.vin,
    required this.uploadedAt,

    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleTyreBrand,
    required this.vehicleTyreDimension,
    required this.vehicleLicense,

    required this.frontLeftWheel,
    required this.frontRightWheel,
    required this.backLeftWheel,
    required this.backRightWheel,

    required this.bikeFrontWheel,
    required this.bikeBackWheel,

    required this.bikeFrontStatus,
    required this.bikeFrontTread,
    required this.bikeFrontWearPatterns,
    required this.bikeFrontPressure,
    required this.bikeFrontSummary,

    required this.bikeBackStatus,
    required this.bikeBackTread,
    required this.bikeBackWearPatterns,
    required this.bikeBackPressure,
    required this.bikeBackSummary,

    required this.frontLeftStatus,
    required this.frontLeftTread,
    required this.frontLeftWearPatterns,
    required this.frontLeftPressure,
    required this.frontLeftSummary,

    required this.frontRightStatus,
    required this.frontRightTread,
    required this.frontRightWearPatterns,
    required this.frontRightPressure,
    required this.frontRightSummary,

    required this.backLeftStatus,
    required this.backLeftTread,
    required this.backLeftWearPatterns,
    required this.backLeftPressure,
    required this.backLeftSummary,

    required this.backRightStatus,
    required this.backRightTread,
    required this.backRightWearPatterns,
    required this.backRightPressure,
    required this.backRightSummary,
  });

  static String _s(dynamic v) => (v ?? '').toString();

  static String _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) {
        final val = _s(j[k]).trim();
        if (val.isNotEmpty) return val;
      }
    }
    return '';
  }

  static DateTime _parseDate(dynamic v) {
    final s = _s(v).trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(s)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory TyreRecord.fromApi(Map<String, dynamic> j) {
    final vehicleType = _pick(j, ['Vehicle type', 'vehicle_type', 'vehicleType']);
    final uploadedAt = _parseDate(_pick(j, [
      'Uploaded Datetime',
      'Uploaded datetime',
      'uploaded_datetime',
      'uploadedAt',
      'uploaded_at'
    ]));

    return TyreRecord(
      userId: _pick(j, ['User ID', 'user_id', 'userId']),
      recordId: int.tryParse(_pick(j, ['Record ID', 'record_id', 'recordId'])) ?? 0,
      vehicleType: vehicleType,
      vehicleId: _pick(j, ['Vehicle ID', 'vehicle_id', 'vehicleId']),
      vin: _pick(j, ['Vin', 'VIN', 'vin']),
      uploadedAt: uploadedAt,

      // ✅ NEW meta
      vehicleBrand: _pick(j, ['Vehicle Brand', 'vehicle_brand', 'vehicleBrand']),
      vehicleModel: _pick(j, ['Vehicle Model', 'vehicle_model', 'vehicleModel']),
      vehicleTyreBrand: _pick(j, ['Vehicle Tyre Brand', 'vehicle_tyre_brand', 'vehicleTyreBrand']),
      vehicleTyreDimension: _pick(j, ['Vehicle Tyre Dimension', 'vehicle_tyre_dimension', 'vehicleTyreDimension']),
      vehicleLicense: _pick(j, ['Vehicle License', 'vehicle_license', 'vehicleLicense']),

      // Images
      frontLeftWheel: _pick(j, ['Front Left Wheel', 'frontLeftWheel', 'front_left_wheel']),
      frontRightWheel: _pick(j, ['Front Right Wheel', 'frontRightWheel', 'front_right_wheel']),
      backLeftWheel: _pick(j, ['Back Left Wheel', 'backLeftWheel', 'back_left_wheel']),
      backRightWheel: _pick(j, ['Back Right Wheel', 'backRightWheel', 'back_right_wheel']),

      bikeFrontWheel: _pick(j, ['Front Wheel', 'bikeFrontWheel', 'front_wheel']),
      bikeBackWheel: _pick(j, ['Back Wheel', 'bikeBackWheel', 'back_wheel']),

      // Bike fields
      bikeFrontStatus: _pick(j, ['Front Tyre status', 'frontTyreStatus']),
      bikeFrontTread: _pick(j, ['Front Tyre tread', 'frontTyreTread']),
      bikeFrontWearPatterns: _pick(j, ['Front Tyre wear patterns', 'frontTyreWearPatterns']),
      bikeFrontPressure: j['Front Tyre pressure'] ?? j['frontTyrePressure'],
      bikeFrontSummary: _pick(j, ['Front Tyre summary', 'frontTyreSummary']),

      bikeBackStatus: _pick(j, ['Back Tyre status', 'backTyreStatus']),
      bikeBackTread: _pick(j, ['Back Tyre tread', 'backTyreTread']),
      bikeBackWearPatterns: _pick(j, ['Back Tyre wear patterns', 'backTyreWearPatterns']),
      bikeBackPressure: j['Back Tyre pressure'] ?? j['backTyrePressure'],
      bikeBackSummary: _pick(j, ['Back Tyre summary', 'backTyreSummary']),

      // Car fields (✅ fixed key names for your sample: "Front Left Tyre status")
      frontLeftStatus: _pick(j, ['Front Left Tyre status', 'Front Left status', 'front_left_status', 'frontLeftStatus']),
      frontLeftTread: _pick(j, ['Front Left tread', 'front_left_tread', 'frontLeftTread']),
      frontLeftWearPatterns: _pick(j, ['Front Left wear patterns', 'front_left_wear_patterns', 'frontLeftWearPatterns']),
      frontLeftPressure: j['Front Left Tyre pressure'] ?? j['Front Left pressure'] ?? j['front_left_pressure'] ?? j['frontLeftPressure'],
      frontLeftSummary: _pick(j, ['Front Left summary', 'front_left_summary', 'frontLeftSummary']),

      frontRightStatus: _pick(j, ['Front Right Tyre status', 'Front Right status', 'front_right_status', 'frontRightStatus']),
      frontRightTread: _pick(j, ['Front Right tread', 'front_right_tread', 'frontRightTread']),
      frontRightWearPatterns: _pick(j, ['Front Right wear patterns', 'front_right_wear_patterns', 'frontRightWearPatterns']),
      frontRightPressure: j['Front Right Tyre pressure'] ?? j['Front Right pressure'] ?? j['front_right_pressure'] ?? j['frontRightPressure'],
      frontRightSummary: _pick(j, ['Front Right summary', 'front_right_summary', 'frontRightSummary']),

      backLeftStatus: _pick(j, ['Back Left Tyre status', 'Back Left status', 'back_left_status', 'backLeftStatus']),
      backLeftTread: _pick(j, ['Back Left tread', 'back_left_tread', 'backLeftTread']),
      backLeftWearPatterns: _pick(j, ['Back Left wear patterns', 'back_left_wear_patterns', 'backLeftWearPatterns']),
      backLeftPressure: j['Back Left Tyre pressure'] ?? j['Back Left pressure'] ?? j['back_left_pressure'] ?? j['backLeftPressure'],
      backLeftSummary: _pick(j, ['Back Left summary', 'back_left_summary', 'backLeftSummary']),

      backRightStatus: _pick(j, ['Back Right Tyre status', 'Back Right status', 'back_right_status', 'backRightStatus']),
      backRightTread: _pick(j, ['Back Right tread', 'back_right_tread', 'backRightTread']),
      backRightWearPatterns: _pick(j, ['Back Right wear patterns', 'back_right_wear_patterns', 'backRightWearPatterns']),
      backRightPressure: j['Back Right Tyre pressure'] ?? j['Back Right pressure'] ?? j['back_right_pressure'] ?? j['backRightPressure'],
      backRightSummary: _pick(j, ['Back Right summary', 'back_right_summary', 'backRightSummary']),
    );
  }
}