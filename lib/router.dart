// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:haldeki_admin_web/models/courier_models.dart';

import 'package:haldeki_admin_web/reports/daily_cash_dashboard.dart';
import 'package:haldeki_admin_web/reports/reports_couriers_page.dart';
import 'package:haldeki_admin_web/reports/reports_customers_page.dart';
import 'package:haldeki_admin_web/reports/reports_orders_page.dart';

import 'package:haldeki_admin_web/screens/Product/market_screen.dart';
import 'package:haldeki_admin_web/screens/admin/client_create_screen.dart';
import 'package:haldeki_admin_web/screens/client_dashboard_screen.dart';
import 'package:haldeki_admin_web/screens/courier_detail_screen.dart';
import 'package:haldeki_admin_web/screens/couriers_screen.dart';
import 'package:haldeki_admin_web/screens/customer_detail_screen.dart'
    hide CourierDetailScreen;
import 'package:haldeki_admin_web/screens/dealer_profile_screen.dart';
import 'package:haldeki_admin_web/screens/delivery_order_detail_screen.dart';
import 'package:haldeki_admin_web/screens/delivery_orders_screen.dart';
import 'package:haldeki_admin_web/screens/ops_map_screen.dart';
import 'package:haldeki_admin_web/screens/product_dashboard_screen.dart';

import 'package:haldeki_admin_web/screens/users_screen%20.dart';

import 'package:haldeki_admin_web/services/api_client.dart';
import 'package:haldeki_admin_web/screens/supplier_profile_screen.dart';

import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'screens/dashboard_screen.dart';

import 'screens/orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/customers_screen.dart';

class AppRouter {
  static GoRouter build() {
    return GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final loc = state.uri.path;
            final index = _navIndexFor(loc);
            return ShellScaffold(child: child, currentIndex: index);
          },
          routes: [
            // --- Ana Sayfa ---
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),

            // --- Operasyon ---
            GoRoute(
              path: '/operasyon',
              builder: (_, __) => const OpsMapScreen(),
            ),

            // --- Ürünler --- ✅ BOŞLUK YOK!
            GoRoute(
              path: '/products',
              builder: (_, __) => const MarketScreen(),
            ),

            // --- İşletmeler ---
            GoRoute(
              path: '/customers',
              builder: (_, __) => const ClientsScreen(),
            ),
            GoRoute(
              path: '/customers/:id',
              builder: (c, s) {
                final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
                final initial =
                    s.extra is CustomerLite ? s.extra as CustomerLite : null;
                return CustomerDetailScreen(id: id, initial: initial);
              },
            ),

            // --- Users (istersen sonra kaldırırız) ---
            GoRoute(path: '/users', builder: (c, s) => const UsersScreen()),
            GoRoute(
              path: '/users/:id',
              builder: (c, s) {
                final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
                final initial =
                    s.extra is CustomerLite ? s.extra as CustomerLite : null;
                return CustomerDetailScreen(id: id, initial: initial);
              },
            ),

            // --- Admin Create ---
            GoRoute(
              path: '/admin/clients/create',
              builder: (ctx, st) => const ClientCreateScreen(),
            ),

            // --- Siparişler: Aktif Siparişler ---
            GoRoute(
              path: '/orders',
              builder: (_, __) => const OrdersScreen(),
              routes: [
                GoRoute(
                  path: ':orderNumber',
                  builder: (_, state) => OrderDetailScreen(
                    orderNumber: state.pathParameters['orderNumber']!,
                  ),
                ),
              ],
            ),

            // --- Siparişler: Kuryeye Aktarılan ---
            GoRoute(
              path: '/delivery-orders',
              builder: (_, __) => const DeliveryOrdersScreen(),
              routes: [
                GoRoute(
                  name: 'deliveryOrderDetail',
                  path: ':orderNumber',
                  builder: (_, state) {
                    final orderNo = Uri.decodeComponent(
                      state.pathParameters['orderNumber']!,
                    );
                    final initialDeliveryStatus =
                        state.uri.queryParameters['status'];

                    return DeliveryOrderDetailScreen(
                      orderNumber: orderNo,
                      initialDeliveryStatus: initialDeliveryStatus,
                    );
                  },
                ),
              ],
            ),

            // --- Kuryeler ---
            GoRoute(
              path: '/couriers',
              builder: (c, s) => const CouriersScreen(),
            ),
            GoRoute(
              path: '/couriers/:id',
              name: 'courier-detail',
              redirect: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '');
                if (id == null || id <= 0) return '/couriers';
                return null;
              },
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                final initial = (state.extra is CourierLite)
                    ? state.extra as CourierLite
                    : null;

                return CourierDetailScreen(id: id, initial: initial);
              },
            ),

            // --- Kasa ---
            GoRoute(
              path: '/cash',
              builder: (_, __) => const DailyCashDashboard(),
            ),

            // --- Raporlar ---
            GoRoute(
              path: '/reports/customers',
              builder: (_, __) => const ReportsCustomersPage(),
            ),
            GoRoute(
              path: '/reports/couriers',
              builder: (_, __) => const ReportsCouriersPage(),
            ),
            GoRoute(
              path: '/reports/orders',
              builder: (_, __) => const ReportsOrdersPage(),
            ),
            GoRoute(
              path: '/product-dashboard',
              builder: (_, __) => const ProductDashboardScreen(),
            ),
            GoRoute(
              path: '/client-dashboard',
              builder: (_, __) => const ClientProductDashboardScreen(),
            ),

            // --- Profil ---
            GoRoute(
              path: '/profile',
              builder: (_, __) => const DealerProfileScreen(),
            ),

            // (opsiyonel) suppliers dursun ama menüde göstermeyebiliriz
            GoRoute(
              path: '/suppliers',
              builder: (_, __) => SupplierProfileScreen(api: ApiClient()),
            ),
          ],
        ),
      ],
    );
  }

  /// Resimdeki sidebar sırası:
  /// 0 Ana Sayfa, 1 Operasyon, 2 Siparişler, 3 İşletmeler, 4 Ürünler, 5 Kuryeler, 6 Kasa, 7 Raporlar, 8 Profil
  static int _navIndexFor(String loc) {
    if (loc == '/dashboard') return 0;
    if (loc == '/operasyon') return 1;

    if (loc == '/orders' ||
        loc.startsWith('/orders/') ||
        loc.startsWith('/delivery-orders')) {
      return 2;
    }

    if (loc == '/customers' || loc.startsWith('/customers/')) return 3;

    // if (loc == '/products') return 4;

    if (loc == '/couriers' || loc.startsWith('/couriers/')) return 5;

    if (loc == '/cash') return 6;

    if (loc.startsWith('/reports') ||
        loc == '/product-dashboard' ||
        loc == '/client-dashboard') {
      return 7;
    }

    if (loc == '/profile') return 8;

    return 0;
  }
}
