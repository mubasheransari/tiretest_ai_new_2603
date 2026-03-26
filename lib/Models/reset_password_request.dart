class ResetPasswordRequest {
   String? oldPassword;
  final String userId;
  final String newPassword;
  final String confirmNewPassword;

   ResetPasswordRequest({
     this.oldPassword,
    required this.userId,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  Map<String, dynamic> toJson() => {
     "currentPassword": oldPassword,
        "userId": userId.trim(),
        "newPassword": newPassword,
        "confirmNewPassword": confirmNewPassword.trim(),
      };
}
