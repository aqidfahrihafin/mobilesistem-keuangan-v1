import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/flat_card.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'faq_screen.dart';
import 'pin_setup_screen.dart';
import 'version_screen.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);

class ProfilTab extends StatelessWidget {
  const ProfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final initial = (user?.name.isNotEmpty ?? false)
        ? user!.name[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          FlatCard(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFE6F5F1),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: _teal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? user?.phone ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 14,
                            color: _teal,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Wali Santri',
                            style: TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FlatCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.person_outline,
                  label: 'Edit Profil',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EBEF)),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Ganti Kata Sandi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EBEF)),
                _MenuTile(
                  icon: Icons.pin_outlined,
                  label: 'PIN Transaksi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                  ),
                ),
                // Owns its own leading divider (only rendered alongside
                // the tile itself) so nothing collapses into a stray
                // double divider when the device has no biometric
                // hardware and the tile hides itself entirely.
                const _BiometricToggleTile(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Lainnya',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.grey[500],
              ),
            ),
          ),
          FlatCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang Aplikasi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EBEF)),
                _MenuTile(
                  icon: Icons.new_releases_outlined,
                  label: 'Versi Aplikasi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VersionScreen()),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9EBEF)),
                _MenuTile(
                  icon: Icons.quiz_outlined,
                  label: 'Pusat Bantuan (QNA)',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FlatCard(
            padding: EdgeInsets.zero,
            child: _MenuTile(
              icon: Icons.logout,
              label: 'Keluar',
              danger: true,
              onTap: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'E-Mall Annuqayah • Dikembangkan oleh Apins Digital',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // With biometric login on, logout() only soft-locks (token stays
    // valid so the fingerprint button on the login screen can resume the
    // session) rather than fully signing out - worth being upfront about
    // since it's a real change from a plain "you're signed out" logout.
    final biometricEnabled = context.read<AuthService>().biometricEnabled;

    final confirmed = await ConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      iconColor: Colors.red[600]!,
      title: 'Keluar dari akun?',
      message: biometricEnabled
          ? 'Sesi akan dikunci. Gunakan sidik jari untuk masuk kembali dengan cepat, atau masuk ulang dengan kata sandi.'
          : 'Anda perlu masuk kembali untuk mengakses saldo dan tagihan.',
      confirmText: 'Ya, Keluar',
      confirmColor: Colors.red[600]!,
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red[600] : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (!danger) const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hides itself entirely (no tile, no divider) when the device has no
/// biometric hardware/enrollment - see BiometricService.isSupported().
class _BiometricToggleTile extends StatefulWidget {
  const _BiometricToggleTile();

  @override
  State<_BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<_BiometricToggleTile> {
  bool? _supported;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await context.read<BiometricService>().isSupported();
    if (mounted) setState(() => _supported = supported);
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    final auth = context.read<AuthService>();

    if (value) {
      // Prove hardware + enrollment actually work end-to-end before
      // persisting the preference - otherwise a wali could enable this and
      // get stuck with no way back in except "Gunakan Kata Sandi" on the
      // very next launch.
      final result = await context.read<BiometricService>().authenticate();
      if (result == BiometricAuthResult.success) {
        await auth.setBiometricEnabled(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifikasi sidik jari gagal, coba lagi.'),
          ),
        );
      }
    } else {
      await auth.setBiometricEnabled(false);
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_supported != true) return const SizedBox.shrink();

    final enabled = context.watch<AuthService>().biometricEnabled;

    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFE9EBEF)),
        _MenuSwitchTile(
          icon: Icons.fingerprint_rounded,
          label: 'Login dengan Sidik Jari',
          value: enabled,
          onChanged: _busy ? null : _onChanged,
        ),
      ],
    );
  }
}

class _MenuSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _MenuSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
