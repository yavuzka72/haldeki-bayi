// lib/screens/login_screen.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'package:haldeki_admin_web/utils/message_dialog.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import 'haldeki_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = true;
  bool _capsOn = false;

  // ✅ Logo path tek yerden
  static const String kLogoAsset = 'assets/haldeki_logo.png';

  // ---- PRIMARY UI COLORS (Purple + Gray + Orange) ----
  static const Color kPurple = Color(0xFF0D4631);
  static const Color kPurple2 = Color(0xFF0D4631);
  static const Color kOrange = Color(0xFFff23cc);

  static const Color kBg = Color(0xFFF6F7FB);
  static const Color kBorder = Color(0xFFE6E8EF);
  static const Color kText = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _capsOn = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _validEmail(String v) {
    final s = v.trim();
    if (!s.contains('@')) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  Future<void> _submit() async {
    final formState = _form.currentState;
    if (formState == null) return;

    final ok = formState.validate();
    if (!ok || _loading) return;

    setState(() => _loading = true);

    final api = context.read<ApiClient>();

    try {
      final email = _email.text.trim();
      final password = _password.text;

      // 1) Login isteği
      final res = await api.login(email, password);
      final data = res.data;

      if (data is! Map) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Sunucudan beklenmeyen yanıt alındı.',
        );
      }

      // 2) Token yakala
      final token = (data['token'] ??
              data['access_token'] ??
              (data['data'] is Map ? data['data']['token'] : null))
          ?.toString();

      if (token == null || token.isEmpty) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Token alınamadı',
        );
      }

      // 3) (Opsiyonel) kullanıcı
      final rawUser = (data['user'] ??
          (data['data'] is Map ? data['data']['user'] : null) ??
          data['data']);
      Map<String, dynamic>? user;
      if (rawUser is Map) user = Map<String, dynamic>.from(rawUser);

      // 4) ApiClient token
      await api.setToken(token);

      // 5) Session
      /*     final session = UserSession.fromLoginResponse(
        data,
        emailFallback: email,
      ).copyWith(rememberMe: _rememberMe);

      await api.setSession(session);
      */

// 5) Session
      final session = UserSession.fromLoginResponse(
        data,
        emailFallback: email,
        rememberMe: _rememberMe, // ✅ buraya ver
      );

