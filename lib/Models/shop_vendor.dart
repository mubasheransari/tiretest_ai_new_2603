// class ShopVendor {
//   final String id;
//   final String shopName;
//   final String? location;
//   final String? phoneNumber;
//   final String? address;
//   final String? services;
//   final String? shopImageUrl;
//   final double latitude;
//   final double longitude;

//   /// optional fields in your response (fallback safe)
//   final double rating; // derived from weights or default
//   final int? reviewCount;

//   const ShopVendor({
//     required this.id,
//     required this.shopName,
//     required this.latitude,
//     required this.longitude,
//     this.location,
//     this.phoneNumber,
//     this.address,
//     this.services,
//     this.shopImageUrl,
//     required this.rating,
//     this.reviewCount,
//   });

//   String get displayAddress =>
//       (address?.trim().isNotEmpty == true)
//           ? address!.trim()
//           : (location?.trim().isNotEmpty == true)
//               ? location!.trim()
//               : '—';

//   factory ShopVendor.fromJson(Map<String, dynamic> json) {
//     double _toDouble(dynamic v) {
//       if (v == null) return 0.0;
//       if (v is num) return v.toDouble();
//       if (v is String) return double.tryParse(v) ?? 0.0;
//       return 0.0;
//     }

//     // your API returns latitude/longitude sometimes as string
//     final lat = _toDouble(json['latitude']);
//     final lng = _toDouble(json['longitude']);

//     // rating fallback strategy:
//     // - if backend has rating => use it
//     // - else if numeric_weights/weights => use it
//     // - else default 4.5
//     double rating = 4.5;
//     final r1 = json['rating'];
//     final r2 = json['numeric_weights'];
//     final r3 = json['weights'];
//     if (r1 != null) rating = _toDouble(r1);
//     else if (r2 != null) rating = _toDouble(r2);
//     else if (r3 != null) rating = _toDouble(r3);

//     // clamp rating 0-5
//     if (rating.isNaN) rating = 4.5;
//     rating = rating.clamp(0.0, 5.0);

//     return ShopVendor(
//       id: (json['id'] ?? '').toString(),
//       shopName: (json['shopName'] ?? json['shop_name'] ?? '').toString(),
//       location: json['location']?.toString(),
//       phoneNumber: json['phoneNumber']?.toString(),
//       address: json['address']?.toString(),
//       services: json['services']?.toString(),
//       shopImageUrl: json['shopImageURL']?.toString(),
//       latitude: lat,
//       longitude: lng,
//       rating: rating,
//       reviewCount: (json['reviewCount'] is int)
//           ? json['reviewCount'] as int
//           : int.tryParse((json['reviewCount'] ?? '').toString()),
//     );
//   }
// }
class VendorPromoCode {
  final String? shopId;
  final String? userId;
  final DateTime? createdAt;
  final String? promocode;

  const VendorPromoCode({
    this.shopId,
    this.userId,
    this.createdAt,
    this.promocode,
  });

  factory VendorPromoCode.fromJson(Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return VendorPromoCode(
      shopId: json['shopId']?.toString(),
      userId: json['userId']?.toString(),
      createdAt: _toDate(json['createdAt']),
      promocode: json['promocode']?.toString(),
    );
  }
}

class ShopVendorModel {
  final String id;
  final String shopName;

  final String? location;
  final String? phoneNumber;
  final String? address;
  final String? services;
  final String? shopImageUrl;

  final double latitude;
  final double longitude;

  final String? tyreBrand;
  final double discountPercentage;
  final int navigationCount;
  final bool isSponsored;
  final VendorPromoCode? promocode;

  final double rating;
  final int? reviewCount;

  const ShopVendorModel({
    required this.id,
    required this.shopName,
    required this.latitude,
    required this.longitude,
    this.location,
    this.phoneNumber,
    this.address,
    this.services,
    this.shopImageUrl,
    this.tyreBrand,
    required this.discountPercentage,
    required this.navigationCount,
    required this.isSponsored,
    this.promocode,
    required this.rating,
    this.reviewCount,
  });

  String get displayAddress =>
      (address?.trim().isNotEmpty == true)
          ? address!.trim()
          : (location?.trim().isNotEmpty == true)
              ? location!.trim()
              : '—';

  List<String> get tyreBrandsList {
    final s = tyreBrand?.trim() ?? '';
    if (s.isEmpty) return const [];
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> get servicesList {
    final s = services?.trim() ?? '';
    if (s.isEmpty) return const [];
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory ShopVendorModel.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    int _toInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    bool _toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    final lat = _toDouble(json['latitude']);
    final lng = _toDouble(json['longitude']);

    double rating = 4.5;
    final r1 = json['rating'];
    final r2 = json['numeric_weights'];
    final r3 = json['weights'];
    if (r1 != null) rating = _toDouble(r1, fallback: 4.5);
    else if (r2 != null) rating = _toDouble(r2, fallback: 4.5);
    else if (r3 != null) rating = _toDouble(r3, fallback: 4.5);

    if (rating.isNaN) rating = 4.5;
    rating = rating.clamp(0.0, 5.0);

    final promoRaw = json['promocode'];
    VendorPromoCode? promo;
    if (promoRaw is Map) {
      promo = VendorPromoCode.fromJson(Map<String, dynamic>.from(promoRaw));
    }

    return ShopVendorModel(
      id: (json['id'] ?? '').toString(),
      shopName: (json['shopName'] ?? json['shop_name'] ?? '').toString(),
      location: json['location']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address']?.toString(),
      services: json['services']?.toString(),
      shopImageUrl: (json['shopImageURL'] == null)
          ? null
          : json['shopImageURL']?.toString(),
      latitude: lat,
      longitude: lng,
      tyreBrand: json['tyreBrand']?.toString(),
      discountPercentage: _toDouble(json['discountPercentage'], fallback: 0.0),
      navigationCount: _toInt(json['navigationCount'], fallback: 0),
      isSponsored: _toBool(json['isSponsored']),
      promocode: promo,
      rating: rating,
      reviewCount: (json['reviewCount'] is int)
          ? json['reviewCount'] as int
          : int.tryParse((json['reviewCount'] ?? '').toString()),
    );
  }
}
