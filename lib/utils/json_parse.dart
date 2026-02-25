// lib/utils/json_parse.dart

String asString(dynamic v, {String fallback = ''}) => v?.toString() ?? fallback;

double asDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.replaceAll('₺', '').replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(s) ?? fallback;
  }
  return fallback;
}

int asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) {
    // saniye/ms heuristics
    return v > 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal()
        : DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
  }
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  return null;
}
