import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/flat_card.dart';
import '../widgets/geometric_pattern.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'faq_screen.dart';
import 'pin_setup_screen.dart';
import 'version_screen.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Container(
                  height: 176,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_teal, _tealDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -40,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: GeometricPatternBackground(opacity: 0.07),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: const [
                              Text(
                                'Profil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -38,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: _teal,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: _teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          Text(
            user?.name ?? '-',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? user?.phone ?? '-',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified_user_outlined, size: 13, color: _teal),
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
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FlatCard(
              color: const Color(0xDDF1F8F6),
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
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 10),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FlatCard(
              color: const Color(0xDDF1F8F6),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FlatCard(
              color: const Color(0xDDF1F8F6),
              padding: EdgeInsets.zero,
              child: _MenuTile(
                icon: Icons.logout,
                label: 'Keluar',
                danger: true,
                onTap: () => _confirmLogout(context),
              ),
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
