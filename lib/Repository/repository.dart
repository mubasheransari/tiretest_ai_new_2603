import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ios_tiretest_ai/Data/token_store.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:ios_tiretest_ai/models/ad_models.dart';
import 'package:ios_tiretest_ai/models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/models/auth_models.dart';
import 'package:http_parser/http_parser.dart';
import 'package:ios_tiretest_ai/models/four_wheeler_uploads_request.dart';
import 'package:ios_tiretest_ai/models/reset_password_request.dart';
import 'package:ios_tiretest_ai/models/reset_password_response.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:ios_tiretest_ai/models/update_user_details_model.dart';
import 'package:ios_tiretest_ai/models/verify_email_response.dart';
import 'package:ios_tiretest_ai/models/verify_otp_model.dart';
import 'package:mime/mime.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/models/user_profile.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:ios_tiretest_ai/models/notification_models.dart';



class Failure {
  final String code;
  final String message;
  final int? statusCode;
  const Failure({required this.code, required this.message, this.statusCode});
}

class Result<T> {
  final T? data;
  final Failure? failure;
  const Result._(this.data, this.failure);
  bool get isSuccess => failure == null;

  factory Result.ok(T data) => Result._(data, null);
  factory Result.fail(Failure f) => Result._(null, f);
}

abstract class AuthRepository {
    Future<Result<List<AdItem>>> fetchCustomAds({String? token});
    Future<Result<VerifyEmailResponse>> verifyEmail({
    required String email,
    String? token,
  });
Future<Result<List<NotificationItem>>> fetchNotifications({
  int page = 1,
  int limit = 50,
});

    Future<Result<ResetPasswordResponse>> resetPassword({
    required ResetPasswordRequest request,
    String? token, // optional (if backend needs it later)
  });
  Future<Result<LoginResponse>> login(LoginRequest req);
  Future<Result<SignupResponse>> signup(SignupRequest req);
  Future<Result<UserProfile>> fetchProfile({String? token});
  Future<void> saveToken(String token);
  Future<String?> getSavedToken();
  Future<void> clearToken();
  Future<Result<VehiclePreferencesModel>> addVehiclePreferences({
    required String vehiclePreference,
    required String brandName,
    required String modelName,
    required String licensePlate,
    required bool? isOwn,
    required String tireBrand,
    required String tireDimension,
  });
  Future<Result<List<ShopVendorModel>>> fetchNearbyShops({
  required double latitude,
  required double longitude,
});

  Future<Result<ResponseFourWheeler>> uploadFourWheeler(FourWheelerUploadRequest req);

  Future<Result<List<TyreRecord>>> fetchUserRecords({
  required String userId,
  required String vehicleType,
  String vehicleId = "ALL",
});
    Future<UpdateUserDetailsResponse> updateUserDetails({
    required String token,
    required UpdateUserDetailsRequest request,
  });

  Future<Result<VerifyOtpResponse>> verifyOtp({
    required VerifyOtpRequest request,
    String? token, // if backend requires Authorization
  });

  Future<Result<TwoWheelerTyreUploadResponse>> uploadTwoWheeler(TyreUploadRequest req);

}

class AuthRepositoryHttp implements AuthRepository {
  AuthRepositoryHttp({
    this.timeout = const Duration(seconds: 200),
    TokenStore? tokenStore,
  }) : _tokenStore = tokenStore ?? TokenStore();

  final Duration timeout;
  final TokenStore _tokenStore;

  static const String _twoWheelerUrl =
      'http://54.162.208.215/app/tyre/two_wheeler_upload/';

  static const String _profileUrl =
      'http://54.162.208.215/backend/api/profile';

  Map<String, String> _jsonHeaders() => const {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  Failure _serverFail(http.Response res, {String? fallback}) {
    String msg = fallback ?? 'Server error (${res.statusCode})';
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed['message'] != null) {
        msg = parsed['message'].toString();
      }
    } catch (_) {/* ignore */}
    return Failure(code: 'server', message: msg, statusCode: res.statusCode);
  }

  @override
  Future<void> saveToken(String token) => _tokenStore.save(token);

  @override
  Future<String?> getSavedToken() => _tokenStore.read();

  @override
  Future<void> clearToken() => _tokenStore.clear();

  // ============================================================
  // ✅ NEW: SAFE compression helper (fix jpg/jpeg assertion)
  // ============================================================
  Future<File> _compressSafe(String inputPath) async {
    final inFile = File(inputPath);
    if (!await inFile.exists()) return inFile;

    final ext = p.extension(inputPath).toLowerCase();

    // ✅ choose output format based on input extension
    final bool isPng = ext == '.png';
    final CompressFormat format = isPng ? CompressFormat.png : CompressFormat.jpeg;
    final String outExt = isPng ? '.png' : '.jpg'; // ✅ VERY IMPORTANT

    final dir = inFile.parent.path;
    final base = p.basenameWithoutExtension(inputPath);
    final outPath = p.join(
      dir,
      'cmp_${DateTime.now().millisecondsSinceEpoch}_$base$outExt',
    );

    try {
      final XFile? outX = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        outPath,
        quality: 75,
        minWidth: 1080,
        keepExif: false,
        format: format,
      );

      if (outX != null && outX.path.isNotEmpty) {
        return File(outX.path);
      }
    } catch (_) {
      // If compression fails for any reason, fallback to original
    }

    return inFile;
  }

