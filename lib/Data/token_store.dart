import 'package:get_storage/get_storage.dart';

class TokenStore {
  static const _kToken = 'auth_token';
  final GetStorage _box = GetStorage();

  Future<void> save(String token) async => _box.write(_kToken, token);
  Future<String?> read() async {
    final v = _box.read<String>(_kToken);
    return (v == null || v.trim().isEmpty) ? null : v;
  }
  Future<void> clear() async => _box.remove(_kToken);
  String? readSync() {
    final v = _box.read<String>(_kToken);
    return (v == null || v.trim().isEmpty) ? null : v;
  }
}
