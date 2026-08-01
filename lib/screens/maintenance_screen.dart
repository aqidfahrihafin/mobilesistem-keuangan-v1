import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/maintenance_provider.dart';
import '../theme/app_theme.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = context.watch<MaintenanceProvider>();
    final expected = maintenance.expectedEndAt;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _MaintenanceIllustration(),
                  const SizedBox(height: 22),
                  const _MaintenanceBadge(),
                  const SizedBox(height: 14),
                  Text(
                    'Layanan sedang kami siapkan',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 25,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    maintenance.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                      height: 1.55,
                    ),
                  ),
                  if (expected != null) ...[
                    const SizedBox(height: 20),
                    _EstimateCard(expected: expected),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: maintenance.checking
                          ? null
                          : () => maintenance.check(),
                      icon: maintenance.checking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        maintenance.checking ? 'Memeriksa...' : 'Coba Lagi',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Data tetap aman. Aplikasi terbuka otomatis setelah layanan normal.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceBadge extends StatelessWidget {
  const _MaintenanceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'PEMELIHARAAN SISTEM',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFFA85B08),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final DateTime expected;

  const _EstimateCard({required this.expected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F766E),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perkiraan selesai',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatDate(expected)} WIB',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day} ${months[value.month - 1]}, $hour:$minute';
  }
}

class _MaintenanceIllustration extends StatelessWidget {
  const _MaintenanceIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 224,
            height: 224,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE5F3F1),
            ),
          ),
          Positioned(
            top: 24,
            right: 62,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF5BE4F),
              ),
            ),
          ),
          Image.asset(
            'assets/images/maintenance-secure-transparent.png',
            height: 244,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Icon(
              Icons.admin_panel_settings_rounded,
              size: 96,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