@override
Future<Result<TwoWheelerTyreUploadResponse>> uploadTwoWheeler(
  TyreUploadRequest req,
) async {
  final url = _twoWheelerUrl;

  final masked = req.token.length > 9
      ? '${req.token.substring(0, 4)}…${req.token.substring(req.token.length - 4)}'
      : '***';

  final token = req.token.trim();
  if (token.isEmpty) {
    return Result.fail(const Failure(
      code: 'auth',
      message: 'Missing token. Please login again.',
    ));
  }

  final userId = req.userId.trim();
  final vehicleId = req.vehicleId.trim();

  if (userId.isEmpty) {
    return Result.fail(const Failure(
      code: 'validation',
      message: 'Missing user_id.',
    ));
  }
  if (vehicleId.isEmpty) {
    return Result.fail(const Failure(
      code: 'validation',
      message: 'Missing vehicle_id.',
    ));
  }

  final vehicleTypeValue =
      req.vehicleType.trim().isEmpty ? 'bike' : req.vehicleType.trim();

  final vinValue = (req.vin ?? '').trim().isEmpty ? 'UNKNOWN' : req.vin!.trim();

  final frontTyreId = req.frontTyreId.trim();
  final backTyreId = req.backTyreId.trim();

  if (frontTyreId.isEmpty) {
    return Result.fail(const Failure(
      code: 'validation',
      message: 'Missing front_tyre_id.',
    ));
  }
  if (backTyreId.isEmpty) {
    return Result.fail(const Failure(
      code: 'validation',
      message: 'Missing back_tyre_id.',
    ));
  }

  // ✅ check files exist
  try {
    final paths = [req.frontPath, req.backPath];
    for (final path in paths) {
      final f = File(path);
      if (!await f.exists()) {
        return Result.fail(
          Failure(code: 'file', message: 'File not found: $path'),
        );
      }
    }
  } catch (_) {}

  const bool enableCompression = true;

  try {
    final frontFile = enableCompression
        ? await _compressSafe(req.frontPath)
        : File(req.frontPath);

    final backFile = enableCompression
        ? await _compressSafe(req.backPath)
        : File(req.backPath);

    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.acceptHeader: 'application/json',
    });

    request.fields.addAll({
      'user_id': userId,
      'vehicle_id': vehicleId,
      'vehicle_type': vehicleTypeValue,
      'vin': vinValue,
      'front_tyre_id': frontTyreId,
      'back_tyre_id': backTyreId,
    });

    request.files.addAll([
      await http.MultipartFile.fromPath(
        'frontimage',
        frontFile.path,
        filename: p.basename(frontFile.path),
      ),
      await http.MultipartFile.fromPath(
        'backimage',
        backFile.path,
        filename: p.basename(backFile.path),
      ),
    ]);

    // ignore: avoid_print
    print('==[UPLOAD-2W][HTTP]=> POST $url');
    // ignore: avoid_print
    print('Headers: {Authorization: Bearer $masked, Accept: application/json}');
    // ignore: avoid_print
    print(
      'Fields: {user_id:$userId, vehicle_id:$vehicleId, vehicle_type:$vehicleTypeValue, vin:$vinValue, '
      'front_tyre_id:$frontTyreId, back_tyre_id:$backTyreId}',
    );

    final streamed = await request.send().timeout(const Duration(seconds: 200));
    final status = streamed.statusCode;
    final body = await streamed.stream.bytesToString();

    // ignore: avoid_print
    print('<= [UPLOAD-2W][HTTP] $status');
    // ignore: avoid_print
    print('<= Body: $body');

    // ✅ empty body guard
    if (body.trim().isEmpty) {
      return Result.fail(Failure(
        code: 'parse',
        message: 'Empty response from server ($status).',
        statusCode: status,
      ));
    }

    // ✅ decode JSON object
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return Result.fail(const Failure(
        code: 'parse',
        message: 'Invalid JSON response (expected object).',
      ));
    }

    final parsed = decoded;

    // ✅ success
    if (status == 200 || status == 201) {
      try {
        final resp = TwoWheelerTyreUploadResponse.fromJson(parsed);

        // ✅ NEW MODEL: data is OBJECT, so validate like this:
        if (resp.data == null) {
          final msg = resp.message.trim().isNotEmpty
              ? resp.message
              : 'Upload succeeded but report data is missing.';
          return Result.fail(Failure(code: 'parse', message: msg));
        }

        // optional (recommended): ensure at least one side exists
        if (resp.data!.front == null && resp.data!.back == null) {
          final msg = resp.message.trim().isNotEmpty
              ? resp.message
              : 'Upload succeeded but tyre details are missing.';
          return Result.fail(Failure(code: 'parse', message: msg));
        }

        return Result.ok(resp);
      } catch (e) {
        return Result.fail(Failure(
          code: 'parse',
          message: 'Failed to parse upload response: $e',
        ));
      }
    }

    // ✅ auth mapping
    if (status == 401 || status == 403) {
      return Result.fail(const Failure(
        code: 'auth',
        message: 'Invalid credentials / token.',
      ));
    }

    // ✅ error message extraction
    String msg = 'Server error ($status)';
    if (parsed['message'] != null) msg = parsed['message'].toString();
    else if (parsed['error'] != null) msg = parsed['error'].toString();
    else if (parsed['detail'] != null) msg = parsed['detail'].toString();
    else if (body.trim().isNotEmpty) {
      msg = body.length > 200 ? body.substring(0, 200) : body;
    }

    return Result.fail(Failure(code: 'server', message: msg, statusCode: status));
  } on SocketException {
    return Result.fail(const Failure(
      code: 'network',
      message: 'Network error / server unreachable',
    ));
  } on HttpException catch (e) {
    return Result.fail(Failure(code: 'server', message: e.message));
  } on FormatException {
    return Result.fail(const Failure(
      code: 'parse',
      message: 'Invalid JSON response',
    ));
  } on TimeoutException {
    return Result.fail(const Failure(
      code: 'timeout',
      message: 'Request timed out',
    ));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }
}







