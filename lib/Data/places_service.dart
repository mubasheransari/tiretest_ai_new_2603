import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ios_tiretest_ai/models/place_marker_data.dart';

class PlacesService {
  PlacesService({
    required this.apiKey,
    this.radiusMeters = 20000,
  });

  final String apiKey;
  final int radiusMeters;

  static const List<String> _priorityKeywords = [
    'tyre shop',
    'tire shop',
    'tyre repair',
    'puncture repair',
    'wheel alignment',
  ];

  Future<List<PlaceMarkerData>> fetchAll({
    required double lat,
    required double lng,
  }) async {
    if (apiKey.trim().isEmpty || apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      return [];
    }

    final dedup = <String, PlaceMarkerData>{};

    Future<void> collect(Future<List<PlaceMarkerData>> future) async {
      try {
        final list = await future.timeout(const Duration(seconds: 7));
        for (final p in list) {
          dedup[p.id] = p;
        }
      } catch (_) {}
    }

    await Future.wait([
      for (final keyword in _priorityKeywords.take(3))
        collect(_nearbyRankByDistance(lat: lat, lng: lng, keyword: keyword)),
      for (final keyword in _priorityKeywords)
        collect(_nearbySearchSinglePage(lat: lat, lng: lng, radius: radiusMeters, keyword: keyword)),
      collect(_nearbySearchSinglePage(lat: lat, lng: lng, radius: radiusMeters, type: 'car_repair')),
      collect(_textSearchSinglePage(lat: lat, lng: lng, radius: radiusMeters, query: 'tyre shop')),
      collect(_textSearchSinglePage(lat: lat, lng: lng, radius: radiusMeters, query: 'tire shop')),
    ]);

    final all = dedup.values.toList();
    if (all.isEmpty) return all;

    final tyreOnly = _filterTyreLikeNames(all);
    return tyreOnly.isNotEmpty ? tyreOnly : all;
  }

  List<PlaceMarkerData> _filterTyreLikeNames(List<PlaceMarkerData> list) {
    bool ok(String? t) {
      final s = (t ?? '').toLowerCase();
      return s.contains('tyre') ||
          s.contains('tire') ||
          s.contains('puncture') ||
          s.contains('wheel') ||
          s.contains('alignment') ||
          s.contains('balancing') ||
          s.contains('garage') ||
          s.contains('auto');
    }

    return list.where((p) => ok(p.name)).toList();
  }

  Future<List<PlaceMarkerData>> _nearbyRankByDistance({
    required double lat,
    required double lng,
    required String keyword,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'key': apiKey,
      'location': '$lat,$lng',
      'rankby': 'distance',
      'keyword': keyword,
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

    if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    return _placesFromResults(results);
  }

  Future<List<PlaceMarkerData>> _nearbySearchSinglePage({
    required double lat,
    required double lng,
    required int radius,
    String? keyword,
    String? type,
  }) async {
    final params = <String, String>{
      'key': apiKey,
      'location': '$lat,$lng',
      'radius': '$radius',
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
    };

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);
    final res = await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

    if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    return _placesFromResults(results);
  }

  Future<List<PlaceMarkerData>> _textSearchSinglePage({
    required double lat,
    required double lng,
    required int radius,
    required String query,
  }) async {
    final params = <String, String>{
      'key': apiKey,
      'query': query,
      'location': '$lat,$lng',
      'radius': '$radius',
    };

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', params);
    final res = await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

    if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    return _placesFromResults(results);
  }

  List<PlaceMarkerData> _placesFromResults(List results) {
    final out = <PlaceMarkerData>[];

    for (final r in results) {
      final m = (r as Map).cast<String, dynamic>();

      final placeId = (m['place_id'] ?? '').toString();
      final name = (m['name'] ?? 'Tyre shop').toString();

      final loc = ((m['geometry'] as Map?)?['location'] as Map?) ?? const {};
      final plat = (loc['lat'] as num?)?.toDouble();
      final plng = (loc['lng'] as num?)?.toDouble();

      if (placeId.isEmpty || plat == null || plng == null) continue;

      out.add(PlaceMarkerData(id: placeId, name: name, lat: plat, lng: plng));
    }

    return out;
  }
}
