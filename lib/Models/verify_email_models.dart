class VerifyEmailRequest {
  final String email;
  const VerifyEmailRequest({required this.email});

  Map<String, dynamic> toJson() => {
        "email": email,
      };
}

class VerifyEmailResponse {
  final String userId;
  const VerifyEmailResponse({required this.userId});

  factory VerifyEmailResponse.fromJson(Map<String, dynamic> json) {
    return VerifyEmailResponse(
      userId: (json["userId"] ?? "").toString(),
    );
  }
}