@override
Future<Result<List<AdItem>>> fetchCustomAds({String? token}) async {
  final uri = Uri.parse(ApiConfig.customAds);

  final saved = await getSavedToken();
  final tok = (token ?? saved ?? '').trim();

  final headers = <String, String>{
    ..._jsonHeaders(),
    if (tok.isNotEmpty) HttpHeaders.authorizationHeader: "Bearer $tok",
  };

  try {
    final res = await http.get(uri, headers: headers).timeout(timeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.fail(const Failure(code: "parse", message: "Invalid ads response"));
      }
      final ads = AdsResponse.fromJson(decoded).data;

      // keep only active + having media
      final filtered = ads.where((a) => a.isActive && a.media.trim().isNotEmpty).toList();
      return Result.ok(filtered);
    }

    return Result.fail(_serverFail(res));
  } on SocketException {
    return Result.fail(const Failure(code: "network", message: "No internet connection"));
  } on TimeoutException {
    return Result.fail(const Failure(code: "timeout", message: "Request timed out"));
  } catch (e) {
    return Result.fail(Failure(code: "unknown", message: e.toString()));
  }
}


  @override
Future<Result<VerifyEmailResponse>> verifyEmail({
  required String email,
  String? token,
}) async {
  final uri = Uri.parse(ApiConfig.verifyEmail);

  final saved = await getSavedToken();
  final tok = (token ?? saved ?? '').trim();

  final headers = <String, String>{
    ..._jsonHeaders(),
    if (tok.isNotEmpty) HttpHeaders.authorizationHeader: "Bearer $tok",
  };

  final body = {"email": email.trim()};

  // ignore: avoid_print
  print("==[VERIFY-EMAIL]=> POST ${ApiConfig.verifyEmail}");
  // ignore: avoid_print
  print("Body: $body");

  try {
    final res = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    final status = res.statusCode;

    // ignore: avoid_print
    print("<= [VERIFY-EMAIL] $status");
    // ignore: avoid_print
    print("<= Body: ${res.body}");

    if (status >= 200 && status < 300) {
      if (res.body.trim().isEmpty) {
        return Result.fail(const Failure(
          code: "parse",
          message: "Empty response from server",
        ));
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.fail(const Failure(code: "parse", message: "Invalid response format"));
      }

      final resp = VerifyEmailResponse.fromJson(decoded);

      if (resp.userId.trim().isEmpty) {
        String msg = decoded["message"]?.toString() ?? "Email verification failed";
        return Result.fail(Failure(code: "validation", message: msg, statusCode: status));
      }

      return Result.ok(resp);
    }

    // extract error message
    String msg = "Request failed ($status)";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        if (decoded["message"] != null) msg = decoded["message"].toString();
        else if (decoded["error"] != null) msg = decoded["error"].toString();
        else if (decoded["detail"] != null) msg = decoded["detail"].toString();
      } else if (res.body.trim().isNotEmpty) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
    } catch (_) {
      if (res.body.trim().isNotEmpty) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
    }

    return Result.fail(Failure(code: "server", message: msg, statusCode: status));
  } on SocketException {
    return Result.fail(const Failure(code: "network", message: "No internet connection"));
  } on TimeoutException {
    return Result.fail(const Failure(code: "timeout", message: "Request timed out"));
  } catch (e) {
    return Result.fail(Failure(code: "unknown", message: e.toString()));
  }
}


  @override
