import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:ios_tiretest_ai/models/ad_models.dart';
import 'package:ios_tiretest_ai/models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/models/auth_models.dart';
import 'package:ios_tiretest_ai/models/place_marker_data.dart';
import 'package:ios_tiretest_ai/models/reset_password_response.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart';
import 'package:ios_tiretest_ai/models/shop_vendor.dart' hide ShopVendorModel;
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_response.dart';
import 'package:ios_tiretest_ai/models/update_user_details_model.dart';
import 'package:ios_tiretest_ai/models/user_profile.dart';
import 'package:ios_tiretest_ai/models/notification_models.dart';
import 'package:ios_tiretest_ai/models/verify_email_response.dart';
import 'package:ios_tiretest_ai/models/verify_otp_model.dart';


enum PlacesStatus { initial, loading, success, failure }
enum HomeMapStatus { initial, preparing, ready, failure }
enum TwoWheelerStatus { idle, uploading, success, failure }
enum AdsStatus { initial, loading, success, failure }
enum LocationStatus { initial, loading, success, failure }
enum ForgotEmailStatus { initial, loading, success, failure }
enum ForgotResetStatus { initial, loading, success, failure }
enum VerifyOtpStatus { initial, verifying, success, failure }
enum AuthStatus { initial, loading, success, failure }
enum FourWheelerStatus { initial, uploading, success, failure }
enum ProfileStatus { initial, loading, success, failure }
enum AddVehiclePreferencesStatus { initial, loading, success, failure }
enum TyreHistoryStatus { initial, loading, success, failure }
enum ShopsStatus { initial, loading, success, failure }
enum UpdateProfileStatus { initial, loading, success, failure }
enum NotificationStatus { initial, loading, success, failure }

/// ✅ Existing
enum ChangePasswordStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  final PlacesStatus placesStatus;
final List<PlaceMarkerData> places;
final String? placesError;
final DateTime? placesFetchedAt;
    final LocationStatus locationStatus;
  final double? currentLat;
  final double? currentLng;
  final String? locationError;
  final HomeMapStatus homeMapStatus;
    final DateTime? shopsFetchedAt;
final double? homeLat;
final double? homeLng;
final String? homeMapError;
    final TwoWheelerStatus twoWheelerStatus;
  final TwoWheelerTyreUploadResponse? twoWheelerResponse;
  final String twoWheelerError;
  final AdsStatus adsStatus;
