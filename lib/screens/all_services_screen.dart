import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../widgets/flat_card.dart';
import 'faq_screen.dart';
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
              title: 'Keuangan',
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
              title: 'Informasi Santri',
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
              ],
            ),
            const SizedBox(height: 22),
            _ServiceSection(
              title: 'Akun & Bantuan',
              items: [
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
                _ServiceItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Pusat Bantuan',
                  onTap: () => _open(context, const FaqScreen()),
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.15,
          ),
          itemBuilder: (context, index) => items[index],
        ),
      ],
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: _teal, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17212B),
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
