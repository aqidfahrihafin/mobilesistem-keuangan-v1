import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../providers/anak_provider.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/flat_card.dart';
import '../widgets/geometric_pattern.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

const _statusLabel = {
  'baru': 'Santri Baru',
  'aktif': 'Aktif',
  'nonaktif': 'Nonaktif',
  'lulus': 'Lulus',
  'keluar': 'Keluar',
};

/// Purely informational identity card for the currently-selected santri -
/// photo, name, NIS, lembaga/kelas, and the biodata already returned by
/// AnakController (no new backend endpoint). Deliberately does NOT surface
/// anything from KartuSantri (nomor_kartu/uid_kartu) - that card's UID is a
/// kiosk RFID/fingerprint credential, encrypted and blind-indexed server-side
/// specifically so it never leaves the admin side; showing it here (even
/// read-only) would undercut that.
class SantriProfileScreen extends StatelessWidget {
  const SantriProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final anak = context.watch<AnakProvider>().selected;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Profil Santri',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
      body: anak == null
          ? const Center(
              child: EmptyStateView(
                icon: Icons.person_outline,
                message: 'Belum ada santri yang tertaut ke akun Anda.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _ProfileHero(anak: anak),
                const SizedBox(height: 20),
                _DetailSection(anak: anak),
              ],
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final Anak anak;

  const _ProfileHero({required this.anak});

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel[anak.status] ?? anak.status;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_teal, _tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: GeometricPatternBackground(opacity: 0.07),
          ),
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            // SizedBox(width: infinity) forces this Column to claim the
            // card's full width. Without it, a Stack's non-positioned
            // child (this Padding) is only given a LOOSE width constraint
            // and Column shrink-wraps to its widest child (the status
            // pill), then Stack's default topStart alignment pins that
            // narrow block to the top-left corner - the avatar/name/pill
            // hugged the left edge with the rest of the card left empty
            // instead of being centered.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  _Avatar(anak: anak),
                  const SizedBox(height: 14),
                  Text(
                    anak.nama,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'NIS ${anak.nis}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$statusLabel • ${anak.lembaga ?? 'Pondok Pusat'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Anak anak;

  const _Avatar({required this.anak});

  @override
  Widget build(BuildContext context) {
    final initial = anak.nama.isNotEmpty ? anak.nama[0].toUpperCase() : '?';
    final fotoUrl = anak.fotoUrl;

    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: fotoUrl == null
            ? _AvatarFallback(initial: initial)
            : Image.network(
                fotoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(initial: initial),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : _AvatarFallback(initial: initial),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;

  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _teal,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final Anak anak;

  const _DetailSection({required this.anak});

  @override
  Widget build(BuildContext context) {
    final ttl = [
      if (anak.tempatLahir?.isNotEmpty ?? false) anak.tempatLahir,
      if (anak.tanggalLahir != null) formatTanggal(anak.tanggalLahir!),
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            'Biodata',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        FlatCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'NIS',
                value: anak.nis,
              ),
              const Divider(height: 1, color: Color(0xFFEEF0F3)),
              _DetailRow(
                icon: Icons.school_outlined,
                label: 'Lembaga / Kelas',
                value: anak.lembaga ?? 'Pondok Pusat',
              ),
              const Divider(height: 1, color: Color(0xFFEEF0F3)),
              _DetailRow(
                icon: Icons.wc_rounded,
                label: 'Jenis Kelamin',
                value: anak.jenisKelamin == 'L'
                    ? 'Laki-laki'
                    : anak.jenisKelamin == 'P'
                    ? 'Perempuan'
                    : '-',
              ),
              const Divider(height: 1, color: Color(0xFFEEF0F3)),
              _DetailRow(
                icon: Icons.cake_outlined,
                label: 'Tempat, Tanggal Lahir',
                value: ttl.isEmpty ? '-' : ttl,
              ),
              const Divider(height: 1, color: Color(0xFFEEF0F3)),
              _DetailRow(
                icon: Icons.home_outlined,
                label: 'Alamat',
                value: (anak.alamat?.isNotEmpty ?? false) ? anak.alamat! : '-',
                isLast: true,
              ),
            ],
          ),
        ),
        if (anak.hubungan != null) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'Hubungan Wali',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          FlatCard(
            padding: EdgeInsets.zero,
            child: _DetailRow(
              icon: Icons.family_restroom_outlined,
              label: 'Status Hubungan',
              value: anak.hubungan!,
              isLast: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: _teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