// persist
      await api.setSession(session);

      // Debug istersen:
      // print('Login OK => userId=${api.currentUserId}, email=${api.currentEmail}, user=${user?['id']}');

      if (!mounted) return;
      context.go('/dashboard');
    } on DioException catch (e) {
      if (!mounted) return;

      final msg = e.response?.data is Map && e.response!.data['message'] != null
          ? e.response!.data['message'].toString()
          : (e.message ?? 'Giriş başarısız.');

      showMessageDialog(
        context,
        title: 'Giriş Hatası',
        message: msg,
        type: MessageType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showMessageDialog(
        context,
        title: 'Hata',
        message: 'Beklenmeyen bir hata oluştu.',
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submiww() async {
    final formState = _form.currentState;
    if (formState == null) return;

    final ok = formState.validate();
    if (!ok || _loading) return;

    setState(() => _loading = true);

    final api = context.read<ApiClient>();

    try {
      final email = _email.text.trim();
      final password = _password.text;

      final res = await api.login(email, password);
      final data = res.data;

      if (data is! Map) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Sunucudan beklenmeyen yanıt alındı.',
        );
      }

      final token = (data['token'] ??
              data['access_token'] ??
              (data['data'] is Map ? data['data']['token'] : null))
          ?.toString();

      if (token == null || token.isEmpty) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Token alınamadı',
        );
      }

      // token header set
      await api.setToken(token);

      // session save
      final session = UserSession.fromLoginResponse(
        data,
        emailFallback: email,
      ).copyWith(rememberMe: _rememberMe);

      await api.setSession(session);

      if (!mounted) return;
      context.go('/collection-report-screen');
    } on DioException catch (e) {
      if (!mounted) return;

      final msg = e.response?.data is Map && e.response!.data['message'] != null
          ? e.response!.data['message'].toString()
          : (e.message ?? 'Giriş başarısız.');

      showMessageDialog(
        context,
        title: 'Giriş Hatası',
        message: msg,
        type: MessageType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showMessageDialog(
        context,
        title: 'Hata',
        message: 'Beklenmeyen bir hata oluştu.',
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onKeyRaw(RawKeyEvent e) {
    // Caps lock detect
    final locked = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
    if (_capsOn != locked) setState(() => _capsOn = locked);

    // Enter => submit
    if (e is RawKeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.enter &&
        !_loading) {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    final cs = base.colorScheme.copyWith(
      primary: kPurple,
      secondary: kPurple2,
      tertiary: kOrange,
      background: kBg,
      surface: Colors.white,
      outline: kBorder,
      outlineVariant: kBorder,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: kText,
      onSurfaceVariant: kMuted,
    );

    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: kBg,
      inputDecorationTheme: HaldekiUI.inputDense(context),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        body: RawKeyboardListener(
          autofocus: true,
          focusNode: FocusNode(),
          onKey: _onKeyRaw,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 980;
              final padX = wide ? 36.0 : 20.0;

              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Background gradient
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF6F7FB),
                            Color(0xFFF1F5F9),
                            Color(0xFFFFFFFF),
                          ],
                        ),
                      ),
                    ),

                    // --- Blobs
                    const _Blob(
                      top: -90,
                      left: -70,
                      size: 280,
                      color: Color(0x336D28D9), // purple
                    ),
                    const _Blob(
                      bottom: -70,
                      right: -50,
                      size: 250,
                      color: Color(0x33F59E0B), // orange
                    ),
                    const _Blob(
                      top: 140,
                      right: -60,
                      size: 170,
                      color: Color(0x267C3AED), // purple2
                    ),

                    // --- Centered glass card
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.72),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: kBorder.withOpacity(.90),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(18),
                              child: SizedBox(
                                height: wide ? 500 : null,
                                child: Row(
                                  children: [
                                    if (wide)
                                      const Expanded(child: _BrandPanel()),
                                    if (wide)
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: cs.outlineVariant,
                                      ),

                                    // ----- Right: Form
                                    Expanded(
                                      child: AbsorbPointer(
                                        absorbing: _loading,
                                        child: Stack(
                                          children: [
                                            SingleChildScrollView(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: padX,
                                                vertical: 22,
                                              ),
                                              child: Form(
                                                key: _form,
                                                child: AutofillGroup(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      if (!wide) ...[
                                                        const SizedBox(
                                                            height: 4),
                                                        const _WordmarkInline(),
                                                        const SizedBox(
                                                            height: 18),
                                                      ],
                                                      Text(
                                                        'Hesabınıza giriş yapın',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleLarge
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'E-posta ve şifrenizle devam edin.',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color: cs
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                          height: 22),

                                                      // Email
                                                      TextFormField(
                                                        controller: _email,
                                                        focusNode: _emailFocus,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText: 'E-posta',
                                                          prefixIcon: Icon(
                                                            Icons
                                                                .mail_outline_rounded,
                                                            size: 20,
                                                          ),
                                                        ),
                                                        keyboardType:
                                                            TextInputType
                                                                .emailAddress,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        autofillHints: const [
                                                          AutofillHints
                                                              .username,
                                                          AutofillHints.email,
                                                        ],
                                                        validator: (v) => (v ==
                                                                    null ||
                                                                !_validEmail(v))
                                                            ? 'Geçerli bir e-posta girin'
                                                            : null,
                                                        onFieldSubmitted: (_) =>
                                                            _passFocus
                                                                .requestFocus(),
                                                      ),
                                                      const SizedBox(
                                                          height: 12),

                                                      // Password
                                                      TextFormField(
                                                        controller: _password,
                                                        focusNode: _passFocus,
                                                        obscureText: _obscure,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText: 'Şifre',
                                                          prefixIcon:
                                                              const Icon(
                                                            Icons
                                                                .lock_outline_rounded,
                                                            size: 20,
                                                          ),
                                                          suffixIcon:
                                                              IconButton(
                                                            onPressed: () =>
                                                                setState(
                                                              () => _obscure =
                                                                  !_obscure,
                                                            ),
                                                            icon: Icon(
                                                              _obscure
                                                                  ? Icons
                                                                      .visibility_outlined
                                                                  : Icons
                                                                      .visibility_off_outlined,
                                                            ),
                                                          ),
                                                        ),
                                                        autofillHints: const [
                                                          AutofillHints.password
                                                        ],
                                                        textInputAction:
                                                            TextInputAction
                                                                .done,
                                                        onFieldSubmitted: (_) =>
                                                            _submit(),
                                                        validator: (v) => (v ==
                                                                    null ||
                                                                v.length < 4)
                                                            ? 'Şifre çok kısa'
                                                            : null,
                                                      ),

                                                      // Caps Lock
                                                      if (_capsOn &&
                                                          _passFocus.hasFocus)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 6),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .keyboard_capslock,
                                                                size: 16,
                                                              ),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                'Caps Lock açık olabilir',
                                                                style: TextStyle(
                                                                    color: cs
                                                                        .tertiary),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                      const SizedBox(
                                                          height: 10),

                                                      Row(
                                                        children: [
                                                          Checkbox.adaptive(
                                                            value: _rememberMe,
                                                            onChanged: (v) =>
                                                                setState(
                                                              () =>
                                                                  _rememberMe =
                                                                      v ?? true,
                                                            ),
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                          ),
                                                          const SizedBox(
                                                              width: 6),
                                                          const Text(
                                                              'Beni hatırla'),
                                                          const Spacer(),
                                                          TextButton(
                                                            onPressed: _loading
                                                                ? null
                                                                : () {
                                                                    // TODO: şifremi unuttum akışı
                                                                  },
                                                            child: const Text(
                                                                'Şifremi unuttum'),
                                                          ),
                                                        ],
                                                      ),

                                                      const SizedBox(height: 8),

                                                      // Login button
                                                      SizedBox(
                                                        height: 48,
                                                        child: FilledButton(
                                                          onPressed: _loading
                                                              ? null
                                                              : _submit,
                                                          child: _loading
                                                              ? const SizedBox(
                                                                  height: 20,
                                                                  width: 20,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                )
                                                              : const Text(
                                                                  'Giriş'),
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                          height: 10),

                                                      // Guest
                                                      /*       SizedBox(
                                                        height: 46,
                                                        child:
                                                            OutlinedButton.icon(
                                                          icon: const Icon(
                                                            Icons
                                                                .explore_outlined,
                                                            size: 18,
                                                          ),
                                                          onPressed: _loading
                                                              ? null
                                                              : () =>
                                                                  context.go(
                                                                    '/collection-report-screen',
                                                                  ),
                                                          label: const Text(
                                                              'Misafir olarak devam et'),
                                                        ),
                                                      ),
*/
                                                      const SizedBox(
                                                          height: 14),
                                                      Text(
                                                        'Giriş yaparak koşulları kabul etmiş olursunuz.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: cs
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Loading overlay
                                            if (_loading)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: cs.surface
                                                          .withOpacity(.35),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Sol panel – sadece logo (wide ekranda)
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const String kLogoAsset = _LoginScreenState.kLogoAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(.70)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Image.asset(
            kLogoAsset,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Dar ekranda wordmark
class _WordmarkInline extends StatelessWidget {
  const _WordmarkInline();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withOpacity(.12),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.storefront_rounded, color: cs.primary),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (r) =>
              LinearGradient(colors: [cs.primary, cs.tertiary]).createShader(r),
          child: Text(
            'Haldeki Bayii Paneli',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
}

/// Arka plan dekoratif blob
class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top, left, right, bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}
