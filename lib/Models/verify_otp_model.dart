import 'dart:convert';

VerifyOtpRequest verifyOtpRequestFromJson(String str) =>
    VerifyOtpRequest.fromJson(json.decode(str) as Map<String, dynamic>);

String verifyOtpRequestToJson(VerifyOtpRequest data) => json.encode(data.toJson());

class VerifyOtpRequest {
  final String email;
  final int otp;

  const VerifyOtpRequest({
    required this.email,
    required this.otp,
  });

  factory VerifyOtpRequest.fromJson(Map<String, dynamic> json) => VerifyOtpRequest(
        email: (json["email"] ?? "").toString(),
        otp: json["otp"] is int ? json["otp"] as int : int.tryParse(json["otp"].toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "email": email,
        "otp": otp,
      };
}

// ====================== RESPONSE ======================

VerifyOtpResponse verifyOtpResponseFromJson(String str) =>
    VerifyOtpResponse.fromJson(json.decode(str) as Map<String, dynamic>);

String verifyOtpResponseToJson(VerifyOtpResponse data) => json.encode(data.toJson());

class VerifyOtpResponse {
  final String token;
  final String message;

  const VerifyOtpResponse({
    required this.token,
    required this.message,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) => VerifyOtpResponse(
        token: (json["token"] ?? "").toString(),
        message: (json["message"] ?? "").toString(),
      );

  Map<String, dynamic> toJson() => {
        "token": token,
        "message": message,
      };

  bool get isValid => token.trim().isNotEmpty;
}
