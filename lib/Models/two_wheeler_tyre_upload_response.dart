class TwoWheelerTyreUploadResponse {
  final TwoWheelerUploadData? data;
  final String message;

  TwoWheelerTyreUploadResponse({
    required this.data,
    required this.message,
  });

  factory TwoWheelerTyreUploadResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];

    return TwoWheelerTyreUploadResponse(
      data: raw is Map<String, dynamic>
          ? TwoWheelerUploadData.fromJson(raw)
          : null,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class TwoWheelerUploadData {
  final int recordId;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  TwoWheelerUploadData({
    required this.recordId,
    required this.front,
    required this.back,
  });

  factory TwoWheelerUploadData.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) =>
        (v is int) ? v : int.tryParse((v ?? '').toString()) ?? 0;

    return TwoWheelerUploadData(
      recordId: _asInt(json['record_id']),
      front: json['front'] is Map<String, dynamic>
          ? TwoWheelerTyreSide.fromJson(json['front'] as Map<String, dynamic>)
          : null,
      back: json['back'] is Map<String, dynamic>
          ? TwoWheelerTyreSide.fromJson(json['back'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TwoWheelerTyreSide {
  /// ✅ NEW (Backend flag): tells if uploaded image contains a vehicle tyre.
  final bool isTire;

  /// If [isTire] is false, these fields can be empty/0.
  final String condition;
  final double treadDepth;
  final String wearPatterns;
  final TwoWheelerPressureAdvisory? pressureAdvisory;
  final TwoWheelerSidewall? sidewall;
  final String summary;
  final String image; // can be base64/data-uri/url

  TwoWheelerTyreSide({
    required this.isTire,
    required this.condition,
    required this.treadDepth,
    required this.wearPatterns,
    required this.pressureAdvisory,
    required this.sidewall,
    required this.summary,
    required this.image,
  });

  factory TwoWheelerTyreSide.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString()) ?? 0.0;
    }

    bool _asBool(dynamic v) {
      if (v == null) return true; // backward compatibility
      if (v is bool) return v;
      final s = (v ?? '').toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return TwoWheelerTyreSide(
      isTire: _asBool(json['is_tire']),
      condition: (json['condition'] ?? '').toString(),
      treadDepth: _asDouble(json['tread_depth']),
      wearPatterns: (json['wear_patterns'] ?? '').toString(),
      pressureAdvisory: json['pressure_advisory'] is Map<String, dynamic>
          ? TwoWheelerPressureAdvisory.fromJson(
              json['pressure_advisory'] as Map<String, dynamic>,
            )
          : json['tire_pressure'] is Map<String, dynamic>
              ? TwoWheelerPressureAdvisory.fromJson(
                  json['tire_pressure'] as Map<String, dynamic>,
                )
              : null,
      sidewall: json['sidewall'] is Map<String, dynamic>
          ? TwoWheelerSidewall.fromJson(json['sidewall'] as Map<String, dynamic>)
          : null,
      summary: (json['summary'] ?? '').toString(),
      // ✅ backend sample returns `image`, but keep `image_url` fallback.
      image: (json['image'] ?? json['image_url'] ?? '').toString(),
    );
  }
}

class TwoWheelerSidewall {
  final bool isTire;
  final String brand;
  final String model;
  final String size;
  final dynamic width;
  final dynamic aspectRatio;
  final dynamic rimDiameter;
  final String loadIndex;
  final String speedRating;
  final String manufacturingDate;
  final TwoWheelerSidewallDamage? sidewallDamage;
  final String confidence;

  TwoWheelerSidewall({
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
    required this.sidewallDamage,
    required this.confidence,
  });

  factory TwoWheelerSidewall.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) {
      if (v == null) return true;
      if (v is bool) return v;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return TwoWheelerSidewall(
      isTire: asBool(json['is_tire']),
      brand: (json['brand'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      width: json['width'],
      aspectRatio: json['aspect_ratio'],
      rimDiameter: json['rim_diameter'],
      loadIndex: (json['load_index'] ?? '').toString(),
      speedRating: (json['speed_rating'] ?? '').toString(),
      manufacturingDate: (json['manufacturing_date'] ?? '').toString(),
      sidewallDamage: json['sidewall_damage'] is Map<String, dynamic>
          ? TwoWheelerSidewallDamage.fromJson(json['sidewall_damage'] as Map<String, dynamic>)
          : null,
      confidence: (json['confidence'] ?? '').toString(),
    );
  }
}

class TwoWheelerSidewallDamage {
  final String status;
  final String description;

  TwoWheelerSidewallDamage({required this.status, required this.description});

  factory TwoWheelerSidewallDamage.fromJson(Map<String, dynamic> json) {
    return TwoWheelerSidewallDamage(
      status: (json['status'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class TwoWheelerPressureAdvisory {
  final String status;
  final String reason;
  final String confidence;

  TwoWheelerPressureAdvisory({
    required this.status,
    required this.reason,
    required this.confidence,
  });

  factory TwoWheelerPressureAdvisory.fromJson(Map<String, dynamic> json) {
    return TwoWheelerPressureAdvisory(
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      confidence: (json['confidence'] ?? '').toString(),
    );
  }
}
