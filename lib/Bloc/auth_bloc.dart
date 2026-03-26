import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Data/places_service.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:ios_tiretest_ai/models/ad_models.dart';
import 'package:ios_tiretest_ai/models/four_wheeler_uploads_request.dart';
import 'package:ios_tiretest_ai/models/notification_models.dart';
import 'package:ios_tiretest_ai/models/place_marker_data.dart';
import 'package:ios_tiretest_ai/models/reset_password_request.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart';
import 'package:ios_tiretest_ai/Repository/repository.dart';
import 'package:ios_tiretest_ai/models/update_user_details_model.dart' show UpdateUserDetailsRequest;
import 'package:ios_tiretest_ai/models/user_profile.dart';
import 'package:ios_tiretest_ai/models/verify_otp_model.dart';
import 'package:ios_tiretest_ai/utils/location_helper.dart';
import '../models/auth_models.dart';
import 'package:bloc/bloc.dart';
import 'dart:async';



class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repo) : super(const AuthState()) {
    on<PlacesPrewarmRequested>(_onPlacesPrewarmRequested);
on<FetchNearbyPlacesRequested>(_onFetchNearbyPlacesRequested);
        on<CurrentLocationRequested>(_onCurrentLocationRequested);
    on<NearbyShopsRefreshRequested>(_onNearbyShopsRefreshRequested);
    on<HomeMapBootRequested>(_onHomeMapBootRequested);
    on<AdsFetchRequested>(_onAdsFetch);
on<AdsSelectRequested>(_onAdsSelect);
    // ✅ OTP
    on<OtpIssuedNow>(_onOtpIssuedNow);
    on<VerifyOtpRequested>(_onVerifyOtp);

    // ✅ Forgot Password
    on<ForgotPasswordVerifyEmailRequested>(_onForgotVerifyEmail);
    on<ForgotPasswordResetRequested>(_onForgotResetPassword);
    on<ForgotPasswordClearRequested>(_onClearForgot);

    // ✅ Notifications
    on<NotificationFetchRequested>(_onNotificationFetch);
    on<NotificationStartListening>(_onNotificationStart);
    on<NotificationStopListening>(_onNotificationStop);
    on<NotificationMarkAllRead>(_onNotificationMarkAllRead);
    on<NotificationMarkSeenByIds>(_onNotificationMarkSeenByIds);

    // ✅ App/Auth
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<ClearAuthError>((e, emit) => emit(state.copyWith(error: null)));


   on<UploadTwoWheelerRequested>(_onUploadTwoWheeler);

    on<UploadFourWheelerRequested>(_onFourWheelerUpload);

    // ✅ Profile
    on<FetchProfileRequested>(_onFetchProfile);
    on<FetchTyreHistoryRequested>(_onFetchTyreHistory);
    on<FetchNearbyShopsRequested>(_onFetchNearbyShops);

    // ✅ Vehicle Pref
    on<AddVehiclePreferenccesEvent>(addVehiclePreferences);

    // ✅ Update profile
    on<UpdateUserDetailsRequested>(_onUpdateUserDetails);
    on<ClearUpdateProfileError>(
      (e, emit) => emit(state.copyWith(updateProfileError: null)),
    );

    // ✅ Change password (existing flow using resetPassword)
    on<ChangePasswordRequested>(_onChangePassword);
    on<ClearChangePasswordError>(
      (e, emit) => emit(state.copyWith(changePasswordError: null)),
    );
  }
  static const _kHomeLat = "home_last_lat";
static const _kHomeLng = "home_last_lng";
static const _kHomeLocTs = "home_last_loc_ts"; // millis
Map<String, double>? _readCachedHomeLoc() {
  final box = GetStorage();
  final lat = box.read(_kHomeLat);
  final lng = box.read(_kHomeLng);

  if (lat is num && lng is num) {
    return {"lat": lat.toDouble(), "lng": lng.toDouble()};
  }
  return null;
}

Future<void> _saveCachedHomeLoc(double lat, double lng) async {
  final box = GetStorage();
  await box.write(_kHomeLat, lat);
  await box.write(_kHomeLng, lng);
  await box.write(_kHomeLocTs, DateTime.now().millisecondsSinceEpoch);
}

  final AuthRepository repo;

  static const _kPlacesCache = "places_cache";
static const _kPlacesCacheLat = "places_cache_lat";
static const _kPlacesCacheLng = "places_cache_lng";
static const _kPlacesCacheTs = "places_cache_ts";

// NOTE: move your key to env later. For now using same key.
static const String _googlePlacesApiKey = 'AIzaSyClBCaZYLuCKg0fT9xsSYpFOJ8sKegE350';

final _placesSvc = PlacesService(apiKey: _googlePlacesApiKey);

