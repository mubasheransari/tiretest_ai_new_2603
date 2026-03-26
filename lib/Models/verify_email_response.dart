class VerifyEmailResponse {
  final String userId;

  const VerifyEmailResponse({required this.userId});

  factory VerifyEmailResponse.fromJson(Map<String, dynamic> json) {
    return VerifyEmailResponse(
      userId: (json['userId'] ?? '').toString(),
    );
  }
}
