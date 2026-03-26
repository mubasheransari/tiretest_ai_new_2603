import 'dart:convert';

/// ✅ Parse from raw JSON string
ResponseFourWheeler responseFourWheelerFromJson(String str) =>
    ResponseFourWheeler.fromJson(json.decode(str) as Map<String, dynamic>);

/// ✅ Convert to raw JSON string
String responseFourWheelerToJson(ResponseFourWheeler data) =>
    json.encode(data.toJson());

/// ---------------------------------------------------------------------------
/// 4-Wheeler upload response model
///
/// Supports **NEW** backend structure (nested objects):
/// {
///   "data": {
///     "User ID": "...",
///     "Vehicle type": "car",
///     "Record ID": 675,
///     "Vehicle ID": "...",
///     "Vin": "",
///     "front_left": {"is_tire": false, ...},
///     "front_right": {"is_tire": true, ...},
///     "back_left": {...},
///     "back_right": {...}
///   },
///   "message": "successful"
/// }
///
/// Also keeps backward compatibility with the older flat-key response (if any).
/// ---------------------------------------------------------------------------

class ResponseFourWheeler {
  final FourWheelerData data;
  final String message;

  const ResponseFourWheeler({
    required this.data,
    required this.message,
  });

  factory ResponseFourWheeler.fromJson(Map<String, dynamic> json) {
    return ResponseFourWheeler(
      data: FourWheelerData.fromJson(
        (json['data'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
      message: (json['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
        'message': message,
      };
}

class TirePressure {
  final String status;
  final String reason;
  final String confidence;

  const TirePressure({
    required this.status,
    required this.reason,
    required this.confidence,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory TirePressure.fromJson(Map<String, dynamic> json) => TirePressure(
        status: _s(json['status']),
        reason: _s(json['reason']),
        confidence: _s(json['confidence']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'reason': reason,
        'confidence': confidence,
      };
}

class FourWheelerTyreSide {
  /// ✅ NEW: backend tells if uploaded image is a tyre
  final bool isTire;

  /// Can be null/empty if [isTire] is false.
  final String? condition;
  final double? treadDepth;
  final String? wearPatterns;
  final TirePressure? pressure;
  final String? summary;
  final String? image; // base64/data-uri/url

  const FourWheelerTyreSide({
    required this.isTire,
    required this.condition,
    required this.treadDepth,
    required this.wearPatterns,
    required this.pressure,
    required this.summary,
    required this.image,
  });

  static String? _sn(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool _bn(dynamic v) {
    if (v == null) return true; // backward compatibility
    if (v is bool) return v;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static TirePressure? _tp(dynamic v) {
    if (v is Map<String, dynamic>) return TirePressure.fromJson(v);
    if (v is Map) return TirePressure.fromJson(Map<String, dynamic>.from(v));
    return null;
  }

  factory FourWheelerTyreSide.fromJson(Map<String, dynamic> json) {
    return FourWheelerTyreSide(
      isTire: _bn(json['is_tire']),
      condition: _sn(json['condition']),
      treadDepth: _dn(json['tread_depth']),
      wearPatterns: _sn(json['wear_patterns']),
      pressure: _tp(json['pressure'] ?? json['pressure_advisory']),
      summary: _sn(json['summary']),
      image: _sn(json['image'] ?? json['image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'is_tire': isTire,
        'condition': condition,
        'tread_depth': treadDepth,
        'wear_patterns': wearPatterns,
        'pressure': pressure?.toJson(),
        'summary': summary,
        'image': image,
      };
}

class FourWheelerData {
  final String userId;
  final String vehicleType;
  final int recordId;
  final String vehicleId;
  final String vin;

  final FourWheelerTyreSide? frontLeft;
  final FourWheelerTyreSide? frontRight;
  final FourWheelerTyreSide? backLeft;
  final FourWheelerTyreSide? backRight;

  const FourWheelerData({
    required this.userId,
    required this.vehicleType,
    required this.recordId,
    required this.vehicleId,
    required this.vin,
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static FourWheelerTyreSide? _side(dynamic v) {
    if (v is Map<String, dynamic>) return FourWheelerTyreSide.fromJson(v);
    if (v is Map) return FourWheelerTyreSide.fromJson(Map<String, dynamic>.from(v));
    return null;
  }

  /// ✅ helper for validation
  List<NotTyreSide> notTyreSides() {
    final list = <NotTyreSide>[];
    if (frontLeft != null && frontLeft!.isTire == false) {
      list.add(const NotTyreSide('Front Left', 'front_left'));
    }
    if (frontRight != null && frontRight!.isTire == false) {
      list.add(const NotTyreSide('Front Right', 'front_right'));
    }
    if (backLeft != null && backLeft!.isTire == false) {
      list.add(const NotTyreSide('Back Left', 'back_left'));
    }
    if (backRight != null && backRight!.isTire == false) {
      list.add(const NotTyreSide('Back Right', 'back_right'));
    }
    return list;
  }

  factory FourWheelerData.fromJson(Map<String, dynamic> json) {
    // ✅ NEW nested structure
    final hasNested = json.containsKey('front_left') ||
        json.containsKey('front_right') ||
        json.containsKey('back_left') ||
        json.containsKey('back_right');

    if (hasNested) {
      return FourWheelerData(
        userId: _s(json['User ID'] ?? json['user_id']),
        vehicleType: _s(json['Vehicle type'] ?? json['vehicle_type']),
        recordId: _i(json['Record ID'] ?? json['record_id']),
        vehicleId: _s(json['Vehicle ID'] ?? json['vehicle_id']),
        vin: _s(json['Vin'] ?? json['vin']),
        frontLeft: _side(json['front_left']),
        frontRight: _side(json['front_right']),
        backLeft: _side(json['back_left']),
        backRight: _side(json['back_right']),
      );
    }

    // ✅ BACKWARD COMPATIBILITY (older flat-key response)
    // We map the old fields into the new structure so the UI still works.
    FourWheelerTyreSide? _fromOld(String prefix) {
      // Old payload didn't have is_tire, assume true.
      return FourWheelerTyreSide(
        isTire: true,
        condition: _s(json['$prefix Tyre status']).isEmpty
            ? null
            : _s(json['$prefix Tyre status']),
        treadDepth: double.tryParse(_s(json['$prefix Tread depth'])),
        wearPatterns: _s(json['$prefix Wear patterns']).isEmpty
            ? null
            : _s(json['$prefix Wear patterns']),
        pressure: null,
        summary: _s(json['$prefix Summary']).isEmpty ? null : _s(json['$prefix Summary']),
        image: _s(json['$prefix Wheel']).isEmpty ? null : _s(json['$prefix Wheel']),
      );
    }

    return FourWheelerData(
      userId: _s(json['User ID'] ?? json['user_id']),
      vehicleType: _s(json['Vehicle type'] ?? json['vehicle_type']),
      recordId: _i(json['Record ID'] ?? json['record_id']),
      vehicleId: _s(json['Vehicle ID'] ?? json['vehicle_id']),
      vin: _s(json['Vin'] ?? json['vin']),
      frontLeft: _fromOld('Front Left'),
      frontRight: _fromOld('Front Right'),
      backLeft: _fromOld('Back Left'),
      backRight: _fromOld('Back Right'),
    );
  }

  Map<String, dynamic> toJson() => {
        'User ID': userId,
        'Vehicle type': vehicleType,
        'Record ID': recordId,
        'Vehicle ID': vehicleId,
        'Vin': vin,
        'front_left': frontLeft?.toJson(),
        'front_right': frontRight?.toJson(),
        'back_left': backLeft?.toJson(),
        'back_right': backRight?.toJson(),
      };
}

class NotTyreSide {
  final String label;
  final String key;
  const NotTyreSide(this.label, this.key);
}