int _placesRequestSerial = 0;
bool _placesFetchInFlight = false;
double? _lastPlacesRequestLat;
double? _lastPlacesRequestLng;
DateTime? _lastPlacesRequestAt;
 
  static const _kNotifReadIds = "notif_read_ids"; 

  Timer? _notifTimer;

  Future<void> _onFetchNearbyPlacesRequested(
  FetchNearbyPlacesRequested e,
  Emitter<AuthState> emit,
) async {
  final box = GetStorage();
  final now = DateTime.now();

  bool isNear(double aLat, double aLng, double bLat, double bLng) {
    return Geolocator.distanceBetween(aLat, aLng, bLat, bLng) <= 2500;
  }

  final recentSameRequest =
      !e.force &&
      _placesFetchInFlight &&
      _lastPlacesRequestLat != null &&
      _lastPlacesRequestLng != null &&
      _lastPlacesRequestAt != null &&
      isNear(e.latitude, e.longitude, _lastPlacesRequestLat!, _lastPlacesRequestLng!) &&
      now.difference(_lastPlacesRequestAt!).inSeconds < 8;

  if (recentSameRequest) {
    return;
  }

  _placesFetchInFlight = true;
  _lastPlacesRequestLat = e.latitude;
  _lastPlacesRequestLng = e.longitude;
  _lastPlacesRequestAt = now;
  final requestSerial = ++_placesRequestSerial;

  if (!e.force &&
      state.places.isNotEmpty &&
      state.placesFetchedAt != null &&
      now.difference(state.placesFetchedAt!).inMinutes < 10) {
    final first = state.places.first;
    if (isNear(e.latitude, e.longitude, first.lat, first.lng)) {
      _placesFetchInFlight = false;
      return;
    }
  }

  List<PlaceMarkerData> cached = const <PlaceMarkerData>[];
  if (!e.force) {
    try {
      final raw = box.read(_kPlacesCache);
      final cacheLat = (box.read(_kPlacesCacheLat) as num?)?.toDouble();
      final cacheLng = (box.read(_kPlacesCacheLng) as num?)?.toDouble();
      final cacheTs = (box.read(_kPlacesCacheTs) as num?)?.toInt();

      final freshEnough = cacheTs != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(cacheTs)).inHours < 24;
      final nearEnough = cacheLat != null &&
          cacheLng != null &&
          isNear(e.latitude, e.longitude, cacheLat, cacheLng);

      if (freshEnough && nearEnough && raw is List && raw.isNotEmpty) {
        cached = raw
            .whereType<Map>()
            .map((x) => PlaceMarkerData.fromJson(Map<String, dynamic>.from(x)))
            .toList();

        if (cached.isNotEmpty) {
          emit(state.copyWith(
            placesStatus: PlacesStatus.success,
            places: cached,
            placesError: null,
            placesFetchedAt: now,
          ));
        }
      }
    } catch (_) {}
  }

  final shouldShowLoading = !e.silent && state.places.isEmpty && cached.isEmpty;
  if (shouldShowLoading) {
    emit(state.copyWith(
      placesStatus: PlacesStatus.loading,
      placesError: null,
    ));
  }

  try {
    var list = await _placesSvc.fetchAll(lat: e.latitude, lng: e.longitude);

    if (list.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 700));
      list = await _placesSvc.fetchAll(lat: e.latitude, lng: e.longitude);
    }

    if (requestSerial != _placesRequestSerial) {
      return;
    }

    if (list.isNotEmpty) {
      try {
        await box.write(_kPlacesCache, list.map((p) => p.toJson()).toList());
        await box.write(_kPlacesCacheLat, e.latitude);
        await box.write(_kPlacesCacheLng, e.longitude);
        await box.write(_kPlacesCacheTs, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}

      emit(state.copyWith(
        placesStatus: PlacesStatus.success,
        places: list,
        placesError: null,
        placesFetchedAt: DateTime.now(),
      ));
    } else if (cached.isNotEmpty || state.places.isNotEmpty) {
      emit(state.copyWith(
        placesStatus: PlacesStatus.success,
        places: cached.isNotEmpty ? cached : state.places,
        placesError: null,
        placesFetchedAt: DateTime.now(),
      ));
    } else {
      emit(state.copyWith(
        placesStatus: PlacesStatus.failure,
        placesError: 'No nearby Google Places shops found for this area.',
      ));
    }
  } catch (ex) {
    if (requestSerial != _placesRequestSerial) {
      return;
    }

    emit(state.copyWith(
      placesStatus: (cached.isNotEmpty || state.places.isNotEmpty)
          ? PlacesStatus.success
          : PlacesStatus.failure,
      places: cached.isNotEmpty ? cached : state.places,
      placesError: (cached.isNotEmpty || state.places.isNotEmpty) ? null : ex.toString(),
      placesFetchedAt: (cached.isNotEmpty || state.places.isNotEmpty)
          ? DateTime.now()
          : state.placesFetchedAt,
    ));
  } finally {
    if (requestSerial == _placesRequestSerial) {
      _placesFetchInFlight = false;
    }
  }
}


