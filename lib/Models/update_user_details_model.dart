class UpdateUserDetailsRequest {
  final String email;
  final String firstName;
  final String lastName;
  final String profileImage;
  final String phone;

  const UpdateUserDetailsRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.profileImage,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
     "email": email,
        "firstName": firstName,
        "lastName": lastName,
        "profileImage": profileImage,
        "phone": phone,
      };
}

class UpdateUserDetailsResponse {
  final String message;

  const UpdateUserDetailsResponse({required this.message});

  factory UpdateUserDetailsResponse.fromJson(Map<String, dynamic> json) {
    return UpdateUserDetailsResponse(
      message: (json["message"] ?? "").toString(),
    );
  }
}