Future<Result<VerifyOtpResponse>> verifyOtp({
  required VerifyOtpRequest request,
  String? token, // optional bearer if backend requires it
}) async {
  final uri = Uri.parse(ApiConfig.verifyOtp);

  // ✅ Authorization is required (your statement) -> add if provided OR saved token exists
  final saved = await getSavedToken();
  final tok = (token ?? saved ?? '').trim();

  final headers = <String, String>{
    ..._jsonHeaders(),
    if (tok.isNotEmpty) HttpHeaders.authorizationHeader: "Bearer $tok",
  };

  // ignore: avoid_print
  print("==[VERIFY-OTP]=> POST ${ApiConfig.verifyOtp}");
  // ignore: avoid_print
  print("Headers: {Accept: application/json, Content-Type: application/json"
      "${tok.isNotEmpty ? ", Authorization: Bearer ****" : ""}}");
  // ignore: avoid_print
  print("Body: ${request.toJson()}");

  try {
    final res = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(request.toJson()),
        )
        .timeout(timeout);

    final status = res.statusCode;

    // ignore: avoid_print
    print("<= [VERIFY-OTP] $status");
    // ignore: avoid_print
    print("<= Body: ${res.body}");

    if (status >= 200 && status < 300) {
      if (res.body.trim().isEmpty) {
        return Result.fail(const Failure(
          code: "parse",
          message: "Empty response from server",
        ));
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.fail(const Failure(code: "parse", message: "Invalid response format"));
      }

      final resp = VerifyOtpResponse.fromJson(decoded);

      // ✅ Save token returned by verifyOTP
      if (resp.token.trim().isNotEmpty) {
        await saveToken(resp.token.trim());

        // if you also store in GetStorage somewhere else, you can keep it consistent:
        // final box = GetStorage();
        // box.write("token", resp.token.trim());
        // box.write("auth_token", resp.token.trim());
      }

      return Result.ok(resp);
    }

    // ✅ extract error message
    String msg = "Request failed ($status)";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        if (decoded["message"] != null) msg = decoded["message"].toString();
        else if (decoded["error"] != null) msg = decoded["error"].toString();
        else if (decoded["detail"] != null) msg = decoded["detail"].toString();
      } else if (res.body.trim().isNotEmpty) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
    } catch (_) {
      if (res.body.trim().isNotEmpty) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
    }

    return Result.fail(Failure(code: "server", message: msg, statusCode: status));
  } on SocketException {
    return Result.fail(const Failure(code: "network", message: "No internet connection"));
  } on TimeoutException {
    return Result.fail(const Failure(code: "timeout", message: "Request timed out"));
  } catch (e) {
    return Result.fail(Failure(code: "unknown", message: e.toString()));
  }
}


 @override
