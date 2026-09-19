import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'bill_list_screen.dart';
import 'create_invoice_screen.dart';
import 'dashboard_screen.dart';
import 'party_list_screen.dart';
import 'product_list_screen.dart';
import 'profile_screen.dart';
import 'shop_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _invoiceTab = 2;

  int _navIndex = 0;
  int _refreshToken = 0;

  void _refreshCurrentPage() {
    setState(() => _refreshToken++);
  }

  String get _title {
    switch (_navIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Parties';
      case 3:
        return 'Products';
      case 4:
        return SessionService.instance.canManageShop
            ? 'Shop Settings'
            : 'Shop Details';
      default:
        return 'GST Billing';
    }
  }

  Future<void> _openCreateInvoice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );
    if (mounted) _refreshCurrentPage();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BillListScreen()),
    );
    if (mounted) _refreshCurrentPage();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted) _refreshCurrentPage();
  }

  void _onDestinationSelected(int index) {
    if (index == _invoiceTab) {
      _openCreateInvoice();
      return;
    }
    setState(() {
      _navIndex = index;
      _refreshToken++;
    });
  }

  Widget _currentPage() {
    switch (_navIndex) {
      case 1:
        return const PartyListScreen();
      case 3:
        return const ProductListScreen();
      case 4:
        return const ShopSettingsScreen(embedded: true);
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              IconButton(
                tooltip: 'History',
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: 'Profile',
                onPressed: _openProfile,
                icon: const Icon(Icons.account_circle_outlined),
              ),
            ],
          ),
          body: KeyedSubtree(
            key: ValueKey('$_navIndex-$_refreshToken'),
            child: _currentPage(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: _onDestinationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Parties',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.add_circle,
                  color: AppTheme.accent,
                  size: 32,
                ),
                selectedIcon: Icon(
                  Icons.add_circle,
                  color: AppTheme.accent,
                  size: 32,
                ),
                label: 'Invoice',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Products',
              ),
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Shop',
              ),
            ],
          ),
        );
      },
    );
  }
}
