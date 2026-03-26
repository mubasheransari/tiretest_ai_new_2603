class AdItem {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int credits;
  final int creditsUsed;
  final String status; // "active"
  final DateTime? createdAt;
  final String audience; // local/countrywide
  final String media; // mp4 url (signed)
  final double radius;

  const AdItem({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.credits,
    required this.creditsUsed,
    required this.status,
    required this.createdAt,
    required this.audience,
    required this.media,
    required this.radius,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory AdItem.fromJson(Map<String, dynamic> json) {
    double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    return AdItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      latitude: _d(json['latitude']),
      longitude: _d(json['longitude']),
      credits: _i(json['credits']),
      creditsUsed: _i(json['creditsUsed']),
      status: (json['status'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      audience: (json['audience'] ?? '').toString(),
      media: (json['media'] ?? '').toString(),
      radius: _d(json['radius']),
    );
  }
}

class AdsResponse {
  final List<AdItem> data;
  final String? message;

  const AdsResponse({required this.data, this.message});

  factory AdsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final list = (raw is List)
        ? raw
            .whereType<Map>()
            .map((e) => AdItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdItem>[];
    return AdsResponse(data: list, message: json['message']?.toString());
  }
}
