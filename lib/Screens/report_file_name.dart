import 'package:intl/intl.dart';

String buildTyreReportFileName({
  required String vehicleType, // car/bike
  required int recordId,
  DateTime? uploadedAt,
}) {
  final vt = vehicleType.toLowerCase().trim();
  final dt = DateFormat('yyyyMMdd_HHmm').format(uploadedAt ?? DateTime.now());

  // ✅ braces prevent "rid_" type bugs forever
  return 'tyre_report_${vt}_${recordId}_$dt.pdf';
}

/// If API gives timestamp as int/string, parse safely:
DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;

  // ISO string
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();

    // numeric string
    final n = int.tryParse(s);
    if (n != null) return _fromEpochSmart(n);
    return null;
  }

  if (value is int) return _fromEpochSmart(value);

  return null;
}

DateTime? _fromEpochSmart(int n) {
  // seconds vs milliseconds
  // seconds are usually 10 digits; ms are 13 digits
  if (n <= 0) return null;
  if (n < 1000000000000) {
    // seconds
    return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toLocal();
  }
  // milliseconds
  return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
}