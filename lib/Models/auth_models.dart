class LoginRequest {
  final String email;
  final String password;
  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class LoginResponse {
  final String token;
  final String? purpose;
  final String? message;

  LoginResponse({required this.token, this.purpose, this.message});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: (json['token'] ?? '').toString(),
        purpose: json['purpose']?.toString(),
        message: json['message']?.toString(),
      );

  bool get isValid => token.isNotEmpty;
}

// ===== SIGNUP =====
class SignupRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  SignupRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
      };
}

class SignupData {
  final String userId;
  final String email;
  final String? purpose;

  SignupData({required this.userId, required this.email, this.purpose});

  factory SignupData.fromJson(Map<String, dynamic> json) => SignupData(
        userId: (json['userId'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        purpose: json['purpose']?.toString(),
      );
}

class SignupResponse {
  final String? message;
  final SignupData? data;

  SignupResponse({this.message, this.data});

  factory SignupResponse.fromJson(Map<String, dynamic> json) => SignupResponse(
        message: json['message']?.toString(),
        data: (json['data'] is Map<String, dynamic>)
            ? SignupData.fromJson(json['data'])
            : null,
      );

  bool get isValid => data != null && data!.userId.isNotEmpty;
}
