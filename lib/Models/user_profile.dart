import 'dart:convert';
import 'dart:convert';

class UserProfile {
  final String firstName;
  final String lastName;
  final String? phone;
  final String? profileImage;
  final String purpose;
  final String userId;
  final String email;
  final int loginCount;
  final int isSurveyShown;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profileImage,
    required this.purpose,
    required this.userId,
    required this.email,
    required this.loginCount,
    required this.isSurveyShown,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        firstName: j['firstName']?.toString() ?? '',
        lastName: j['lastName']?.toString() ?? '',
        phone: j['phone']?.toString(),
        profileImage: j['profileImage']?.toString(),
        purpose: j['purpose']?.toString() ?? '',
        userId: j['userId']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        loginCount: (j['loginCount'] is int)
            ? j['loginCount'] as int
            : int.tryParse(j['loginCount']?.toString() ?? '0') ?? 0,
        isSurveyShown: (j['isSurveyShown'] is int)
            ? j['isSurveyShown'] as int
            : int.tryParse(j['isSurveyShown']?.toString() ?? '0') ?? 0,
      );

  /// ✅ NEW: copyWith (needed for optimistic UI update)
  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? profileImage,
    String? purpose,
    String? userId,
    String? email,
    int? loginCount,
    int? isSurveyShown,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      purpose: purpose ?? this.purpose,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      loginCount: loginCount ?? this.loginCount,
      isSurveyShown: isSurveyShown ?? this.isSurveyShown,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'profileImage': profileImage,
        'purpose': purpose,
        'userId': userId,
        'email': email,
        'loginCount': loginCount,
        'isSurveyShown': isSurveyShown,
      };

  @override
  String toString() => jsonEncode(toJson());
}

// class UserProfile {
//   final String firstName;
//   final String lastName;
//   final String? phone;
//   final String? profileImage;
//   final String purpose;
//   final String userId;
//   final String email;
//   final int loginCount;
//   final int isSurveyShown;

//   const UserProfile({
//     required this.firstName,
//     required this.lastName,
//     required this.phone,
//     required this.profileImage,
//     required this.purpose,
//     required this.userId,
//     required this.email,
//     required this.loginCount,
//     required this.isSurveyShown,
//   });

//   factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
//         firstName: j['firstName']?.toString() ?? '',
//         lastName: j['lastName']?.toString() ?? '',
//         phone: j['phone'] as String?,
//         profileImage: j['profileImage'] as String?,
//         purpose: j['purpose']?.toString() ?? '',
//         userId: j['userId']?.toString() ?? '',
//         email: j['email']?.toString() ?? '',
//         loginCount: (j['loginCount'] is int)
//             ? j['loginCount'] as int
//             : int.tryParse(j['loginCount']?.toString() ?? '0') ?? 0,
//         isSurveyShown: (j['isSurveyShown'] is int)
//             ? j['isSurveyShown'] as int
//             : int.tryParse(j['isSurveyShown']?.toString() ?? '0') ?? 0,
//       );

//   @override
//   String toString() => jsonEncode({
//         'firstName': firstName,
//         'lastName': lastName,
//         'phone': phone,
//         'profileImage': profileImage,
//         'purpose': purpose,
//         'userId': userId,
//         'email': email,
//         'loginCount': loginCount,
//         'isSurveyShown': isSurveyShown,
//       });
// }