Future<void> _onPlacesPrewarmRequested(
  PlacesPrewarmRequested e,
  Emitter<AuthState> emit,
) async {
  // 1) Try cached HOME location from your HomeMapBoot flow
  final lat = state.homeLat ?? state.currentLat;
  final lng = state.homeLng ?? state.currentLng;

  // 2) If still null, try GetStorage last saved
  double? useLat = lat;
  double? useLng = lng;

  final box = GetStorage();
  useLat ??= (box.read(_kHomeLat) as num?)?.toDouble();
  useLng ??= (box.read(_kHomeLng) as num?)?.toDouble();

  if (useLat == null || useLng == null) return;

  // fire silently
  add(FetchNearbyPlacesRequested(
    latitude: useLat,
    longitude: useLng,
    silent: true,
    force: false,
  ));
}

  Future<void> _onHomeMapBootRequested(
  HomeMapBootRequested e,
  Emitter<AuthState> emit,
) async {
  emit(state.copyWith(
    homeMapStatus: HomeMapStatus.preparing,
    homeMapError: null,
  ));

  // 1) ✅ instant: use cached lat/lng if present (unless forceRefresh)
  if (!e.forceRefresh) {
    final cached = _readCachedHomeLoc();
    if (cached != null) {
      final lat = cached["lat"]!;
      final lng = cached["lng"]!;

      emit(state.copyWith(
        homeMapStatus: HomeMapStatus.ready,
        homeLat: lat,
        homeLng: lng,
        homeMapError: null,
      ));

      // ✅ Fetch markers immediately WITHOUT changing UI to loading
      add(FetchNearbyShopsRequested(
        latitude: lat,
        longitude: lng,
        silent: true,
      ));
    }
  }

  // 2) ✅ background: last known position (fast)
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final lat = last.latitude;
      final lng = last.longitude;

      // update state if not set yet
      if (state.homeLat == null || state.homeLng == null) {
        emit(state.copyWith(
          homeMapStatus: HomeMapStatus.ready,
          homeLat: lat,
          homeLng: lng,
          homeMapError: null,
        ));
        add(FetchNearbyShopsRequested(
          latitude: lat,
          longitude: lng,
          silent: true,
        ));
      }

      await _saveCachedHomeLoc(lat, lng);
    }
  } catch (_) {}

  // 3) ✅ background: current GPS (accurate but slower) with timeout
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    final p = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 8),
    );

    final lat = p.latitude;
    final lng = p.longitude;

    // only update if changed enough (avoid spam)
    final oldLat = state.homeLat;
    final oldLng = state.homeLng;

    final changed = oldLat == null ||
        oldLng == null ||
        (oldLat - lat).abs() > 0.0003 ||
        (oldLng - lng).abs() > 0.0003;

    if (changed) {
      emit(state.copyWith(
        homeMapStatus: HomeMapStatus.ready,
        homeLat: lat,
        homeLng: lng,
        homeMapError: null,
      ));

      await _saveCachedHomeLoc(lat, lng);

      // ✅ refresh markers silently
      add(FetchNearbyShopsRequested(
        latitude: lat,
        longitude: lng,
        silent: true,
      ));
    }
  } catch (_) {
    // If we already had cached/last-known, don’t mark failure.
    if (state.homeLat == null || state.homeLng == null) {
      emit(state.copyWith(
        homeMapStatus: HomeMapStatus.failure,
        homeMapError: "Failed to get location",
      ));
    }
  }
}

  Set<String> _readIds() {
    final box = GetStorage();
    final raw = box.read(_kNotifReadIds);
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    return <String>{};
  }

  Future<void> _writeReadIds(Set<String> ids) async {
    final box = GetStorage();
    await box.write(_kNotifReadIds, ids.toList());
  }

  int _computeUnread(List<NotificationItem> list, Set<String> readIds) {
    return list.where((n) => !readIds.contains(n.id)).length;
  }

  Future<void> _onUploadTwoWheeler(
  UploadTwoWheelerRequested e,
  Emitter<AuthState> emit,
) async {
  if (state.twoWheelerStatus == TwoWheelerStatus.uploading) return;

  final box = GetStorage();

  // ✅ same token handling style (auth_token first, then token)
  final token =
      (box.read<String>('auth_token') ?? box.read<String>('token') ?? '').trim();

  if (token.isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'Missing auth token. Please log in again.',
    ));
    return;
  }

  // ✅ get userId from profile (single source of truth)
  final userId = (state.profile?.userId?.toString() ?? '').trim();
  if (userId.isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'User profile not loaded. Please login again.',
    ));
    return;
  }

  // ✅ required fields
  if (e.vehicleId.trim().isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'Missing vehicle_id.',
    ));
    return;
  }

  if (e.frontPath.trim().isEmpty || e.backPath.trim().isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'Missing front/back tyre images.',
    ));
    return;
  }

  // ✅ REQUIRED: tyre ids must come from preferences response
  if (e.frontTyreId.trim().isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'Missing front_tyre_id. Save preferences again.',
    ));
    return;
  }

  if (e.backTyreId.trim().isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: 'Missing back_tyre_id. Save preferences again.',
    ));
    return;
  }

  emit(state.copyWith(
    twoWheelerStatus: TwoWheelerStatus.uploading,
    twoWheelerError: '',
  ));

  final req = TyreUploadRequest(
    token: token,
    userId: userId,
    vehicleType: (e.vehicleType.trim().isEmpty ? 'bike' : e.vehicleType.trim()),
    vehicleId: e.vehicleId.trim(),
    vin: (e.vin ?? '').trim().isEmpty ? null : e.vin!.trim(),
    frontPath: e.frontPath.trim(),
    backPath: e.backPath.trim(),

    // ✅ REQUIRED
    frontTyreId: e.frontTyreId.trim(),
    backTyreId: e.backTyreId.trim(),
  );

  final result = await repo.uploadTwoWheeler(req);

  if (result.isSuccess) {
    final resp = result.data;

    // ✅ NEW: Validate is_tire flags so user knows image is not a tyre
    final bad = <String>[];
    final front = resp?.data?.front;
    final back = resp?.data?.back;
    if (front != null && front.isTire == false) bad.add('Front');
    if (back != null && back.isTire == false) bad.add('Back');

    if (bad.isNotEmpty) {
      final msg =
          '${bad.join(' & ')} image${bad.length > 1 ? 's are' : ' is'} not a tyre. Please upload a clear tyre photo.';

      // Keep response for UI, but mark as failure to trigger Snackbar.
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        twoWheelerResponse: resp,
        twoWheelerError: msg,
      ));
      return;
    }

    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.success,
      twoWheelerResponse: resp,
      twoWheelerError: '',
    ));
  } else {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      twoWheelerError: result.failure?.message ?? 'Upload failed',
    ));
  }
}



  Future<void> _onForgotVerifyEmail(
    ForgotPasswordVerifyEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();

    if (email.isEmpty) {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.failure,
        forgotEmailError: "Email is required",
        verifyEmailResponse: null,
      ));
      return;
    }

    emit(state.copyWith(
      forgotEmailStatus: ForgotEmailStatus.loading,
      forgotEmailError: null,
      verifyEmailResponse: null,
    ));

    // ✅ Your repository signature: verifyEmail({required email})
    final result = await repo.verifyEmail(email: email);

    if (result.isSuccess) {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.success,
        verifyEmailResponse: result.data,
        forgotEmailError: null,
      ));
    } else {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.failure,
        forgotEmailError: result.failure?.message ?? "Email verification failed",
        verifyEmailResponse: null,
      ));
    }
  }

  Future<void> _onAdsFetch(AdsFetchRequested e, Emitter<AuthState> emit) async {
  if (!e.silent) {
    emit(state.copyWith(adsError: null));
  }

  emit(state.copyWith(adsStatus: AdsStatus.loading, adsError: null));

  final r = await repo.fetchCustomAds(token: e.token);

  if (!r.isSuccess) {
    emit(state.copyWith(
      adsStatus: AdsStatus.failure,
      adsError: r.failure?.message ?? "Failed to load ads",
      ads: const <AdItem>[],
      selectedAd: null,
    ));
    return;
  }

  final list = r.data ?? const <AdItem>[];

  // ✅ pick first active ad
  final first = list.isNotEmpty ? list.first : null;

  emit(state.copyWith(
    adsStatus: AdsStatus.success,
    ads: list,
    selectedAd: first,
    adsError: null,
  ));
}