Future<Result<List<NotificationItem>>> fetchNotifications({
  int page = 1,
  int limit = 50,
}) async {
  final uri = Uri.parse(ApiConfig.getNotification).replace(queryParameters: {
    "page": "$page",
    "limit": "$limit",
  });

  try {
    final res = await http.get(uri, headers: _jsonHeaders()).timeout(timeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);

      if (decoded is! Map<String, dynamic>) {
        return Result.fail(const Failure(code: "parse", message: "Invalid response"));
      }

      final data = decoded["data"];
      if (data is! List) {
        return Result.fail(const Failure(code: "parse", message: "Missing data list"));
      }

      final list = data
          .whereType<Map>()
          .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // newest first by sentAt/createdAt
      list.sort((a, b) {
        final ad = a.sentAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.sentAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      return Result.ok(list);
    }

    return Result.fail(_serverFail(res));
  } on SocketException {
    return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
  } on TimeoutException {
    return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }
}



  @override
  Future<Result<ResetPasswordResponse>> resetPassword({
    required ResetPasswordRequest request,
    String? token,
  }) async {
    final uri = Uri.parse(ApiConfig.resetPassword);

    // optional bearer
    final headers = <String, String>{
      ..._jsonHeaders(),
      if ((token ?? '').trim().isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer ${token!.trim()}',
    };

    try {
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(timeout);

      final status = res.statusCode;

      if (status >= 200 && status < 300) {
        if (res.body.trim().isEmpty) {
          return Result.ok(const ResetPasswordResponse(message: "Password updated successfully"));
        }
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return Result.ok(ResetPasswordResponse.fromJson(decoded));
        }
        return Result.ok(const ResetPasswordResponse(message: "Password updated successfully"));
      }

      // extract backend message/error
      String msg = "Request failed ($status)";
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded["message"] != null) msg = decoded["message"].toString();
          if (decoded["error"] != null) msg = decoded["error"].toString();
        }
      } catch (_) {
        if (res.body.trim().isNotEmpty) msg = res.body;
      }

      return Result.fail(Failure(code: "server", message: msg, statusCode: status));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

@override
Future<UpdateUserDetailsResponse> updateUserDetails({
  required String token,
  required UpdateUserDetailsRequest request,
}) async {
  try {
    final uri = Uri.parse(ApiConfig.editProfile); 

    final res = await http.put(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode(request.toJson()),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.trim().isEmpty) {
        return const UpdateUserDetailsResponse(
          message: "User details updated successfully",
        );
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return UpdateUserDetailsResponse.fromJson(decoded);
      }
      return const UpdateUserDetailsResponse(
        message: "User details updated successfully",
      );
    }

    // error message extraction
    String message = "Request failed (${res.statusCode})";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded["message"] != null) {
        message = decoded["message"].toString();
      }
    } catch (_) {
      if (res.body.isNotEmpty) message = res.body;
    }

    throw Exception(message);
  } catch (e) {
    throw Exception("Something went wrong: $e");
  }
}

  String _extractDioMessage(DioException e) {
    // Try backend message first
    final data = e.response?.data;
    if (data is Map && data["message"] != null) {
      return data["message"].toString();
    }

    // Common fallbacks
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return "Request timed out. Please try again.";
    }

    if (e.response?.statusCode == 401) return "Unauthorized. Token expired.";
    if (e.response?.statusCode == 404) return "API not found (404).";
    if (e.response?.statusCode == 500) return "Server error (500).";

    return e.message ?? "Request failed.";
  }

