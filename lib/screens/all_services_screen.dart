import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../theme/app_theme.dart';
import 'faq_screen.dart';
import 'login_pin_setup_screen.dart';
import 'pin_setup_screen.dart';
import 'santri_profile_screen.dart';
import 'scan_bayar_screen.dart';
import 'topup_tab.dart';
import 'tabungan_screen.dart';
import 'transfer_saldo_screen.dart';

const _bg = AppColors.background;

class AllServicesScreen extends StatelessWidget {
  const AllServicesScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _goTab(BuildContext context, int index) {
    context.read<TabIndexProvider>().go(index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Semua Layanan'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _ServiceSection(
              title: 'Layanan Utama',
              items: [
                _ServiceItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Top Up',
                  onTap: () => _open(context, const TopupTab()),
                ),
                _ServiceItem(
                  icon: Icons.send_rounded,
                  label: 'Transfer',
                  onTap: () => _open(context, const TransferSaldoScreen()),
                ),
                _ServiceItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Bayar Kantin',
                  onTap: () => _open(context, const ScanBayarScreen()),
                ),
                _ServiceItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Tagihan',
                  onTap: () => _goTab(context, 1),
                ),
                _ServiceItem(
                  icon: Icons.savings_outlined,
                  label: 'Tabungan',
                  onTap: () => _open(context, const TabunganScreen()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ServiceSection(
              title: 'Santri & Akun',
              items: [
                _ServiceItem(
                  icon: Icons.badge_rounded,
                  label: 'Profil Santri',
                  onTap: () => _open(context, const SantriProfileScreen()),
                ),
                _ServiceItem(
                  icon: Icons.history_rounded,
                  label: 'Riwayat',
                  onTap: () => _goTab(context, 2),
                ),
                _ServiceItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profil Wali',
                  onTap: () => _goTab(context, 3),
                ),
                _ServiceItem(
                  icon: Icons.pin_outlined,
                  label: 'PIN Transaksi',
                  onTap: () => _open(context, const PinSetupScreen()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ServiceSection(
              title: 'Keamanan & Bantuan',
              items: [
                _ServiceItem(
                  icon: Icons.lock_person_outlined,
                  label: 'PIN Login',
                  onTap: () => _open(context, const LoginPinSetupScreen()),
                ),
                _ServiceItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Pusat Bantuan',
                  onTap: () => _open(context, const FaqScreen()),
                ),
                const _ServiceItem(
                  icon: Icons.gavel_outlined,
                  label: 'Pelanggaran',
                  enabled: false,
                  comingSoon: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  final String title;
  final List<_ServiceItem> items;

  const _ServiceSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 340 ? 3 : 4;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 92,
                ),
                itemBuilder: (context, index) => items[index],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  static const _colors = [
    Color(0xFF0F8F83),
    Color(0xFF2563EB),
    Color(0xFF8B4BE8),
    Color(0xFFE23483),
    Color(0xFFF59E0B),
  ];

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool comingSoon;

  const _ServiceItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? _colors[icon.codePoint % _colors.length]
        : const Color(0xFF98A2B3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Layanan ini akan segera tersedia.'),
                ),
              ),
        borderRadius: AppRadius.borderRadius,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.borderRadius,
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 28),
                ),
                if (comingSoon)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD8DDE3)),
                      ),
                      child: const Text(
                        'Segera',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
