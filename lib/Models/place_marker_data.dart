import 'package:equatable/equatable.dart';

class PlaceMarkerData extends Equatable {
  final String id; // place_id
  final String name;
  final double lat;
  final double lng;

  const PlaceMarkerData({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
      };

  factory PlaceMarkerData.fromJson(Map<String, dynamic> j) => PlaceMarkerData(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Tyre shop').toString(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [id, name, lat, lng];
}