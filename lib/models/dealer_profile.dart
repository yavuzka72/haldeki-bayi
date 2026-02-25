class DealerProfile {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String userType;

  final int? dealerId;
  final int? vendorId;

  final int? cityId;
  final String? city;
  final String? district;
  final String? address;

  final double? latitude;
  final double? longitude;

  final bool isActive;
  final int? status;
  final String? statusText; // <-- Örn: "Aktif", "Pasif", "Onay bekliyor"

  final String? vehiclePlate;
  final String? iban;

  final double? commissionRate;
  final String? commissionType;

  final bool hasHadiAccount;

  final String? loginType;
  final String? appVersion;
  final String? appSource;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final DateTime? lastLocationUpdateAt;
  final DateTime? lastNotificationSeen;

  DealerProfile({
    required this.id,
    required this.name,
    required this.userType,
    this.email,
    this.phone,
    this.dealerId,
    this.vendorId,
    this.cityId,
    this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.isActive = false,
    this.status,
    this.statusText,
    this.vehiclePlate,
    this.iban,
    this.commissionRate,
    this.commissionType,
    this.hasHadiAccount = false,
    this.loginType,
    this.appVersion,
    this.appSource,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.lastLocationUpdateAt,
    this.lastNotificationSeen,
  });

  /// Bayi raporunda kullanacağımız efektif ID
  /// dealer_id varsa onu, yoksa kendi id'sini kullan.
  int get effectiveDealerId => dealerId ?? id;

  factory DealerProfile.fromJson(Map<String, dynamic> json) {
    int? _toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) {
        return int.tryParse(v);
      }
      return null;
    }

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    final rawUserType = (json['user_type'] ?? '') as String;
    final safeUserType = rawUserType.isEmpty ? 'client' : rawUserType;

    return DealerProfile(
      id: _toInt(json['id']) ?? 0,
      name: (json['name'] ?? '') as String,
      userType: safeUserType,
      email: json['email'] as String?,
      phone: json['phone'] as String?,

      // 🔴 BURAYI DÜZELTTİK
      dealerId: _toInt(json['dealer_id']),
      vendorId: _toInt(json['vendor_id']),
      cityId: _toInt(json['city_id']),

      city: json['city'] as String?,
      district: json['district'] as String?,
      address: json['address'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isActive: (json['is_active'] ?? false) == true || json['is_active'] == 1,

      status: _toInt(json['status']),
      statusText: json['status_text'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      iban: json['iban'] as String?,
      commissionRate: _toDouble(json['commission_rate']),
      commissionType: json['commission_type'] as String?,
      hasHadiAccount: (json['has_hadi_account'] ?? false) == true ||
          json['has_hadi_account'] == 1,
      loginType: json['login_type'] as String?,
      appVersion: json['app_version'] as String?,
      appSource: json['app_source'] as String?,
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
      lastLoginAt: _toDate(json['last_login_at']),
      lastLocationUpdateAt: _toDate(json['last_location_update_at']),
      lastNotificationSeen: _toDate(json['last_notification_seen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'user_type': userType,
      'email': email,
      'phone': phone,
      'dealer_id': dealerId,
      'vendor_id': vendorId,
      'city_id': cityId,
      'city': city,
      'district': district,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'status': status,
      'status_text': statusText,
      'vehicle_plate': vehiclePlate,
      'iban': iban,
      'commission_rate': commissionRate,
      'commission_type': commissionType,
      'has_hadi_account': hasHadiAccount,
      'login_type': loginType,
      'app_version': appVersion,
      'app_source': appSource,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'last_location_update_at': lastLocationUpdateAt?.toIso8601String(),
      'last_notification_seen': lastNotificationSeen?.toIso8601String(),
    };
  }
}
