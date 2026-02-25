// lib/widgets/shell_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haldeki_admin_web/screens/Product/market_screen.dart';
import 'package:haldeki_admin_web/screens/dashboard_screen.dart';
import 'package:haldeki_admin_web/screens/ops_map_screen.dart';
import 'package:haldeki_admin_web/screens/orders_screen.dart';
import 'package:haldeki_admin_web/screens/product_dashboard_screen.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../services/api_client.dart';

class KClientsColors {
  // Brand (Haldeki yeşili)
  static const purple = Color(0xFF0D4631);
  static const purple2 = Color(0xFF0D4631);
  static const orange = Color(0xFFff23cc);

  // Neutral
  static const bg = Color(0xFFF6F7FB);
  static const card = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF8FAFC);
  static const line = Color(0xFFE6E8EF);

  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // Status
  static const passive = Color(0xFF475569);
}

class ShellScaffold extends StatefulWidget {
  final Widget child;

  /// Mobil alt bar index (0..5)
  final int currentIndex;

  /// Badge sayaçları
  final int activeOrdersCount; // /orders
  final int handedOverCount; // /delivery-orders

  /// AppBar bilgileri (opsiyonel)
  final String? userName;

  const ShellScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    this.activeOrdersCount = 0,
    this.handedOverCount = 0,
    this.userName,
  });

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  bool _ordersExpanded = false;
  bool _reportsExpanded = false;

  // ---- Güvenli sepet satır sayısı ----
  int _safeLineCount(dynamic cart) {
    try {
      if (cart == null) return 0;
      final lines = (cart as dynamic).lines;
      if (lines is List) return lines.length;
      if (lines is int) return lines;
      final lc = (cart as dynamic).lineCount;
      if (lc is int) return lc;
    } catch (_) {}
    return 0;
  }

  // ---- Path güvenli okuma ----
  String _safeCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      try {
        final loc = GoRouterState.of(context).matchedLocation;
        if (loc.isNotEmpty) return Uri.parse(loc).path;
      } catch (_) {
        try {
          final info = GoRouter.of(context).routeInformationProvider.value;
          final loc = info.location;
          if (loc != null) return Uri.parse(loc).path;
        } catch (_) {}
      }
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1000;

    final cart = context.watch<Cart>();
    final lineCount = _safeLineCount(cart);

    final api = context.watch<ApiClient>();
    final profile = api.currentProfile;

    final profilemail = api.currentEmail;
    final profilName = api.currentName;

    final upperName = ((profilName ?? widget.userName ?? '')).toUpperCase();
    final email = profilemail ?? '';

    // "/" gelirse dashboard'a
    final currentPath = _safeCurrentPath(context);
    if (currentPath == '/' || currentPath.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
    }

    final ordersOpen = _ordersExpanded ||
        currentPath.startsWith('/orders') ||
        currentPath.startsWith('/delivery-orders');

    final reportsOpen = _reportsExpanded ||
        currentPath.startsWith('/reports') ||
        currentPath == '/product-dashboard' ||
        currentPath == '/client-dashboard';

    return Scaffold(
      backgroundColor: KClientsColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: _TopBarLight(
          title: 'Haldeki Bayi',
          businessName: upperName,
          businessEmail: email,
          onLogout: () async {
            try {
              await api.logout();
            } catch (_) {}
            if (!mounted) return;
            context.go('/login');
          },
        ),
      ),
      body: Row(
        children: [
          if (isWide)
            _SidebarLikeScreenshot(
              currentPath: currentPath,
              ordersOpen: ordersOpen,
              reportsOpen: reportsOpen,
              activeOrdersCount: widget.activeOrdersCount,
              handedOverCount: widget.handedOverCount,
              onToggleOrders: () =>
                  setState(() => _ordersExpanded = !_ordersExpanded),
              onToggleReports: () =>
                  setState(() => _reportsExpanded = !_reportsExpanded),
              onGo: (r) => context.go(r),
            ),
          if (isWide) _buildVerticalDivider(),
          Expanded(
            child: Container(
              color: KClientsColors.bg,
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? _buildStatusBar(context)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusBar(context),
                Theme(
                  data: Theme.of(context).copyWith(
                    navigationBarTheme: NavigationBarThemeData(
                      backgroundColor: KClientsColors.card,
                      indicatorColor: KClientsColors.purple.withOpacity(.12),
                      labelTextStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: KClientsColors.text,
                        ),
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: widget.currentIndex.clamp(0, 5),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_customize_outlined),
                        selectedIcon: Icon(Icons.dashboard_customize),
                        label: 'Operasyon',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.store_mall_directory_outlined),
                        selectedIcon: Icon(Icons.store_mall_directory),
                        label: 'Market',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.shopping_cart_outlined),
                        selectedIcon: Icon(Icons.shopping_cart),
                        label: 'Sepet',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'Siparişler',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_circle_outlined),
                        selectedIcon: Icon(Icons.account_circle),
                        label: 'Profil',
                      ),
                    ],
                    onDestinationSelected: (i) {
                      switch (i) {
                        case 0:
                          GoRoute(
                            path: '/dashboard',
                            pageBuilder: (context, state) {
                              return CustomTransitionPage(
                                key: state.pageKey,
                                child: const DashboardScreen(),
                                transitionDuration:
                                    const Duration(milliseconds: 250),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                          break;
                        case 1:
                          GoRoute(
                            path: '/operasyon',
                            pageBuilder: (context, state) {
                              return CustomTransitionPage(
                                key: state.pageKey,
                                child: const OpsMapScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                          break;
                        case 2:
                          GoRoute(
                            path: '/products',
                            pageBuilder: (context, state) {
                              return CustomTransitionPage(
                                key: state.pageKey,
                                child: const MarketScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                          break;
                        case 3:
                          context.go('/cart');
                          break;
                        case 4:
                          GoRoute(
                            path: '/orders',
                            pageBuilder: (context, state) {
                              return CustomTransitionPage(
                                key: state.pageKey,
                                child: const OrdersScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                          break;
                        case 5:
                          context.go('/profile');
                          break;
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: double.infinity,
      color: KClientsColors.line,
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final api = context.watch<ApiClient>();
    final p = api.currentProfile;

    final rawName = (p?.name ?? widget.userName ?? 'A BAYİ');
    final name = rawName.toUpperCase();

    final city = (p?.city ?? '').trim().toUpperCase();
    final district = (p?.district ?? '').trim().toUpperCase();
    final addr = (p?.address ?? '').trim();

    final locParts = <String>[];
    if (city.isNotEmpty) locParts.add(city);
    if (district.isNotEmpty) locParts.add(district);
    final locPart = locParts.join(' / ');

    String addressLine;
    if (locPart.isEmpty) {
      addressLine = addr;
    } else if (addr.isEmpty) {
      addressLine = locPart;
    } else {
      addressLine = '$locPart, $addr';
    }

    final text = addressLine.trim().isEmpty ? name : '$name — $addressLine';

    return Material(
      color: KClientsColors.card,
      child: SafeArea(
        top: false,
        child: Container(
          height: 30,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: KClientsColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.person, size: 16, color: KClientsColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: KClientsColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
//  SIDEBAR (BİREBİR RESİM GİBİ)
// =====================================================
// =====================================================
//  PREMIUM SIDEBAR
// =====================================================
class _SidebarLikeScreenshot extends StatelessWidget {
  const _SidebarLikeScreenshot({
    required this.currentPath,
    required this.ordersOpen,
    required this.reportsOpen,
    required this.activeOrdersCount,
    required this.handedOverCount,
    required this.onToggleOrders,
    required this.onToggleReports,
    required this.onGo,
  });

  final String currentPath;
  final bool ordersOpen;
  final bool reportsOpen;

  final int activeOrdersCount;
  final int handedOverCount;

  final VoidCallback onToggleOrders;
  final VoidCallback onToggleReports;
  final ValueChanged<String> onGo;

  bool _isSelected(String route) {
    if (route == '/orders') {
      return currentPath == '/orders' || currentPath.startsWith('/orders/');
    }
    if (route == '/delivery-orders') {
      return currentPath.startsWith('/delivery-orders');
    }
    if (route == '/customers') {
      return currentPath.startsWith('/customers');
    }
    if (route == '/couriers') {
      return currentPath.startsWith('/couriers');
    }
    if (route == '/products') {
      return currentPath.startsWith('/products');
    }
    if (route == '/reports') {
      return currentPath.startsWith('/reports') ||
          currentPath == '/product-dashboard' ||
          currentPath == '/client-dashboard';
    }
    return currentPath == route || currentPath.startsWith('$route/');
  }

  @override
  Widget build(BuildContext context) {
    final inOrders = currentPath.startsWith('/orders') ||
        currentPath.startsWith('/delivery-orders');

    return SizedBox(
      width: 280,
      child: Material(
        color: const Color(0xFFF9FAFB),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _RailHeaderLight(
                title: 'haldeki.com',
                logoAsset: 'assets/logo/haldeki_logo_icon.png',
              ),
              const Divider(height: 1, color: KClientsColors.line),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    _tile(
                      icon: Icons.grid_view_rounded,
                      label: 'Ana Sayfa',
                      selected: _isSelected('/dashboard'),
                      onTap: () => onGo('/dashboard'),
                    ),
                    _tile(
                      icon: Icons.dashboard_customize_outlined,
                      label: 'Operasyon',
                      selected: _isSelected('/operasyon'),
                      onTap: () => onGo('/operasyon'),
                    ),
                    _groupTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Siparişler',
                      expanded: ordersOpen,
                      selected: inOrders,
                      onTap: onToggleOrders,
                    ),
                    if (ordersOpen) ...[
                      _subTile(
                        label: 'Aktif Siparişler',
                        selected: _isSelected('/orders'),
                        badge: activeOrdersCount,
                        onTap: () => onGo('/orders'),
                      ),
                      _subTile(
                        label: 'Kuryeye Aktarılan',
                        selected: _isSelected('/delivery-orders'),
                        badge: handedOverCount,
                        onTap: () => onGo('/delivery-orders'),
                      ),
                    ],
                    _tile(
                      icon: Icons.people_outline,
                      label: 'İşletmeler',
                      selected: _isSelected('/customers'),
                      onTap: () => onGo('/customers'),
                    ),
                    /*  _tile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Ürünler',
                      selected: _isSelected('/products'),
                      onTap: () => onGo('/products'),
                    ),*/
                    _tile(
                      icon: Icons.delivery_dining_outlined,
                      label: 'Kuryeler',
                      selected: _isSelected('/couriers'),
                      onTap: () => onGo('/couriers'),
                    ),
                    _tile(
                      icon: Icons.point_of_sale_outlined,
                      label: 'Kasa',
                      selected: _isSelected('/cash'),
                      onTap: () => onGo('/cash'),
                    ),
                    _groupTile(
                      icon: Icons.insert_chart_outlined,
                      label: 'Raporlar',
                      expanded: reportsOpen,
                      selected: _isSelected('/reports'),
                      onTap: onToggleReports,
                    ),
                    if (reportsOpen) ...[
                      _dotTile(
                        label: 'Kasa Raporu',
                        selected: _isSelected('/cash'),
                        onTap: () => onGo('/cash'),
                      ),
                      _dotTile(
                        label: 'İşletme Raporu',
                        selected: _isSelected('/reports/customers'),
                        onTap: () => onGo('/reports/customers'),
                      ),
                      _dotTile(
                        label: 'Kurye Raporu',
                        selected: _isSelected('/reports/couriers'),
                        onTap: () => onGo('/reports/couriers'),
                      ),
                      _dotTile(
                        label: 'Ürün Raporu',
                        selected: _isSelected('/product-dashboard'),
                        onTap: () => onGo('/product-dashboard'),
                      ),
                      _dotTile(
                        label: 'İşletme Ürün Raporu',
                        selected: _isSelected('/client-dashboard'),
                        onTap: () => onGo('/client-dashboard'),
                      ),
                    ],
                    _tile(
                      icon: Icons.account_circle_outlined,
                      label: 'Profil',
                      selected: _isSelected('/profile'),
                      onTap: () => onGo('/profile'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  //  PREMIUM TILE
  // --------------------------------------------------
  Widget _tile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _HoverTile(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Icon(
              icon,
              size: 22,
              color: selected ? KClientsColors.purple : KClientsColors.muted,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? KClientsColors.purple : KClientsColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTile({
    required IconData icon,
    required String label,
    required bool expanded,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _HoverTile(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Icon(
              icon,
              size: 22,
              color: selected ? KClientsColors.purple : KClientsColors.muted,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? KClientsColors.purple : KClientsColors.text,
              ),
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(Icons.expand_more, size: 18),
          )
        ],
      ),
    );
  }

  Widget _subTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: _HoverTile(
        selected: selected,
        onTap: onTap,
        child: Row(
          children: [
            if (badge > 0)
              _BadgeIcon(
                count: badge,
                child: Icon(Icons.receipt_long,
                    size: 18,
                    color: selected
                        ? KClientsColors.purple
                        : KClientsColors.muted),
              )
            else
              Icon(Icons.receipt_long,
                  size: 18,
                  color:
                      selected ? KClientsColors.purple : KClientsColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? KClientsColors.purple : KClientsColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: _HoverTile(
        selected: selected,
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 8,
                color: selected ? KClientsColors.purple : KClientsColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? KClientsColors.purple : KClientsColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
//  HOVER TILE CORE
// --------------------------------------------------
class _HoverTile extends StatefulWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  const _HoverTile({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? KClientsColors.purple.withOpacity(.08)
        : hovered
            ? Colors.black.withOpacity(.03)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                width: 3,
                color: widget.selected
                    ? KClientsColors.purple
                    : Colors.transparent,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// =====================================================
//  HEADER (LOGO + haldeki.com + BAYİ PANEL) - seninle aynı
// =====================================================
class _RailHeaderLight extends StatelessWidget {
  const _RailHeaderLight({required this.title, this.logoAsset});
  final String title;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: logoAsset == null
                  ? const SizedBox.shrink()
                  : Image.asset(
                      logoAsset!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KClientsColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KClientsColors.purple.withOpacity(.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: KClientsColors.purple.withOpacity(.25),
              ),
            ),
            child: const Text(
              'BAYİ PANEL',
              style: TextStyle(
                color: KClientsColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: .6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Basit badge (palette uyumlu)
class _BadgeIcon extends StatelessWidget {
  final int count;
  final Widget child;
  const _BadgeIcon({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -7,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: KClientsColors.orange,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  color: KClientsColors.orange.withOpacity(.25),
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---- Üst bar bileşeni (light) ----
class _TopBarLight extends StatelessWidget {
  final String title;
  final String businessName;
  final String businessEmail;
  final VoidCallback onLogout;

  const _TopBarLight({
    required this.title,
    required this.businessName,
    required this.businessEmail,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: KClientsColors.card,
        border: Border(
          bottom: BorderSide(color: KClientsColors.line),
        ),
      ),
      child: Row(
        children: [
          // brand chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KClientsColors.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KClientsColors.line),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo/haldeki_logo_icon.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: KClientsColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // user info
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                businessName,
                style: const TextStyle(
                  color: KClientsColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              if (businessEmail.isNotEmpty)
                Text(
                  businessEmail,
                  style: const TextStyle(
                    color: KClientsColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // logout
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: KClientsColors.purple.withOpacity(.10),
              foregroundColor: KClientsColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: KClientsColors.purple.withOpacity(.22)),
              ),
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout,
                size: 18, color: KClientsColors.orange),
            label: const Text(
              'Çıkış',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
