import 'dart:convert';

class TyreUploadResponse {
  final TyreUploadData data;
  final String? message;

  const TyreUploadResponse({required this.data, this.message});

  factory TyreUploadResponse.fromJson(Map<String, dynamic> j) {
    final dataJson = j['data'] as Map<String, dynamic>?;
    if (dataJson == null) {
      throw const FormatException('Missing "data"');
    }
    return TyreUploadResponse(
      data: TyreUploadData.fromJson(dataJson),
      message: j['message']?.toString(),
    );
  }

  @override
  String toString() => jsonEncode({'data': data.toMap(), 'message': message});
}

class TyreUploadData {
  final String userId;            // "User ID"
  final String vehicleType;       // "Vehicle Type"
  final int recordId;             // "Record ID"
  final String vehicleId;         // "Vehicle ID"
  final String? vin;              // "vin"
  final String frontWheel;        // "Front Wheel"
  final String backWheel;         // "Back Wheel"
  final String frontTyreStatus;   // "Front Tyre status"
  final String backTyreStatus;    // "Back Tyre status"

  const TyreUploadData({
    required this.userId,
    required this.vehicleType,
    required this.recordId,
    required this.vehicleId,
    required this.vin,
    required this.frontWheel,
    required this.backWheel,
    required this.frontTyreStatus,
    required this.backTyreStatus,
  });

  factory TyreUploadData.fromJson(Map<String, dynamic> j) => TyreUploadData(
        userId: j['User ID']?.toString() ?? '',
        vehicleType: j['Vehicle Type']?.toString() ?? '',
        recordId: (j['Record ID'] is int)
            ? (j['Record ID'] as int)
            : int.tryParse(j['Record ID']?.toString() ?? '0') ?? 0,
        vehicleId: j['Vehicle ID']?.toString() ?? '',
        vin: j['vin']?.toString(),
        frontWheel: j['Front Wheel']?.toString() ?? '',
        backWheel: j['Back Wheel']?.toString() ?? '',
        frontTyreStatus: j['Front Tyre status']?.toString() ?? '',
        backTyreStatus: j['Back Tyre status']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'User ID': userId,
        'Vehicle Type': vehicleType,
        'Record ID': recordId,
        'Vehicle ID': vehicleId,
        'vin': vin,
        'Front Wheel': frontWheel,
        'Back Wheel': backWheel,
        'Front Tyre status': frontTyreStatus,
        'Back Tyre status': backTyreStatus,
      };
}


// tyre_upload_data_ext.dart (or at bottom of tyre_upload_response.dart)

extension TyreUploadDataX on TyreUploadData {
  String? get frontWheelUrl => _normalizeUrl(frontWheel);
  String? get backWheelUrl  => _normalizeUrl(backWheel);

  static String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    // If backend returns a relative path like "/uploads/xyz.jpg" or "uploads/xyz.jpg"
    const host = 'http://54.162.208.215';
    return v.startsWith('/') ? '$host$v' : '$host/$v';
  }
}
