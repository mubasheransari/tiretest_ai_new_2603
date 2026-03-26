class ResetPasswordRequest {
  final String userId;
  final String newPassword;
  final String confirmNewPassword;

  const ResetPasswordRequest({
    required this.userId,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  Map<String, dynamic> toJson() => {
        "newPassword": newPassword,
        "confirmNewPassword": confirmNewPassword,
        "userId": userId,
      };
}

class ResetPasswordResponse {
  final String message;
  const ResetPasswordResponse({required this.message});

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      message: (json["message"] ?? "Password updated successfully").toString(),
    );
  }
}