@override
Future<Result<ResponseFourWheeler>> uploadFourWheeler(
  FourWheelerUploadRequest req,
) async {
  final url = ApiConfig.fourWheelerUrl;

  final masked = req.token.length > 9
      ? '${req.token.substring(0, 4)}…${req.token.substring(req.token.length - 4)}'
      : '***';

  // ✅ sanitize fields
  final vinValue = req.vin.trim().isEmpty ? "UNKNOWN" : req.vin.trim();
  final vehicleTypeValue =
      req.vehicleType.trim().isEmpty ? "car" : req.vehicleType.trim();

  // ✅ check files exist + log raw sizes
  try {
    final paths = [
      req.frontLeftPath,
      req.frontRightPath,
      req.backLeftPath,
      req.backRightPath,
    ];

    int total = 0;
    for (final path in paths) {
      final f = File(path);
      if (!await f.exists()) {
        return Result.fail(Failure(
          code: 'file',
          message: 'File not found: $path',
        ));
      }
      final bytes = await f.length();
      total += bytes;
      // ignore: avoid_print
      print(
          'FILE ${p.basename(path)}: ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB');
    }
    // ignore: avoid_print
    print('TOTAL UPLOAD (RAW): ${(total / 1024 / 1024).toStringAsFixed(2)} MB');
  } catch (_) {}

  const bool enableCompression = true;

  try {
    // ✅ compress safely (keep your existing implementation)
    final fl = enableCompression
        ? await _compressSafe(req.frontLeftPath)
        : File(req.frontLeftPath);
    final fr = enableCompression
        ? await _compressSafe(req.frontRightPath)
        : File(req.frontRightPath);
    final bl = enableCompression
        ? await _compressSafe(req.backLeftPath)
        : File(req.backLeftPath);
    final br = enableCompression
        ? await _compressSafe(req.backRightPath)
        : File(req.backRightPath);

    // ✅ log sizes after compression
    try {
      final files = [fl, fr, bl, br];
      int total = 0;
      for (final f in files) {
        final bytes = await f.length();
        total += bytes;
        // ignore: avoid_print
        print(
            'CMP FILE ${p.basename(f.path)}: ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      // ignore: avoid_print
      print(
          'TOTAL UPLOAD (COMPRESSED): ${(total / 1024 / 1024).toStringAsFixed(2)} MB');
    } catch (_) {}

    // ✅ Build multipart request
    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);

    // ✅ headers
    request.headers.addAll({
      HttpHeaders.authorizationHeader: 'Bearer ${req.token}',
      HttpHeaders.acceptHeader: 'application/json',
    });

    // ✅ fields (same as dio form)
    request.fields.addAll({
      'user_id': req.userId.trim(),
      'vehicle_id': req.vehicleId.trim(),
      'vehicle_type': vehicleTypeValue,
      'vin': vinValue,

      'front_left_tyre_id': req.frontLeftTyreId.trim(),
      'front_right_tyre_id': req.frontRightTyreId.trim(),
      'back_left_tyre_id': req.backLeftTyreId.trim(),
      'back_right_tyre_id': req.backRightTyreId.trim(),
    });

    // ✅ files
    request.files.addAll([
      await http.MultipartFile.fromPath(
        'front_left',
        fl.path,
        filename: p.basename(fl.path),
      ),
      await http.MultipartFile.fromPath(
        'front_right',
        fr.path,
        filename: p.basename(fr.path),
      ),
      await http.MultipartFile.fromPath(
        'back_left',
        bl.path,
        filename: p.basename(bl.path),
      ),
      await http.MultipartFile.fromPath(
        'back_right',
        br.path,
        filename: p.basename(br.path),
      ),
    ]);

    // ignore: avoid_print
    print('==[UPLOAD-4W][HTTP]=> POST $url');
    // ignore: avoid_print
    print('Headers: {Authorization: Bearer $masked, Accept: application/json}');
    // ignore: avoid_print
    print(
        'Fields: {user_id:${req.userId}, vehicle_id:${req.vehicleId}, vehicle_type:$vehicleTypeValue, vin:$vinValue, '
        'front_left_tyre_id:${req.frontLeftTyreId}, front_right_tyre_id:${req.frontRightTyreId}, '
        'back_left_tyre_id:${req.backLeftTyreId}, back_right_tyre_id:${req.backRightTyreId}}');
    // ignore: avoid_print
    print(
        'Files: FL=${fl.path} | FR=${fr.path} | BL=${bl.path} | BR=${br.path}');

    // ✅ send (http has no progress callback)
    final streamed = await request.send().timeout(
          const Duration(seconds: 200),
        );

    final status = streamed.statusCode;

    // ✅ read full response body
    final body = await streamed.stream.bytesToString();

    // ignore: avoid_print
    print('<= [UPLOAD-4W][HTTP] $status');
    // ignore: avoid_print
    print('<= Body: $body');

    // ✅ parse JSON (some APIs return plain text on error)
    Map<String, dynamic> parsed = const {};
    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          parsed = decoded;
        } else {
          // if backend returns a list or something unexpected
          return Result.fail(const Failure(
            code: 'parse',
            message: 'Invalid JSON response (expected object)',
          ));
        }
      } catch (_) {
        // not JSON
        parsed = const {};
      }
    }

    // ✅ success
    if (status == 200 || status == 201) {
      // If backend returns JSON object
      if (parsed.isNotEmpty) {
        final resp = ResponseFourWheeler.fromJson(parsed);
        return Result.ok(resp);
      }

      // If backend returns non-json success (rare)
      return Result.fail(const Failure(
        code: 'parse',
        message: 'Success response is not valid JSON',
      ));
    }

    // ✅ error message extraction
    String msg = 'Server error ($status)';
    try {
      if (parsed['message'] != null) msg = parsed['message'].toString();
      else if (parsed['error'] != null) msg = parsed['error'].toString();
      else if (parsed['detail'] != null) msg = parsed['detail'].toString();
      else if (body.trim().isNotEmpty) msg = body.length > 200 ? body.substring(0, 200) : body;
    } catch (_) {
      if (body.trim().isNotEmpty) {
        msg = body.length > 200 ? body.substring(0, 200) : body;
      }
    }

    return Result.fail(Failure(code: 'server', message: msg, statusCode: status));
  } on SocketException {
    return Result.fail(const Failure(
      code: 'network',
      message: 'Network error / server unreachable',
    ));
  } on HttpException catch (e) {
    return Result.fail(Failure(code: 'server', message: e.message));
  } on FormatException {
    return Result.fail(const Failure(code: 'parse', message: 'Invalid JSON response'));
  } on TimeoutException {
    return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }
}


  @override
  Future<Result<LoginResponse>> login(LoginRequest req) async {
    final uri = Uri.parse(ApiConfig.login);

    try {
      final res = await http
          .post(uri, headers: _jsonHeaders(), body: jsonEncode(req.toJson()))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final resp = LoginResponse.fromJson(parsed);

        final tok = _extractTokenFromRaw(parsed);
        if (tok != null && tok.isNotEmpty) {
          await saveToken(tok);
        }

        if (!resp.isValid) {
          return Result.fail(Failure(
            code: 'validation',
            message: parsed['message']?.toString() ?? 'Login failed',
            statusCode: res.statusCode,
          ));
        }
        return Result.ok(resp);
      }
      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  String? _extractTokenFromRaw(Map<String, dynamic> raw) {
    if (raw['token'] is String) return raw['token'] as String;
    if (raw['access_token'] is String) return raw['access_token'] as String;
    if (raw['accessToken'] is String) return raw['accessToken'] as String;

    final result = raw['result'];
    if (result is Map<String, dynamic>) {
      if (result['token'] is String) return result['token'] as String;
      if (result['access_token'] is String) return result['access_token'] as String;
      if (result['accessToken'] is String) return result['accessToken'] as String;
    }
    return null;
  }

  @override
  Future<Result<SignupResponse>> signup(SignupRequest req) async {
    final uri = Uri.parse(ApiConfig.signup);
    try {
      final res = await http
          .post(uri, headers: _jsonHeaders(), body: jsonEncode(req.toJson()))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final resp = SignupResponse.fromJson(parsed);
        if (!resp.isValid) {
          return Result.fail(Failure(
            code: 'validation',
            message: resp.message ?? 'Signup failed',
            statusCode: res.statusCode,
          ));
        }
        return Result.ok(resp);
      }

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  @override
  Future<Result<UserProfile>> fetchProfile({String? token}) async {
    final tok = token ?? await getSavedToken();
    if (tok == null || tok.isEmpty) {
      return Result.fail(const Failure(code: 'validation', message: 'No token available'));
    }

    final uri = Uri.parse(_profileUrl);
    final headers = {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $tok',
    };

    try {
      final res = await http.get(uri, headers: headers).timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        late final Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid JSON'));
        }

        final data = parsed['data'];
        if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
          final profile = UserProfile.fromJson(data.first as Map<String, dynamic>);
          return Result.ok(profile);
        }
        return Result.fail(const Failure(code: 'parse', message: 'Missing data array'));
      }

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }


  @override
