import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {
  const AppStarted();
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class SignupRequested extends AuthEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  const SignupRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [firstName, lastName, email, password];
}


class UploadFourWheelerRequested extends AuthEvent {
  final String vehicleId;
  final String vehicleType;
  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  const UploadFourWheelerRequested({
    required this.vehicleId,
    this.vehicleType = 'car',
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
  });

  @override
  List<Object?> get props => [
        vehicleId,
        vehicleType,
        vin,
        frontLeftTyreId,
        frontRightTyreId,
        backLeftTyreId,
        backRightTyreId,
        frontLeftPath,
        frontRightPath,
        backLeftPath,
        backRightPath,
      ];
}

class ClearAuthError extends AuthEvent {
  const ClearAuthError();
}

class FetchProfileRequested extends AuthEvent {
  final String? token;
  const FetchProfileRequested({this.token});
  @override
  List<Object?> get props => [token];
}

class AddVehiclePreferenccesEvent extends AuthEvent {
  final String vehiclePreference;
  final String brandName;
  final String modelName;
  final String licensePlate;
  final bool? isOwn;
  final String tireBrand;
  final String tireDimension;

  const AddVehiclePreferenccesEvent({
    required this.vehiclePreference,
    required this.brandName,
    required this.modelName,
    required this.licensePlate,
    required this.isOwn,
    required this.tireBrand,
    required this.tireDimension,
  });

  @override
  List<Object?> get props => [
        vehiclePreference,
        brandName,
        modelName,
        licensePlate,
        isOwn,
        tireBrand,
        tireDimension,
      ];
}
class FetchNearbyShopsRequested extends AuthEvent {
  final double latitude;
  final double longitude;

  // ✅ NEW: if silent, don’t flip UI loading states
  final bool silent;

  const FetchNearbyShopsRequested({
    required this.latitude,
    required this.longitude,
    this.silent = false,
  });

  @override
  List<Object?> get props => [latitude, longitude, silent];
}
class FetchTyreHistoryRequested extends AuthEvent {
  final String userId;
  final String vehicleId; // default ALL

  const FetchTyreHistoryRequested({
    required this.userId,
    this.vehicleId = "ALL",
  });

  @override
  List<Object?> get props => [userId, vehicleId];
}

class UpdateUserDetailsRequested extends AuthEvent {
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String profileImage; 

  const UpdateUserDetailsRequested({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profileImage,
  });

  @override
  List<Object?> get props => [email,firstName, lastName, phone, profileImage];
}

/// ✅ Optional: clear update profile error
class ClearUpdateProfileError extends AuthEvent {
  const ClearUpdateProfileError();
}
class ChangePasswordRequested extends AuthEvent {
  final String oldPassword;
  final String newPassword;
  final String confirmNewPassword;

  const ChangePasswordRequested({
     required this.oldPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  @override
  List<Object?> get props => [oldPassword,newPassword, confirmNewPassword];
}

class ClearChangePasswordError extends AuthEvent {
  const ClearChangePasswordError();
}



class NotificationFetchRequested extends AuthEvent {
  const NotificationFetchRequested({
    this.page = 1,
    this.limit = 4,
    this.silent = false,
  });

  final int page;
  final int limit;
  final bool silent;

  @override
  List<Object?> get props => [page, limit, silent];
}

class NotificationStartListening extends AuthEvent {
  const NotificationStartListening({this.intervalSeconds = 15});
  final int intervalSeconds;

  @override
  List<Object?> get props => [intervalSeconds];
}

class NotificationStopListening extends AuthEvent {
  const NotificationStopListening();
}

class NotificationMarkAllRead extends AuthEvent {
  const NotificationMarkAllRead();
}

class NotificationMarkSeenByIds extends AuthEvent {
  const NotificationMarkSeenByIds(this.ids);
  final List<String> ids;

  @override
  List<Object?> get props => [ids];
}


class VerifyOtpRequested extends AuthEvent {
  final String email;
  final int otp;
  final String? token; // optional if needed

  const VerifyOtpRequested({
    required this.email,
    required this.otp,
    this.token,
  });

  @override
  List<Object?> get props => [email, otp, token];
}

// class OtpIssuedNow extends AuthEvent {
//   const OtpIssuedNow();
// }

class OtpIssuedNow extends AuthEvent {
  final String email;
  const OtpIssuedNow({required this.email});

  @override
  List<Object?> get props => [email];
}

class ForgotPasswordVerifyEmailRequested extends AuthEvent {
  final String email;
  const ForgotPasswordVerifyEmailRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

/// ✅ Step-2: Reset Password using userId
class ForgotPasswordResetRequested extends AuthEvent {
  final String userId;
  final String newPassword;
  final String confirmPassword;

  const ForgotPasswordResetRequested({
    required this.userId,
    required this.newPassword,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [userId, newPassword, confirmPassword];
}

/// ✅ Clear forgot states (optional but recommended)
class ForgotPasswordClearRequested extends AuthEvent {
  const ForgotPasswordClearRequested();
}


class AdsFetchRequested extends AuthEvent {
  final bool silent;
  final String? token;
  const AdsFetchRequested({this.silent = false, this.token});

  @override
  List<Object?> get props => [silent, token];
}

class AdsSelectRequested extends AuthEvent {
  final String adId; // choose which ad to play (optional)
  const AdsSelectRequested(this.adId);

  @override
  List<Object?> get props => [adId];
}


class UploadTwoWheelerRequested extends AuthEvent {
  final String userId;
  final String vehicleId;
  final String vehicleType;
  final String token;
  final String? vin;

  final String frontPath;
  final String backPath;

  // ✅ NEW
  final String frontTyreId;
  final String backTyreId;

  const UploadTwoWheelerRequested({
    required this.userId,
    required this.vehicleId,
    required this.vehicleType,
    required this.token,
    this.vin,
    required this.frontPath,
    required this.backPath,

    // ✅ REQUIRED
    required this.frontTyreId,
    required this.backTyreId,
  });

  @override
  List<Object?> get props => [
        userId,
        vehicleId,
        vehicleType,
        token,
        vin,
        frontPath,
        backPath,
        frontTyreId,
        backTyreId,
      ];
}
class HomeMapBootRequested extends AuthEvent {
  final bool forceRefresh; // if true skip cache
  const HomeMapBootRequested({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}


class CurrentLocationRequested extends AuthEvent {
  final bool force; // re-fetch even if already exists
  const CurrentLocationRequested({this.force = false});

  @override
  List<Object?> get props => [force];
}

// Optional: if you want manual refresh of shops without forcing GPS again
class NearbyShopsRefreshRequested extends AuthEvent {
  const NearbyShopsRefreshRequested();
}


class FetchNearbyPlacesRequested extends AuthEvent {
  final double latitude;
  final double longitude;

  /// silent=true means do not disturb other UI flows
  final bool silent;

  /// force=true ignores cache and refetches
  final bool force;

  const FetchNearbyPlacesRequested({
    required this.latitude,
    required this.longitude,
    this.silent = true,
    this.force = false,
  });

  @override
  List<Object?> get props => [latitude, longitude, silent, force];
}

class PlacesPrewarmRequested extends AuthEvent {
  const PlacesPrewarmRequested();

  @override
  List<Object?> get props => [];
}