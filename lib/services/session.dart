import 'dart:convert';

class UserSession {
  final int userId;
  final int dealerId;
  final int vendorId;
  final String email;
  final String name;
  final String? city;
  final String? district;
  final bool rememberMe;
  final int? partnerClientId;

  const UserSession({
    required this.userId,
    required this.dealerId,
    required this.vendorId,
    required this.email,
    required this.name,
    this.city,
    this.district,
    this.rememberMe = false,
    this.partnerClientId,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'dealerId': dealerId,
        'vendorId': vendorId,
        'email': email,
        'name': name,
        'city': city,
        'district': district,
        'rememberMe': rememberMe,
        'partnerClientId': partnerClientId,
      };

  factory UserSession.fromJson(Map<String, dynamic> m) => UserSession(
        userId: (m['userId'] is num)
            ? (m['userId'] as num).toInt()
            : (int.tryParse('${m['userId']}') ?? 0),
        dealerId: (m['dealerId'] is num)
            ? (m['dealerId'] as num).toInt()
            : (int.tryParse('${m['dealerId']}') ?? 0),
        vendorId: (m['vendorId'] is num)
            ? (m['vendorId'] as num).toInt()
            : (int.tryParse('${m['vendorId']}') ?? 0),
        email: (m['email'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        city: m['city'] as String?,
        district: m['district'] as String?,
        rememberMe: m['rememberMe'] == true,
        partnerClientId: (m['partnerClientId'] is num)
            ? (m['partnerClientId'] as num).toInt()
            : int.tryParse('${m['partnerClientId']}'),
      );

  UserSession copyWith({
    int? userId,
    int? dealerId,
    int? vendorId,
    String? email,
    String? name,
    String? city,
    String? district,
    bool? rememberMe,
    int? partnerClientId,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      dealerId: dealerId ?? this.dealerId,
      vendorId: vendorId ?? this.vendorId,
      email: email ?? this.email,
      name: name ?? this.name,
      city: city ?? this.city,
      district: district ?? this.district,
      rememberMe: rememberMe ?? this.rememberMe,
      partnerClientId: partnerClientId ?? this.partnerClientId,
    );
  }

  static int? _pickInt(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }

  static String? _pickStr(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.trim().isNotEmpty) return s;
    }
    return null;
  }

  /// Login yanıtı:
  /// - kökte {token, user:{...}}
  /// - veya {data:{token, user:{...}}}
  /// - veya user root olabilir
  static UserSession fromLoginResponse(
    dynamic payload, {
    String? emailFallback,
    String? nameFallback,
    bool rememberMe = false,
  }) {
    Map root = {};
    if (payload is Map) {
      root = payload;
      if (root['data'] is Map) root = root['data'];
    }

    Map user = {};
    if (root['user'] is Map) {
      user = root['user'];
    } else {
      user = root; // bazı backendler direk user döner
    }

    final userId = _pickInt(user, ['id', 'user_id']) ?? 0;

    // vendor_id yoksa userId fallback
    final vendorId = _pickInt(user, ['vendor_id', 'vendorId']) ?? userId;

    // dealer_id yoksa vendorId fallback (son çare userId)
    final dealerId = _pickInt(user, ['dealer_id', 'dealerId']) ?? vendorId;

    final email = _pickStr(user, ['email']) ?? (emailFallback ?? '');
    final name = _pickStr(user, ['name']) ?? (nameFallback ?? '');
    final city = _pickStr(user, ['city', 'il']);
    final district = _pickStr(user, ['district', 'ilce']);

    final partnerClientId =
        _pickInt(user, ['partner_client_id', 'partnerClientId']) ??
            _pickInt(root, ['partner_client_id', 'partnerClientId']);

    return UserSession(
      userId: userId,
      dealerId: dealerId,
      vendorId: vendorId,
      email: email,
      name: name,
      city: city,
      district: district,
      rememberMe: rememberMe,
      partnerClientId: partnerClientId,
    );
  }

  String toEncoded() => jsonEncode(toJson());
  factory UserSession.fromEncoded(String s) =>
      UserSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