Future<Result<List<ShopVendorModel>>> fetchNearbyShops({
  required double latitude,
  required double longitude,
}) async {
  try {
    final dio = Dio(
      BaseOptions(
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        validateStatus: (_) => true,
        responseType: ResponseType.plain,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    final url = ApiConfig.shopsUrl;
    print("LOCATION URL :: $url");
    print("LOCATION URL :: $url");
    print("LOCATION URL :: $url");

    // Your Postman shows GET with JSON body (non-standard).
    // Dio supports sending `data` in GET; backend must accept it.
    final res = await dio.get(
      url,
      data: {
        "latitude": latitude,
        "longitude": longitude,
      },
    );

    final status = res.statusCode ?? 0;

    if (status ==200) {
      final raw = res.data;
      print("API DATA $raw");
      print("API DATA $raw");

      dynamic decoded;
      if (raw is String) {
        decoded = jsonDecode(raw);
      } else {
        decoded = raw;
      }

      if (decoded is! List) {
        // sometimes backend wraps: {data:[...]} - handle both
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => ShopVendorModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return Result.ok(list);
        }

        return Result.fail(const Failure(
          code: 'parse',
          message: 'Invalid shops response format',
        ));
      }

      final list = decoded
          .whereType<Map>()
          .map((e) => ShopVendorModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      return Result.ok(list);
    }

    return Result.fail(Failure(
      code: 'server',
      message: 'Server error ($status)',
      statusCode: status,
    ));
  } on SocketException {
    return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
  } on TimeoutException {
    return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }}

@override
Future<Result<List<TyreRecord>>> fetchUserRecords({
  required String userId,
  required String vehicleType, // "car" | "bike"
  String vehicleId = "ALL",
}) async {
  try {
    final uid = userId.trim();
    final vType = vehicleType.trim().isEmpty ? "car" : vehicleType.trim();
    final vId = vehicleId.trim().isEmpty ? "ALL" : vehicleId.trim();

    if (uid.isEmpty) {
      return Result.fail(const Failure(
        code: "validation",
        message: "Missing user_id",
      ));
    }

    // ✅ token (consistent with your bloc)
    final box = GetStorage();
    final token =
        (box.read<String>('auth_token') ?? box.read<String>('token') ?? '').trim();

    final uri = Uri.parse(ApiConfig.fetchUserRecord).replace(
      queryParameters: {
        "vehicle_type": vType, // car/bike
        "user_id": uid,
        "vehicle_id": vId,
      },
    );

    final headers = <String, String>{
      ..._jsonHeaders(),
      if (token.isNotEmpty) HttpHeaders.authorizationHeader: "Bearer $token",
    };

    // ignore: avoid_print
    print("==[TYRE-HISTORY]=> GET $uri");
    // ignore: avoid_print
    print("Headers: {Accept: application/json, Content-Type: application/json"
        "${token.isNotEmpty ? ", Authorization: Bearer ****" : ""}}");

    final res = await http.get(uri, headers: headers).timeout(timeout);

    // ignore: avoid_print
    print("<= [TYRE-HISTORY] ${res.statusCode}");
    // ignore: avoid_print
    print("<= Body: ${res.body}");

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.trim().isEmpty) {
        return Result.ok(const <TyreRecord>[]);
      }

      final decoded = jsonDecode(res.body);

      if (decoded is! Map<String, dynamic>) {
        return Result.fail(const Failure(
          code: "parse",
          message: "Invalid response format (expected object)",
        ));
      }

      final raw = decoded["data"];
      if (raw is! List) {
        return Result.fail(const Failure(
          code: "parse",
          message: "Missing data list",
        ));
      }

      final list = raw
          .whereType<Map>()
          .map((e) => TyreRecord.fromApi(Map<String, dynamic>.from(e)))
          .toList();

      // ✅ latest first
      list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return Result.ok(list);
    }

    // ✅ show backend message if present
    String msg = "Server error (${res.statusCode})";
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed["message"] != null) {
        msg = parsed["message"].toString();
      } else if (parsed is Map && parsed["error"] != null) {
        msg = parsed["error"].toString();
      }
    } catch (_) {
      if (res.body.trim().isNotEmpty) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
    }

    return Result.fail(Failure(
      code: "server",
      message: msg,
      statusCode: res.statusCode,
    ));
  } on SocketException {
    return Result.fail(const Failure(
      code: "network",
      message: "No internet connection",
    ));
  } on TimeoutException {
    return Result.fail(const Failure(
      code: "timeout",
      message: "Request timed out",
    ));
  } on FormatException {
    return Result.fail(const Failure(
      code: "parse",
      message: "Invalid JSON response",
    ));
  } catch (e) {
    return Result.fail(Failure(code: "unknown", message: e.toString()));
  }
}


  @override
  Future<Result<VehiclePreferencesModel>> addVehiclePreferences({
    required String vehiclePreference,
    required String brandName,
    required String modelName,
    required String licensePlate,
    required bool? isOwn,
    required String tireBrand,
    required String tireDimension,
  }) async {
    final box = GetStorage();
    final tok = box.read<String>("token");

    if (tok == null || tok.isEmpty) {
      return Result.fail(const Failure(
        code: 'validation',
        message: 'No token available. Please login again.',
      ));
    }

    final uri = Uri.parse(ApiConfig.vehiclePreferences);

    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $tok',
    };

    final bodyArray = [
      {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "isOwn": isOwn,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
      }
    ];

    final bodyJson = jsonEncode(bodyArray);

    try {
      final res = await http
          .post(uri, headers: headers, body: bodyJson)
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final model = VehiclePreferencesModel.fromJson(parsed);
        return Result.ok(model);
      }

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }
}

class ApiConfig {
  static const String verifyEmail =
    "http://54.162.208.215/backend/api/verifyemail";

  static const login = 'http://54.162.208.215/backend/api/login';
  static const signup = 'http://54.162.208.215/backend/api/signup';
  static const String vehiclePreferences =
      'http://54.162.208.215/backend/api/addVehiclePreference';
  static const String fourWheelerUrl =
      'http://54.162.208.215/app/tyre/four_wheeler_upload/';
      
        static const String fetchUserRecord =
      'http://54.162.208.215/app/tyre/fetch_user_record/';
       static const String shopsUrl = 'http://54.162.208.215/backend/api/shops';
       static const String editProfile = "http://54.162.208.215/backend/api/userDetailsUpdate";
         static const String resetPassword =
      "http://54.162.208.215/backend/api/resetpassword";
      static const String getNotification =
    "http://54.162.208.215/backend/api/getNotification";
  static const String verifyOtp =
      "http://54.162.208.215/backend/api/verifyotp";
      static const String customAds = "http://54.162.208.215/backend/api/customads";

}

