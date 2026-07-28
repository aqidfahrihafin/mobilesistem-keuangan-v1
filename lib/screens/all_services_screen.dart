import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import 'faq_screen.dart';
import 'login_pin_setup_screen.dart';
import 'pin_setup_screen.dart';
import 'santri_profile_screen.dart';
import 'scan_bayar_screen.dart';
import 'topup_tab.dart';
import 'transfer_saldo_screen.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

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
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17212B),
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
              ],
            ),
            const SizedBox(height: 22),
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
            const SizedBox(height: 22),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17212B),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8E4)),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 12,
              mainAxisExtent: 82,
            ),
            itemBuilder: (context, index) => items[index],
          ),
        ),
      ],
    );
  }
}

class _ServiceItem extends StatelessWidget {
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
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: enabled
                        ? _teal.withValues(alpha: 0.09)
                        : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: enabled
                          ? _teal.withValues(alpha: 0.08)
                          : const Color(0xFFE1E4E8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: enabled ? _teal : const Color(0xFF98A2B3),
                    size: 20,
                  ),
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
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? const Color(0xFF17212B)
                    : const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
