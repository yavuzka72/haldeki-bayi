class ApiConfig {
  /// iOS Sim:https://api.haldeki.com/
  /// Android Emu: http://10.0.2.2:8000
  /// Prod:https://api.haldeki.com/
  static String base =
      'https://api.haldeki.com'; //'https://api.haldeki.com/'; // değiştirilebilir
  static String get v1 => '$base/api/v1';
}
