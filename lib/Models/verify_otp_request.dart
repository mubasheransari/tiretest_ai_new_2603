class VerifyOtpRequest {
  final String email;
  final String otp; // keep as string to avoid int issues

  const VerifyOtpRequest({
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
        "email": email.trim(),
        "otp": otp.trim(),
      };
}
