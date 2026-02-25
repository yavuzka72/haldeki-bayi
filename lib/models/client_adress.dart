// lib/models/client_address.dart
class ClientAddress {
  final int id;
  final String title;
  final String contactName;
  final String contactPhone;
  final String address;
  final String? city;
  final String? district;

  // Ek alanlar (Laravel tarafında mevcut/işe yarar)
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final int? countryId;
  final int? cityId;
  final bool isDefault;

  const ClientAddress({
    required this.id,
    required this.title,
    required this.contactName,
    required this.contactPhone,
    required this.address,
    this.city,
    this.district,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.countryId,
    this.cityId,
    this.isDefault = false,
  });

  // --- küçük yardımcılar ---
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (['1', 'true', 'yes', 'evet', 'açık', 'open'].contains(s)) return true;
      if (['0', 'false', 'no', 'hayır', 'kapalı', 'closed'].contains(s)) {
        return false;
      }
    }
    return fallback;
  }

  static String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  factory ClientAddress.fromJson(Map<String, dynamic> j) {
    // Bazı API'ler { data: {...} } sarımı yapabilir
    final m = (j['data'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(j['data'] as Map)
        : j;

    return ClientAddress(
      id: _asInt(m['id']),
      title: _asString(
        m['title'] ?? m['name'],
        fallback: 'Adres',
      ),
      contactName: _asString(m['contact_name'] ?? m['contactName']),
      contactPhone: _asString(m['contact_phone'] ?? m['contactPhone']),
      address: _asString(m['address']),
      city: _asString(m['city'], fallback: '').isEmpty
          ? null
          : _asString(m['city']),
      district: _asString(m['district'], fallback: '').isEmpty
          ? null
          : _asString(m['district']),
      postalCode:
          _asString(m['postal_code'] ?? m['postalCode'], fallback: '').isEmpty
              ? null
              : _asString(m['postal_code'] ?? m['postalCode']),
      latitude: _asDoubleOrNull(m['latitude']),
      longitude: _asDoubleOrNull(m['longitude']),
      countryId: (m['country_id'] != null) ? _asInt(m['country_id']) : null,
      cityId: (m['city_id'] != null) ? _asInt(m['city_id']) : null,
      isDefault: _asBool(m['is_default']),
    );
  }

  Map<String, dynamic> toJson() => {
        // id'yi genelde POST/PUT’ta göndermeyiz; ihtiyaca göre ekleyebilirsin
        'title': title,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'address': address,
        'city': city,
        'district': district,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'country_id': countryId,
        'city_id': cityId,
        'is_default': isDefault ? 1 : 0,
      };

  ClientAddress copyWith({
    int? id,
    String? title,
    String? contactName,
    String? contactPhone,
    String? address,
    String? city,
    String? district,
    String? postalCode,
    double? latitude,
    double? longitude,
    int? countryId,
    int? cityId,
    bool? isDefault,
  }) {
    return ClientAddress(
      id: id ?? this.id,
      title: title ?? this.title,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      countryId: countryId ?? this.countryId,
      cityId: cityId ?? this.cityId,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() =>
      'ClientAddress(id: $id, title: $title, city: $city, district: $district)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientAddress &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          contactName == other.contactName &&
          contactPhone == other.contactPhone &&
          address == other.address &&
          city == other.city &&
          district == other.district &&
          postalCode == other.postalCode &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          countryId == other.countryId &&
          cityId == other.cityId &&
          isDefault == other.isDefault;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      contactName.hashCode ^
      contactPhone.hashCode ^
      address.hashCode ^
      city.hashCode ^
      district.hashCode ^
      (postalCode?.hashCode ?? 0) ^
      (latitude?.hashCode ?? 0) ^
      (longitude?.hashCode ?? 0) ^
      (countryId?.hashCode ?? 0) ^
      (cityId?.hashCode ?? 0) ^
      isDefault.hashCode;
}

extension ClientAddressPartnerBody on ClientAddress {
  /// PartnerClient update endpoint'ine gidecek body
  /// Route: POST /api/partner/v1/partner-clients/{id}
  Map<String, dynamic> toPartnerClientUpdateBody() => {
        'address': address,
        'city': city,
        'district': district,

        'latitude': latitude,
        'longitude': longitude,

        // bazı backendlerde gerekiyor olabilir (senin partner-clients create payload'ında var)
        'country_id': countryId,
        'city_id': cityId,
        'location_lat': latitude,
        'location_lng': longitude,
      }..removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
}
