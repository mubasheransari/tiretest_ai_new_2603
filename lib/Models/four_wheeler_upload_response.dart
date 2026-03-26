class FourWheelerUploadResponse {
  final Map<String, dynamic> data;
  final String? message;

  const FourWheelerUploadResponse({
    required this.data,
    this.message,
  });

  factory FourWheelerUploadResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return FourWheelerUploadResponse(
      data: rawData is Map<String, dynamic> ? rawData : <String, dynamic>{},
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        "data": data,
        "message": message,
      };
}
