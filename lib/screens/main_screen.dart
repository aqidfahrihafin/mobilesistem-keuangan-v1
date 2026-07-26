import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../providers/anak_provider.dart';
import '../providers/tab_index_provider.dart';
import 'home_tab.dart';
import 'laporan_tab.dart';
import 'profil_tab.dart';
import 'tagihan_tab.dart';
import 'topup_tab.dart';

const _teal = Color(0xFF0F766E);

/// Shell for the logged-in app: bottom nav + the 4 tabs, all sharing one
/// AnakProvider (so switching anak on Home is reflected on Tagihan/Riwayat
/// too) and one TabIndexProvider (so e.g. Home's "Lihat Semua" can switch
/// tabs from a deeply nested widget without prop-drilling a callback).
///
/// Top Up is the 5th destination, rendered as a docked/elevated circular
/// button (PayPal's "Kirim/Minta" pattern) rather than a 5th IndexedStack
/// entry - it's a one-shot flow you push into and back out of, not a tab
/// you park on, so it doesn't need a slot in TabIndexProvider.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _tabs = [HomeTab(), TagihanTab(), LaporanTab(), ProfilTab()];

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnakProvider>().load();
    });
  }

  void _openTopup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TopupTab()));
  }

  /// This is the root screen after login - the system back gesture/button
  /// reaching here means "leave the app", which is one tap too easy to hit
  /// by accident (no confirmation, no undo). Standard double-back-to-exit:
  /// the first press just shows a hint and resets a short window; only a
  /// second press *within* that window actually exits.
  void _handleBackPress(bool didPop) {
    if (didPop) return;

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = context.watch<TabIndexProvider>().index;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackPress(didPop),
      child: Scaffold(
        body: IndexedStack(index: tabIndex, children: _tabs),
        floatingActionButton: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            onPressed: _openTopup,
            tooltip: 'Top Up Saldo',
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
            // FittedBox (not just a fixed 60x60 circle) - a CircleBorder
            // FAB actively clips its content, so a larger system font
            // scale would otherwise cut the "Top Up" label off at the
            // circle's edge instead of just looking cramped. scaleDown
            // shrinks the icon+label stack together if it doesn't fit,
            // rather than letting either get clipped.
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 22),
                  SizedBox(height: 1),
                  Text(
                    'Top Up',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: const Color(0xE8FFFFFF),
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x260F3D3A),
          elevation: 12,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Beranda',
                        selected: tabIndex == 0,
                        onTap: () => context.read<TabIndexProvider>().go(0),
                      ),
                      _NavItem(
                        icon: Icons.receipt_long_outlined,
                        selectedIcon: Icons.receipt_long,
                        label: 'Tagihan',
                        selected: tabIndex == 1,
                        onTap: () => context.read<TabIndexProvider>().go(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart_rounded,
                        label: 'Laporan',
                        selected: tabIndex == 2,
                        onTap: () => context.read<TabIndexProvider>().go(2),
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profil',
                        selected: tabIndex == 3,
                        onTap: () => context.read<TabIndexProvider>().go(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _teal : Colors.grey[600];

    return InkResponse(
      onTap: onTap,
      radius: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 23),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
