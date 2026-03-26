class ResetPasswordResponse {
  final String? message;
  final String? error;

  const ResetPasswordResponse({
    this.message,
    this.error,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      message: json['message']?.toString(),
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'error': error,
      };
}
