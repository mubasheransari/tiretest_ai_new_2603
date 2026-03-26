class VerifyOtpResponse {
  final String token;
  final String? message;

  const VerifyOtpResponse({required this.token, this.message});

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      token: (json["token"] ?? "").toString(),
      message: json["message"]?.toString(),
    );
  }

  bool get isValid => token.trim().isNotEmpty;
}
