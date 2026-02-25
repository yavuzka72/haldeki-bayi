import 'courier_models.dart';

class CourierRepository {
  CourierRepository._();
  static final instance = CourierRepository._();

  final Map<int, CourierLite> _cache = {};

  void seed(List<CourierLite> list) {
    for (final c in list) {
      _cache[c.id] = c;
    }
  }

  CourierLite? getById(int id) => _cache[id];
}
