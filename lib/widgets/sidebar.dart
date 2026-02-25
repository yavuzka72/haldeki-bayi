import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.appTitle = 'Haldeki Bayi',
    this.logoAsset, // ör: assets/logo.png
  });

  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final String appTitle;
  final String? logoAsset;

  bool _isActive(String route) => currentRoute == route;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260, // geniş (yazılı) menü
      color: cs.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ------- Header: logo + isim -------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  _Logo(logoAsset: logoAsset),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ------- Menü -------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _tile(
                    context,
                    icon: Icons.arrow_back,
                    label: 'Siteyi Görüntüle',
                    onTap: () => onNavigate('/'),
                  ),
                  _tile(
                    context,
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Gösterge Paneli',
                    route: '/dashboard',
                  ),
                  _tile(
                    context,
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Operasyon',
                    route: '/operasyon',
                  ),
                  _tile(
                    context,
                    icon: Icons.public_outlined,
                    label: 'Ülke',
                    route: '/countries',
                  ),
                  _tile(
                    context,
                    icon: Icons.apartment_outlined,
                    label: 'Şehir',
                    route: '/cities',
                    // örnekte kırmızı vurgu vardı: seçiliyse kırmızı göster
                    selectedColor: Colors.red,
                  ),

                  // --- Gruplar (ikincideki gibi açılır) ---
                  _group(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Sipariş',
                    children: [
                      _subtile(context, 'Tüm Siparişler', '/orders'),
                      _subtile(context, 'Bekleyen', '/orders/pending'),
                    ],
                  ),
                  /*   _tile(
                    context,
                    icon: Icons.person_outline,
                    label: 'Ürünler',
                    route: '/products',
                    selectedColor: Colors.red, // örnekte kırmızı vurgu
                  ),*/
                  _group(
                    context,
                    icon: Icons.speed_outlined,
                    label: 'Kurye',
                    children: [
                      _subtile(context, 'Aktif Kuryeler', '/couriers/active'),
                      _subtile(context, 'Talepler', '/couriers/requests'),
                    ],
                  ),
                  _group(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'Ayar',
                    children: [
                      _subtile(context, 'Genel', '/settings/general'),
                      _subtile(context, 'Ödeme', '/settings/payments'),
                    ],
                  ),
                  _tile(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Geri çekme talebi',
                    route: '/withdrawals',
                  ),
                  _tile(
                    context,
                    icon: Icons.receipt_outlined,
                    label: 'Fatura ayarı',
                    route: '/billing',
                  ),
                  _group(
                    context,
                    icon: Icons.app_settings_alt_outlined,
                    label: 'Uygulama Ayarı',
                    children: [
                      _subtile(context, 'Bildirimler', '/app/notifications'),
                      _subtile(context, 'Güvenlik', '/app/security'),
                    ],
                  ),
                  _group(
                    context,
                    icon: Icons.public,
                    label: 'Web Sitesi Bölümü',
                    children: [
                      _subtile(context, 'Sayfalar', '/site/pages'),
                      _subtile(context, 'Bannerlar', '/site/banners'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- helpers -----
  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? route,
    VoidCallback? onTap,
    Color? selectedColor,
  }) {
    final selected = route != null && _isActive(route);
    final baseColor = selectedColor ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: selected ? baseColor : null),
      title: Text(
        label,
        style: selected
            ? TextStyle(color: baseColor, fontWeight: FontWeight.w600)
            : null,
      ),
      selected: selected,
      onTap: onTap ?? (() => onNavigate(route ?? '/')),
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
    );
  }

  Widget _group(BuildContext context,
      {required IconData icon,
      required String label,
      required List<Widget> children}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(label),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 20),
        collapsedShape: const RoundedRectangleBorder(),
        shape: const RoundedRectangleBorder(),
        children: children,
      ),
    );
  }

  Widget _subtile(BuildContext context, String label, String route) {
    final selected = _isActive(route);
    return ListTile(
      title: Text(
        label,
        style: selected
            ? TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      onTap: () => onNavigate(route),
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.logoAsset});
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary.withOpacity(.12);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: (logoAsset != null)
          ? ClipOval(
              child: Image.asset(logoAsset!,
                  width: 44, height: 44, fit: BoxFit.cover))
          : Icon(Icons.apps, color: cs.onPrimaryContainer),
    );
  }
}