final List<AdItem> ads;
final AdItem? selectedAd;
final String? adsError;
  // =========================
  // ✅ OTP
  // =========================
  final VerifyOtpStatus verifyOtpStatus;
  final VerifyOtpResponse? verifyOtpResponse;
  final String? verifyOtpError;

  // expiry info
  final DateTime? otpIssuedAt;
  final int otpExpirySeconds;

  // =========================
  // ✅ Forgot Password (NEW)
  // =========================
  final ForgotEmailStatus forgotEmailStatus;
  final VerifyEmailResponse? verifyEmailResponse;
  final String? forgotEmailError;

  final ForgotResetStatus forgotResetStatus;
  final ResetPasswordResponse? forgotResetResponse;
  final String? forgotResetError;

  // =========================
  // ✅ Notifications
  // =========================
  final List<NotificationItem> notifications;
  final int notificationUnreadCount;
  final String? notificationError;
  final bool notificationListening;
  final NotificationStatus notificationStatus;
  final Set<String> notificationSeenIds;

  // =========================
  // ✅ Shops
  // =========================
  final ShopsStatus shopsStatus;
  final List<ShopVendorModel> shops;
  final String? shopsError;

  // =========================
  // ✅ Tyre history
  // =========================
  final TyreHistoryStatus tyreHistoryStatus;
  final String? tyreHistoryError;
  final Map<String, List<TyreRecord>> tyreRecordsByType;

  // =========================
  // ✅ Auth
  // =========================
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;
  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;
  final String? error;

  // =========================
  // ✅ Add vehicle preferences
  // =========================
  final AddVehiclePreferencesStatus addVehiclePreferencesStatus;
  final VehiclePreferencesModel? vehiclePreferencesModel;
  final String? errorMessageVehiclePreferences;

  // =========================
  // ✅ Uploads
  // =========================


  final FourWheelerStatus fourWheelerStatus;
  final ResponseFourWheeler? fourWheelerResponse;
  final String? fourWheelerError;

  // =========================
  // ✅ Profile
  // =========================
  final ProfileStatus profileStatus;
  final UserProfile? profile;

  final UpdateProfileStatus updateProfileStatus;
  final UpdateUserDetailsResponse? updateProfileResponse;
  final String? updateProfileError;

  // =========================
  // ✅ Change Password (Existing)
  // =========================
  final ChangePasswordStatus changePasswordStatus;
  final ResetPasswordResponse? changePasswordResponse;
  final String? changePasswordError;

  // =========================
  // ✅ Records list (your current screen usage)
  // =========================
  final List<TyreRecord> records;
  final String? recordsError;
  final String recordsVehicleType;

  const AuthState({
    this.placesStatus = PlacesStatus.initial,
this.places = const <PlaceMarkerData>[],
this.placesError,
this.placesFetchedAt,
    this.locationStatus = LocationStatus.initial,
    this.currentLat,
    this.currentLng,
    this.locationError,
    this.shopsFetchedAt,
      this.homeMapStatus = HomeMapStatus.initial,
  this.homeLat,
  this.homeLng,
  this.homeMapError,
       this.twoWheelerStatus = TwoWheelerStatus.idle,
    this.twoWheelerResponse,
    this.twoWheelerError = '',
      this.adsStatus = AdsStatus.initial,
  this.ads = const <AdItem>[],
  this.selectedAd,
  this.adsError,
    // OTP
    this.verifyOtpStatus = VerifyOtpStatus.initial,
    this.verifyOtpResponse,
    this.verifyOtpError,
    this.otpIssuedAt,
    this.otpExpirySeconds = 600,

    // Forgot Password (NEW)
    this.forgotEmailStatus = ForgotEmailStatus.initial,
    this.verifyEmailResponse,
    this.forgotEmailError,
    this.forgotResetStatus = ForgotResetStatus.initial,
    this.forgotResetResponse,
    this.forgotResetError,

    // Notifications
    this.notifications = const <NotificationItem>[],
    this.notificationUnreadCount = 0,
    this.notificationError,
    this.notificationListening = false,
    this.notificationStatus = NotificationStatus.initial,
    this.notificationSeenIds = const <String>{},

    // Shops
    this.shopsStatus = ShopsStatus.initial,
    this.shops = const <ShopVendorModel>[],
    this.shopsError,

    // Tyre history
    this.tyreHistoryStatus = TyreHistoryStatus.initial,
    this.tyreHistoryError,
    this.tyreRecordsByType = const {},

    // Auth
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.error,

    // Vehicle preferences
    this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
    this.vehiclePreferencesModel,
    this.errorMessageVehiclePreferences,


    this.fourWheelerStatus = FourWheelerStatus.initial,
    this.fourWheelerResponse,
    this.fourWheelerError,

    // Profile
    this.profileStatus = ProfileStatus.initial,
    this.profile,
    this.updateProfileStatus = UpdateProfileStatus.initial,
    this.updateProfileResponse,
    this.updateProfileError,

    // Change password (existing)
    this.changePasswordStatus = ChangePasswordStatus.initial,
    this.changePasswordResponse,
    this.changePasswordError,

    // Records
    this.records = const [],
    this.recordsError,
    this.recordsVehicleType = 'car',
  });

  

  List<TyreRecord> get carRecords =>
      tyreRecordsByType['car'] ?? const <TyreRecord>[];
  List<TyreRecord> get bikeRecords =>
      tyreRecordsByType['bike'] ?? const <TyreRecord>[];

  List<TyreRecord> get allTyreRecords {
    final combined = <TyreRecord>[...carRecords, ...bikeRecords];
    combined.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return combined;
  }

  AuthState copyWith({
    PlacesStatus? placesStatus,
List<PlaceMarkerData>? places,
String? placesError,
DateTime? placesFetchedAt,
        LocationStatus? locationStatus,
    double? currentLat,
    double? currentLng,
    String? locationError,
    DateTime? shopsFetchedAt,
      HomeMapStatus? homeMapStatus,
  double? homeLat,
  double? homeLng,
  String? homeMapError,
        TwoWheelerStatus? twoWheelerStatus,
    TwoWheelerTyreUploadResponse? twoWheelerResponse,
    String? twoWheelerError,
      AdsStatus? adsStatus,
  List<AdItem>? ads,
  AdItem? selectedAd,
  String? adsError,
    // OTP
    VerifyOtpStatus? verifyOtpStatus,
    VerifyOtpResponse? verifyOtpResponse,
    String? verifyOtpError,
    DateTime? otpIssuedAt,
    int? otpExpirySeconds,

    // Forgot password (NEW)
    ForgotEmailStatus? forgotEmailStatus,
    VerifyEmailResponse? verifyEmailResponse,
    String? forgotEmailError,
    ForgotResetStatus? forgotResetStatus,
    ResetPasswordResponse? forgotResetResponse,
    String? forgotResetError,

    // Notifications
    List<NotificationItem>? notifications,
    int? notificationUnreadCount,
    String? notificationError,
    bool? notificationListening,
    NotificationStatus? notificationStatus,
    Set<String>? notificationSeenIds,

    // Shops
    ShopsStatus? shopsStatus,
    List<ShopVendorModel>? shops,
    String? shopsError,

    // Tyre history
    TyreHistoryStatus? tyreHistoryStatus,
    String? tyreHistoryError,
    Map<String, List<TyreRecord>>? tyreRecordsByType,

    // Auth
    AuthStatus? loginStatus,
    AuthStatus? signupStatus,
    LoginResponse? loginResponse,
    SignupResponse? signupResponse,
    String? error,

    // Vehicle pref
    AddVehiclePreferencesStatus? addVehiclePreferencesStatus,
    VehiclePreferencesModel? vehiclePreferencesModel,
    String? errorMessageVehiclePreferences,

    // Uploads


    FourWheelerStatus? fourWheelerStatus,
    ResponseFourWheeler? fourWheelerResponse,
    String? fourWheelerError,

    // Profile
    ProfileStatus? profileStatus,
    UserProfile? profile,

    UpdateProfileStatus? updateProfileStatus,
    UpdateUserDetailsResponse? updateProfileResponse,
    String? updateProfileError,

    // Change password
    ChangePasswordStatus? changePasswordStatus,
    ResetPasswordResponse? changePasswordResponse,
    String? changePasswordError,

    // Records
    List<TyreRecord>? records,
    String? recordsError,
    String? recordsVehicleType,
  }) {
    return AuthState(
      placesStatus: placesStatus ?? this.placesStatus,
places: places ?? this.places,
placesError: placesError ?? this.placesError,
placesFetchedAt: placesFetchedAt ?? this.placesFetchedAt,
            locationStatus: locationStatus ?? this.locationStatus,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      locationError: locationError ?? this.locationError,
      shopsFetchedAt: shopsFetchedAt ?? this.shopsFetchedAt,
    homeMapStatus: homeMapStatus ?? this.homeMapStatus,
    homeLat: homeLat ?? this.homeLat,
    homeLng: homeLng ?? this.homeLng,
    homeMapError: homeMapError ?? this.homeMapError,
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
      twoWheelerError: twoWheelerError ?? this.twoWheelerError,
          adsStatus: adsStatus ?? this.adsStatus,
    ads: ads ?? this.ads,
    selectedAd: selectedAd ?? this.selectedAd,
    adsError: adsError ?? this.adsError,
      // OTP
      verifyOtpStatus: verifyOtpStatus ?? this.verifyOtpStatus,
      verifyOtpResponse: verifyOtpResponse ?? this.verifyOtpResponse,
      verifyOtpError: verifyOtpError ?? this.verifyOtpError,
      otpIssuedAt: otpIssuedAt ?? this.otpIssuedAt,
      otpExpirySeconds: otpExpirySeconds ?? this.otpExpirySeconds,

      // Forgot password (NEW)
      forgotEmailStatus: forgotEmailStatus ?? this.forgotEmailStatus,
      verifyEmailResponse: verifyEmailResponse ?? this.verifyEmailResponse,
      forgotEmailError: forgotEmailError ?? this.forgotEmailError,
      forgotResetStatus: forgotResetStatus ?? this.forgotResetStatus,
      forgotResetResponse: forgotResetResponse ?? this.forgotResetResponse,
      forgotResetError: forgotResetError ?? this.forgotResetError,

      // Notifications
      notifications: notifications ?? this.notifications,
      notificationUnreadCount:
          notificationUnreadCount ?? this.notificationUnreadCount,
      notificationError: notificationError ?? this.notificationError,
      notificationListening:
          notificationListening ?? this.notificationListening,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      notificationSeenIds: notificationSeenIds ?? this.notificationSeenIds,

      // Shops
      shopsStatus: shopsStatus ?? this.shopsStatus,
      shops: shops ?? this.shops,
      shopsError: shopsError ?? this.shopsError,

      // Tyre history
      tyreHistoryStatus: tyreHistoryStatus ?? this.tyreHistoryStatus,
      tyreHistoryError: tyreHistoryError ?? this.tyreHistoryError,
      tyreRecordsByType: tyreRecordsByType ?? this.tyreRecordsByType,

      // Auth
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error ?? this.error,

      // Vehicle pref
      addVehiclePreferencesStatus:
          addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
      vehiclePreferencesModel:
          vehiclePreferencesModel ?? this.vehiclePreferencesModel,
      errorMessageVehiclePreferences:
          errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,

      // Uploads
  
      fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
      fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
      fourWheelerError: fourWheelerError ?? this.fourWheelerError,

      // Profile
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
      updateProfileStatus: updateProfileStatus ?? this.updateProfileStatus,
      updateProfileResponse:
          updateProfileResponse ?? this.updateProfileResponse,
      updateProfileError: updateProfileError ?? this.updateProfileError,

      // Change password
      changePasswordStatus:
          changePasswordStatus ?? this.changePasswordStatus,
      changePasswordResponse:
          changePasswordResponse ?? this.changePasswordResponse,
      changePasswordError: changePasswordError ?? this.changePasswordError,

      // Records
      records: records ?? this.records,
      recordsError: recordsError ?? this.recordsError,
      recordsVehicleType: recordsVehicleType ?? this.recordsVehicleType,
    );
  }

  @override
  List<Object?> get props => [
    placesStatus,
places,
placesError,
placesFetchedAt,
           locationStatus,
        currentLat,
        currentLng,
        locationError,
        shopsFetchedAt,
      homeMapStatus,
  homeLat,
  homeLng,
  homeMapError,
            twoWheelerStatus,
        twoWheelerResponse,
        twoWheelerError,
      adsStatus,
  ads,
  selectedAd,
  adsError,
        // Notifications
        notifications,
        notificationUnreadCount,
        notificationError,
        notificationListening,
        notificationStatus,
        notificationSeenIds,

        // OTP
        verifyOtpStatus,
        verifyOtpResponse,
        verifyOtpError,
        otpIssuedAt,
        otpExpirySeconds,

        // Forgot password (NEW)
        forgotEmailStatus,
        verifyEmailResponse,
        forgotEmailError,
        forgotResetStatus,
        forgotResetResponse,
        forgotResetError,

        // Shops
        shopsStatus,
        shops,
        shopsError,

        // Tyre history
        tyreHistoryStatus,
        tyreHistoryError,
        tyreRecordsByType,

        // Auth
        loginStatus,
        signupStatus,
        loginResponse,
        signupResponse,
        error,

        // Vehicle pref
        addVehiclePreferencesStatus,
        vehiclePreferencesModel,
        errorMessageVehiclePreferences,

        // Uploads
        twoWheelerStatus,
        twoWheelerResponse,
        fourWheelerStatus,
        fourWheelerResponse,
        fourWheelerError,

        // Profile
        profileStatus,
        profile,
        updateProfileStatus,
        updateProfileResponse,
        updateProfileError,

        // Change password
        changePasswordStatus,
        changePasswordResponse,
        changePasswordError,

        // Records
        records,
        recordsError,
        recordsVehicleType,
      ];
}