Future<void> _onAdsSelect(AdsSelectRequested e, Emitter<AuthState> emit) async {
  final found = state.ads.firstWhere(
    (x) => x.id == e.adId,
    orElse: () => state.selectedAd ?? (state.ads.isNotEmpty ? state.ads.first : AdItem(
      id: '',
      name: '',
      latitude: 0,
      longitude: 0,
      credits: 0,
      creditsUsed: 0,
      status: 'inactive',
      createdAt: null,
      audience: '',
      media: '',
      radius: 0,
    )),
  );

  emit(state.copyWith(selectedAd: found.id.isEmpty ? null : found));
}


  // ============================================================
  // ✅ Forgot Password - Step 2: Reset Password with userId
  // ============================================================
  Future<void> _onForgotResetPassword(
    ForgotPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    final userId = event.userId.trim();
    final p1 = event.newPassword.trim();
    final p2 = event.confirmPassword.trim();

    if (userId.isEmpty) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "UserId missing. Please verify email again.",
        forgotResetResponse: null,
      ));
      return;
    }

    if (p1.isEmpty || p2.isEmpty) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "Password fields are required",
        forgotResetResponse: null,
      ));
      return;
    }

    if (p1 != p2) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "Passwords do not match",
        forgotResetResponse: null,
      ));
      return;
    }

    emit(state.copyWith(
      forgotResetStatus: ForgotResetStatus.loading,
      forgotResetError: null,
      forgotResetResponse: null,
    ));

    final result = await repo.resetPassword(
      request: ResetPasswordRequest(
        userId: userId,
        newPassword: p1,
        confirmNewPassword: p2,
      ),
    );

    if (result.isSuccess) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.success,
        forgotResetResponse: result.data,
        forgotResetError: null,
      ));
    } else {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: result.failure?.message ?? "Reset password failed",
        forgotResetResponse: null,
      ));
    }
  }

  Future<void> _onClearForgot(
    ForgotPasswordClearRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      forgotEmailStatus: ForgotEmailStatus.initial,
      verifyEmailResponse: null,
      forgotEmailError: null,
      forgotResetStatus: ForgotResetStatus.initial,
      forgotResetResponse: null,
      forgotResetError: null,
    ));
  }


  Future<void> _onOtpIssuedNow(OtpIssuedNow e, Emitter<AuthState> emit) async {

    await repo.verifyEmail(email: e.email);
   
    emit(state.copyWith(
      otpIssuedAt: DateTime.now(),
      verifyOtpStatus: VerifyOtpStatus.initial,
      verifyOtpError: null,
      verifyOtpResponse: null,
      otpExpirySeconds: 600,
    ));
  }

  Future<void> _onVerifyOtp(VerifyOtpRequested e, Emitter<AuthState> emit) async {
    if (state.verifyOtpStatus == VerifyOtpStatus.verifying) return;

    final issued = state.otpIssuedAt;
    if (issued != null) {
      final elapsed = DateTime.now().difference(issued).inSeconds;
      if (elapsed > state.otpExpirySeconds) {
        emit(state.copyWith(
          verifyOtpStatus: VerifyOtpStatus.failure,
          verifyOtpError: "OTP expired. Please resend OTP.",
        ));
        return;
      }
    }

    if (e.email.trim().isEmpty) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: "Email is required",
      ));
      return;
    }

    if (e.otp <= 0) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: "Invalid OTP",
      ));
      return;
    }

    emit(state.copyWith(
      verifyOtpStatus: VerifyOtpStatus.verifying,
      verifyOtpError: null,
      verifyOtpResponse: null,
    ));

    final r = await repo.verifyOtp(
      request: VerifyOtpRequest(email: e.email.trim(), otp: e.otp),
      token: e.token,
    );

    if (r.isSuccess) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.success,
        verifyOtpResponse: r.data,
        verifyOtpError: null,
      ));

      add(const FetchProfileRequested());
    } else {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: r.failure?.message ?? "OTP verification failed",
      ));
    }
  }


