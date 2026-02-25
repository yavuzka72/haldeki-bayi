// lib/main.dart
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // web: # kaldırma
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'models/cart.dart'; // <-- Cart için

/// ✅ Web'de mouse/trackpad ile sürükleyerek (drag) scroll'u aktif eder
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TR yerelleştirme
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR', null);

  // Web'de hash (#) kaldır — sunucuda SPA rewrite şart
  try {
    setUrlStrategy(PathUrlStrategy());
  } catch (_) {}

  // API istemcisi
  final api = ApiClient();
  await api.init();

  runApp(
    MultiProvider(
      providers: [
        // ApiClient'ı tüm app'e ver
        Provider<ApiClient>.value(value: api),

        // Cart: singleton kullanıyorsan .value; değilse create: (_) => Cart()
        ChangeNotifierProvider<Cart>.value(value: Cart.I),
      ],
      child: const HaldekiApp(),
    ),
  );
}

void main() {
  runZonedGuarded(() {
    _bootstrap();
  }, (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  });
}
