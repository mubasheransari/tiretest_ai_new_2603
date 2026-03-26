// class TyreUploadRequest {
//   final String userId;
//   final String vehicleType; // "bike"
//   final String vehicleId;
//   final String frontPath;
//   final String backPath;
//   final String token;       // Bearer token
//   final String? vin;

//   const TyreUploadRequest({
//     required this.userId,
//     required this.vehicleType,
//     required this.vehicleId,
//     required this.frontPath,
//     required this.backPath,
//     required this.token,
//     this.vin,
//   });
// }
class TyreUploadRequest {
  final String token;
  final String userId;
  final String vehicleType;
  final String vehicleId;
  final String? vin;

  final String frontPath;
  final String backPath;

  // ✅ add these
  final String frontTyreId;
  final String backTyreId;

  TyreUploadRequest({
    required this.token,
    required this.userId,
    required this.vehicleType,
    required this.vehicleId,
    this.vin,
    required this.frontPath,
    required this.backPath,
    required this.frontTyreId,
    required this.backTyreId,
  });
}