Future<void> _onCurrentLocationRequested(
    CurrentLocationRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (!e.force &&
        state.currentLat != null &&
        state.currentLng != null &&
        state.locationStatus == LocationStatus.success) {
      if (state.shops.isEmpty && state.shopsStatus != ShopsStatus.loading) {
        add(FetchNearbyShopsRequested(
          latitude: state.currentLat!,
          longitude: state.currentLng!,
        ));
      }
      return;
    }

    emit(state.copyWith(
      locationStatus: LocationStatus.loading,
      locationError: null,
    ));

    try {
      final pos = await LocationHelper.getCurrentLocation();

      if (pos == null) {
        emit(state.copyWith(
          locationStatus: LocationStatus.failure,
          locationError:
              "Location unavailable. Enable GPS and allow location permission.",
        ));
      }

      emit(state.copyWith(
        locationStatus: LocationStatus.success,
        currentLat: pos!.latitude,
        currentLng: pos!.longitude,
        locationError: null,
      ));

      add(FetchNearbyShopsRequested(
        latitude: pos.latitude,
        longitude: pos.longitude,
      ));
    } catch (ex) {
      emit(state.copyWith(
        locationStatus: LocationStatus.failure,
        locationError: ex.toString(),
      ));
    }
  }

  Future<void> _onNearbyShopsRefreshRequested(
    NearbyShopsRefreshRequested e,
    Emitter<AuthState> emit,
  ) async {
    // ✅ refresh using cached location (no hardcode)
    final lat = state.currentLat;
    final lng = state.currentLng;

    if (lat == null || lng == null) {
      add(const CurrentLocationRequested(force: true));
      return;
    }

    add(FetchNearbyShopsRequested(latitude: lat, longitude: lng));
  }

  Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
    final tok = await repo.getSavedToken();

    if (tok != null && tok.isNotEmpty) {
      add(const FetchProfileRequested());
      add(const NotificationStartListening(intervalSeconds: 15));
      add(const CurrentLocationRequested());
    }
  }

  Future<void> _onNotificationFetch(
    NotificationFetchRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (!e.silent) {
      emit(state.copyWith(notificationError: null));
    }

    final r = await repo.fetchNotifications(page: e.page, limit: e.limit);

    if (!r.isSuccess) {
      if (!e.silent) {
        emit(state.copyWith(
          notificationError:
              r.failure?.message ?? "Failed to load notifications",
        ));
      }
      return;
    }

    final list = r.data ?? const <NotificationItem>[];
    final readIds = _readIds();
    final unread = _computeUnread(list, readIds);

    emit(state.copyWith(
      notifications: list,
      notificationUnreadCount: unread,
      notificationError: null,
    ));
  }

  Future<void> _onNotificationStart(
    NotificationStartListening e,
    Emitter<AuthState> emit,
  ) async {
    _notifTimer?.cancel();

    emit(state.copyWith(notificationListening: true));

    add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));

    _notifTimer = Timer.periodic(Duration(seconds: e.intervalSeconds), (_) {
      add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));
    });
  }

  Future<void> _onNotificationStop(
    NotificationStopListening e,
    Emitter<AuthState> emit,
  ) async {
    _notifTimer?.cancel();
    _notifTimer = null;
    emit(state.copyWith(notificationListening: false));
  }

  Future<void> _onNotificationMarkAllRead(
    NotificationMarkAllRead e,
    Emitter<AuthState> emit,
  ) async {
    final current = state.notifications;
    if (current.isEmpty) {
      emit(state.copyWith(notificationUnreadCount: 0));
      return;
    }

    final ids = current.map((n) => n.id).where((id) => id.isNotEmpty).toSet();
    final readIds = _readIds()..addAll(ids);
    await _writeReadIds(readIds);

    emit(state.copyWith(notificationUnreadCount: 0));
  }

  Future<void> _onNotificationMarkSeenByIds(
    NotificationMarkSeenByIds e,
    Emitter<AuthState> emit,
  ) async {
    if (e.ids.isEmpty) return;

    final readIds = _readIds()..addAll(e.ids.where((x) => x.trim().isNotEmpty));
    await _writeReadIds(readIds);

    final unread = _computeUnread(state.notifications, readIds);
    emit(state.copyWith(notificationUnreadCount: unread));
  }

  // ============================================================
  // ✅ Shops
  // ============================================================
  // Future<void> _onFetchNearbyShops(
  //   FetchNearbyShopsRequested e,
  //   Emitter<AuthState> emit,
  // ) async {
  //   emit(state.copyWith(
  //     shopsStatus: ShopsStatus.loading,
  //     shopsError: null,
  //   ));

  //   final r = await repo.fetchNearbyShops(
  //     latitude: e.latitude,
  //     longitude: e.longitude,
  //   );

  //   if (r.isSuccess) {
  //     emit(state.copyWith(
  //       shopsStatus: ShopsStatus.success,
  //       shops: r.data ?? <ShopVendorModel>[],
  //       shopsError: null,
  //     ));
  //   } else {
  //     emit(state.copyWith(
  //       shopsStatus: ShopsStatus.failure,
  //       shopsError: r.failure?.message ?? 'Failed to load shops',
  //     ));
  //   }
  // }

  Future<void> _onFetchNearbyShops(
  FetchNearbyShopsRequested e,
  Emitter<AuthState> emit,
) async {
  if (!e.silent) {
    emit(state.copyWith(
      shopsStatus: ShopsStatus.loading,
      shopsError: null,
    ));
  } else {
    emit(state.copyWith(shopsError: null));
  }

  final r = await repo.fetchNearbyShops(
    latitude: e.latitude,
    longitude: e.longitude,
  );

  if (r.isSuccess) {
    emit(state.copyWith(
      shopsStatus: ShopsStatus.success,
      shops: r.data ?? <ShopVendorModel>[],
      shopsError: null,
    ));
  } else {
    // ✅ If silent: don’t wipe existing markers; only set error optionally
    emit(state.copyWith(
      shopsStatus: e.silent ? state.shopsStatus : ShopsStatus.failure,
      shopsError: r.failure?.message ?? 'Failed to load shops',
    ));
  }
}

  // ============================================================
  // ✅ Login/Signup
  // ============================================================
  Future<void> _onLogin(LoginRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(loginStatus: AuthStatus.loading, error: null));
    final r =
        await repo.login(LoginRequest(email: e.email, password: e.password));

    if (r.isSuccess) {
      emit(state.copyWith(
        loginStatus: AuthStatus.success,
        loginResponse: r.data,
        error: null,
      ));
      add(const FetchProfileRequested());
    } else {
      emit(state.copyWith(
        loginStatus: AuthStatus.failure,
        error: r.failure?.message ?? 'Login failed',
      ));
    }
  }

  Future<void> _onSignup(SignupRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(signupStatus: AuthStatus.loading, error: null));

    final r = await repo.signup(SignupRequest(
      firstName: e.firstName,
      lastName: e.lastName,
      email: e.email,
      password: e.password,
    ));

    if (r.isSuccess) {
      emit(state.copyWith(
        signupStatus: AuthStatus.success,
        signupResponse: r.data,
        error: null,
      ));
    } else {
      emit(state.copyWith(
        signupStatus: AuthStatus.failure,
        error: r.failure?.message ?? 'Signup failed',
      ));
    }
  }

  Future<void> _onFourWheelerUpload(
    UploadFourWheelerRequested e,
    Emitter<AuthState> emit,
  ) async {
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (state.fourWheelerStatus == FourWheelerStatus.uploading) return;

    if (token.isEmpty) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Missing auth token. Please log in again.',
      ));
      return;
    }

    if (state.profile?.userId == null) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'User profile not loaded. Please login again.',
      ));
      return;
    }

    if (e.vehicleId.trim().isEmpty) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Missing vehicle_id.',
      ));
      return;
    }

    if (!File(e.frontLeftPath).existsSync() ||
        !File(e.frontRightPath).existsSync() ||
        !File(e.backLeftPath).existsSync() ||
        !File(e.backRightPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'One or more images not found.',
      ));
      return;
    }

    emit(state.copyWith(
      fourWheelerStatus: FourWheelerStatus.uploading,
      fourWheelerError: null,
      fourWheelerResponse: null,
    ));

    final req = FourWheelerUploadRequest(
      userId: state.profile!.userId.toString(),
      token: token,
      vehicleId: e.vehicleId,
      vehicleType: e.vehicleType,
      vin: e.vin,
      frontLeftTyreId: e.frontLeftTyreId,
      frontRightTyreId: e.frontRightTyreId,
      backLeftTyreId: e.backLeftTyreId,
      backRightTyreId: e.backRightTyreId,
      frontLeftPath: e.frontLeftPath,
      frontRightPath: e.frontRightPath,
      backLeftPath: e.backLeftPath,
      backRightPath: e.backRightPath,
    );

    final r = await repo.uploadFourWheeler(req);

    if (r.isSuccess) {
      final resp = r.data;

      // ✅ NEW: Validate is_tire flags (if any image isn't a tyre, show error)
      final bad = resp?.data.notTyreSides() ?? const <NotTyreSide>[];
      if (bad.isNotEmpty) {
        final labels = bad.map((e) => e.label).toList();
        final msg =
            '${labels.join(', ')} image${labels.length > 1 ? 's are' : ' is'} not a tyre. Please upload clear tyre photos.';

        // Keep response (optional), but mark as failure so GenerateReportScreen can show error.
        emit(state.copyWith(
          fourWheelerStatus: FourWheelerStatus.failure,
          fourWheelerResponse: resp,
          fourWheelerError: msg,
        ));
        return;
      }

      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.success,
        fourWheelerResponse: resp,
        fourWheelerError: null,
      ));
    } else {
      final sc = r.failure?.statusCode;
      final msg =
          r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: msg,
      ));
    }
  }


  Future<void> _onFetchProfile(
    FetchProfileRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(profileStatus: ProfileStatus.loading, error: null));

    final r = await repo.fetchProfile(token: e.token);

    if (r.isSuccess) {
      final profile = r.data;

      emit(state.copyWith(
        profileStatus: ProfileStatus.success,
        profile: profile,
        error: null,
      ));

      if (state.tyreHistoryStatus == TyreHistoryStatus.initial &&
          profile?.userId != null) {
        add(
          FetchTyreHistoryRequested(
            userId: profile!.userId.toString(),
            vehicleId: "ALL",
          ),
        );
      }
    } else {
      emit(state.copyWith(
        profileStatus: ProfileStatus.failure,
        error: r.failure?.message ?? 'Failed to fetch profile',
      ));
    }
  }


  Future<void> addVehiclePreferences(
    AddVehiclePreferenccesEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      addVehiclePreferencesStatus: AddVehiclePreferencesStatus.loading,
      errorMessageVehiclePreferences: null,
    ));

    final result = await repo.addVehiclePreferences(
      vehiclePreference: event.vehiclePreference,
      brandName: event.brandName,
      modelName: event.modelName,
      licensePlate: event.licensePlate,
      isOwn: event.isOwn,
      tireBrand: event.tireBrand,
      tireDimension: event.tireDimension,
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        addVehiclePreferencesStatus: AddVehiclePreferencesStatus.failure,
        errorMessageVehiclePreferences:
            result.failure?.message ?? 'Failed to save vehicle',
      ));
      return;
    }

    emit(state.copyWith(
      addVehiclePreferencesStatus: AddVehiclePreferencesStatus.success,
      vehiclePreferencesModel: result.data,
    ));
  }


  Future<void> _onFetchTyreHistory(
    FetchTyreHistoryRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      tyreHistoryStatus: TyreHistoryStatus.loading,
      tyreHistoryError: null,
    ));

    try {
      final results = await Future.wait([
        repo.fetchUserRecords(
          userId: e.userId,
          vehicleType: "car",
          vehicleId: e.vehicleId,
        ),
        repo.fetchUserRecords(
          userId: e.userId,
          vehicleType: "bike",
          vehicleId: e.vehicleId,
        ),
      ]);

      final carRes = results[0];
      final bikeRes = results[1];

      if (!carRes.isSuccess && !bikeRes.isSuccess) {
        emit(state.copyWith(
          tyreHistoryStatus: TyreHistoryStatus.failure,
          tyreHistoryError: carRes.failure?.message ??
              bikeRes.failure?.message ??
              "Failed to load history",
        ));
        return;
      }

      final updated = Map<String, List<TyreRecord>>.from(state.tyreRecordsByType);

      if (carRes.isSuccess) updated['car'] = carRes.data ?? const <TyreRecord>[];
      if (bikeRes.isSuccess) updated['bike'] = bikeRes.data ?? const <TyreRecord>[];

      emit(state.copyWith(
        tyreHistoryStatus: TyreHistoryStatus.success,
        tyreHistoryError: null,
        tyreRecordsByType: updated,
      ));
    } catch (ex) {
      emit(state.copyWith(
        tyreHistoryStatus: TyreHistoryStatus.failure,
        tyreHistoryError: ex.toString(),
      ));
    }
  }


  Future<void> _onUpdateUserDetails(
    UpdateUserDetailsRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (state.updateProfileStatus == UpdateProfileStatus.loading) return;

    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (token.isEmpty) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: 'Missing auth token. Please login again.',
      ));
      return;
    }

    if (e.firstName.trim().isEmpty || e.lastName.trim().isEmpty) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: 'First name and last name are required.',
      ));
      return;
    }

    emit(state.copyWith(
      updateProfileStatus: UpdateProfileStatus.loading,
      updateProfileError: null,
      updateProfileResponse: null,
    ));

    try {
      final r = await repo.updateUserDetails(
        token: token,
        request: UpdateUserDetailsRequest(
          email: e.email.trim(),
          firstName: e.firstName.trim(),
          lastName: e.lastName.trim(),
          profileImage: e.profileImage.trim(),
          phone: e.phone.trim(),
        ),
      );

      final p = state.profile;
      UserProfile? updatedProfile = p;
      if (p != null) {
        updatedProfile = p.copyWith(
          firstName: e.firstName.trim(),
          lastName: e.lastName.trim(),
          phone: e.phone.trim(),
          profileImage: e.profileImage.trim(),
        );
      }

      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.success,
        updateProfileResponse: r,
        updateProfileError: null,
        profile: updatedProfile ?? state.profile,
      ));

      add(const FetchProfileRequested());
    } catch (ex) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: ex.toString(),
      ));
    }
  }


  Future<void> _onChangePassword(
    ChangePasswordRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (state.changePasswordStatus == ChangePasswordStatus.loading) return;

    final userId = state.profile?.userId?.toString() ?? '';
    if (userId.trim().isEmpty) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'User profile not loaded. Please login again.',
      ));
      return;
    }

    if (e.newPassword.trim().isEmpty || e.confirmNewPassword.trim().isEmpty) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'Password fields are required.',
      ));
      return;
    }

    if (e.newPassword.trim() != e.confirmNewPassword.trim()) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'New passwords do not match.',
      ));
      return;
    }

    emit(state.copyWith(
      changePasswordStatus: ChangePasswordStatus.loading,
      changePasswordError: null,
      changePasswordResponse: null,
    ));

    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    final r = await repo.resetPassword(
      request: ResetPasswordRequest(
        oldPassword: e.oldPassword,
        userId: userId.trim(),
        newPassword: e.newPassword.trim(),
        confirmNewPassword: e.confirmNewPassword.trim(),
      ),
      token: token.isEmpty ? null : token,
    );

    if (r.isSuccess) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.success,
        changePasswordResponse: r.data,
        changePasswordError: null,
      ));
    } else {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: r.failure?.message ?? 'Failed to change password',
      ));
    }
  }

  // ============================================================
  // ✅ Close
  // ============================================================
  @override
  Future<void> close() {
    _notifTimer?.cancel();
    _notifTimer = null;
    return super.close();
  }
}

