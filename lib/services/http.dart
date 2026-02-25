import 'package:dio/dio.dart';
import 'api_config.dart';

class Http {
  Http._();
  static final Http I = Http._();

  final Dio dio = Dio(BaseOptions(
    baseUrl: ApiConfig.v1.endsWith('/') ? ApiConfig.v1 : '${ApiConfig.v1}/',
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
    headers: {'Accept':'application/json','Content-Type':'application/json'},
  ));
}
