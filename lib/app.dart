import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:haldeki_admin_web/theme/brand_theme.dart';
import 'theme/app_theme.dart';
import 'router.dart';


class HaldekiApp extends StatelessWidget {
  const HaldekiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.build();
  return MaterialApp.router(
  debugShowCheckedModeBanner: false,
  title: 'Haldeki Bayi',
// theme: AppTheme.lightTheme(context),

      theme: lightTheme(),
      darkTheme: lightTheme(),
      themeMode: ThemeMode.system,


  routerConfig: router,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('tr'),
    Locale('en'),
  ],
  locale: const Locale('tr'),
);
  }
}
