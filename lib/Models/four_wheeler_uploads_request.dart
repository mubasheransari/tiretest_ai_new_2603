class FourWheelerUploadRequest {
  final String userId;
  final String token;

  final String vehicleId;
  final String vehicleType; // "Car" / "car" based on backend
  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  const FourWheelerUploadRequest({
    required this.userId,
    required this.token,
    required this.vehicleId,
    required this.vehicleType,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
  });
}
