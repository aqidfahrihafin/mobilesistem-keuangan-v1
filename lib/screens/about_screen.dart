import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/app_info_provider.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/flat_card.dart';
import '../widgets/geometric_pattern.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

class _Fitur {
  final IconData icon;
  final String label;

  const _Fitur(this.icon, this.label);
}

const _fiturUnggulan = [
  _Fitur(Icons.account_balance_wallet_rounded, 'Saldo Real-Time'),
  _Fitur(Icons.receipt_long_rounded, 'Bayar Tagihan'),
  _Fitur(Icons.qr_code_2_rounded, 'Top Up VA/QRIS'),
  _Fitur(Icons.fingerprint_rounded, 'Login Sidik Jari'),
  _Fitur(Icons.bar_chart_rounded, 'Laporan Lengkap'),
  _Fitur(Icons.description_rounded, 'Kwitansi Resmi'),
];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_teal, _tealDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: const AppLogoImage(),
                ),
                const SizedBox(height: 16),
                Text(
                  context.watch<AppInfoProvider>().namaAplikasi ??
                      'E-Mall Annuqayah',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.watch<AppInfoProvider>().namaPondok ??
                      'Pondok Pesantren Latee',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 10),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        version != null ? 'Versi $version' : 'Memuat versi...',
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FlatCard(
            color: const Color(0xDDF1F8F6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplikasi wali santri resmi Pondok Pesantren Latee - memudahkan '
                  'orang tua/wali memantau saldo, membayar tagihan, dan mengelola '
                  'keuangan santri langsung dari genggaman, kapan saja dan di mana saja.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Fitur Unggulan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: _fiturUnggulan
                .map(
                  (f) => Container(
                    decoration: BoxDecoration(
                      color: const Color(0xDDF1F8F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x80A9CEC8)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F3D3A),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(f.icon, color: _teal, size: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          f.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    child: GeometricPatternBackground(opacity: 0.06),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIKEMBANGKAN OLEH',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Apins Digital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solusi digital untuk kebutuhan pondok pesantren.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '© ${DateTime.now().year} Apins Digital. All rights reserved.',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
