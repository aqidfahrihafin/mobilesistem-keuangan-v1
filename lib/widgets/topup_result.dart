import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

import '../models/topup.dart';
import '../utils/formatters.dart';
import '../utils/metode_topup.dart';
import 'flat_card.dart';

const _bg = Color(0xFFF7F8FA);
const _teal = Color(0xFF0F766E);

/// Shared "how did this top up turn out" UI - originally built for the
/// generic top-up screen (TopupTab), extracted so the tagihan-scoped direct
/// Midtrans payment flow (TagihanTopupScreen) can render results the exact
/// same way instead of duplicating this UI.
class MetodeTile extends StatelessWidget {
  final MetodeTopup metode;
  final bool selected;
  final VoidCallback onTap;

  /// Estimated Midtrans fee for this channel at the currently-typed
  /// nominal, only when the admin's MidtransFeeService policy charges it to
  /// the wali - null/0 renders nothing extra, so a pondok-absorbed fee (or
  /// no fee configured at all) leaves this tile pixel-identical to before.
  final int? biayaEstimasi;

  const MetodeTile({
    super.key,
    required this.metode,
    required this.selected,
    required this.onTap,
    this.biayaEstimasi,
  });

  @override
  Widget build(BuildContext context) {
    final kategori = metode.kode == 'qris' ? 'QRIS' : 'Virtual Account';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 116,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            color: const Color(0xE6F4F9F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? _teal.withValues(alpha: 0.35)
                  : const Color(0xBFFFFFFF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F3D3A),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xECFAFDFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? _teal.withValues(alpha: 0.35)
                            : const Color(0xBFFFFFFF),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F3D3A),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(metode.icon, color: _teal, size: 23),
                  ),
                  if (selected)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _teal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF4F9F8),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          kategori,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: Color(0xFF17212B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metode.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        color: Color(0xFF667085),
                      ),
                    ),
                    if (biayaEstimasi != null && biayaEstimasi! > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+${formatRupiah(biayaEstimasi!)} biaya admin',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _teal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CaraBayarCard extends StatelessWidget {
  final MetodeTopup? metode;

  const CaraBayarCard({super.key, required this.metode});

  @override
  Widget build(BuildContext context) {
    final langkah = metode?.langkahPembayaran;
    if (langkah == null || langkah.isEmpty) return const SizedBox.shrink();

    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18, color: _teal),
              SizedBox(width: 8),
              Text(
                'Cara Bayar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...langkah.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
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

class VaCard extends StatelessWidget {
  final Topup topup;
  final void Function(String vaNumber) onSalin;

  const VaCard({super.key, required this.topup, required this.onSalin});

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: _teal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Virtual Account ${topup.vaBank?.toUpperCase() ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              StatusPill(status: topup.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Nomor Virtual Account',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        topup.vaNumber ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: topup.vaNumber == null
                          ? null
                          : () => onSalin(topup.vaNumber!),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: _teal,
                      tooltip: 'Salin nomor',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          JumlahBayarRow(
            nominal: topup.nominalDiminta,
            biaya: topup.biayaDitanggungWali ? topup.biayaMidtrans : null,
          ),
          if (topup.expiryTime != null) ...[
            const SizedBox(height: 10),
            ExpiryRow(expiryTime: topup.expiryTime!),
          ],
        ],
      ),
    );
  }
}

class QrisCard extends StatefulWidget {
  final Topup topup;

  const QrisCard({super.key, required this.topup});

  @override
  State<QrisCard> createState() => _QrisCardState();
}

class _QrisCardState extends State<QrisCard> {
  bool _saving = false;
  final _captureKey = GlobalKey();

  Future<void> _saveQr() async {
    final qrUrl = widget.topup.qrUrl;
    if (qrUrl == null || _saving) return;

    setState(() => _saving = true);
    try {
      var allowed = await Gal.hasAccess();
      if (!allowed) {
        await Gal.requestAccess();
        allowed = await Gal.hasAccess();
      }
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin galeri diperlukan untuk menyimpan QRIS.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      await precacheImage(NetworkImage(qrUrl), context);
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Tampilan QRIS belum siap.');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Gambar QRIS gagal dibuat.');
      await Gal.putImageBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 19),
              SizedBox(width: 9),
              Text('QRIS berhasil disimpan ke galeri.'),
            ],
          ),
          backgroundColor: _teal,
        ),
      );
    } on GalException catch (error) {
      if (!mounted) return;
      final message = error.type == GalExceptionType.accessDenied
          ? 'Izin galeri diperlukan untuk menyimpan QRIS.'
          : 'QRIS gagal disimpan. Silakan coba lagi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRIS gagal diunduh. Periksa koneksi lalu coba lagi.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topup = widget.topup;
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _QrisDownloadContent(topup: topup),
              ),
            ),
          ),
          if (topup.qrUrl != null) const SizedBox(height: 14),
          if (topup.qrUrl != null) ...[
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _saveQr,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _teal,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _saving ? 'Menyimpan QR...' : 'Simpan QR ke Galeri',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrisDownloadContent extends StatelessWidget {
  final Topup topup;

  const _QrisDownloadContent({required this.topup});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.qr_code_rounded, color: _teal, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pembayaran QRIS',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
            StatusPill(status: topup.status),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: topup.qrUrl == null
                ? const Center(child: Icon(Icons.qr_code_2, size: 64))
                : Image.network(
                    topup.qrUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Center(
                      child: Text(
                        'Gagal memuat QR',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        JumlahBayarRow(
          nominal: topup.nominalDiminta,
          biaya: topup.biayaDitanggungWali ? topup.biayaMidtrans : null,
        ),
        if (topup.expiryTime != null) ...[
          const SizedBox(height: 10),
          ExpiryRow(expiryTime: topup.expiryTime!),
        ],
        const SizedBox(height: 10),
        Text(
          'ID Pembayaran: ${topup.uuid}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class JumlahBayarRow extends StatelessWidget {
  final int nominal;

  /// The Midtrans fee actually charged on top of [nominal] - null/0 keeps
  /// today's single-line display; a positive value shows a Nominal/Biaya
  /// Admin/Total breakdown instead. Callers should pass the *authoritative*
  /// value locked in on the created Topup (topup.biayaMidtrans, only when
  /// topup.biayaDitanggungWali), not a pre-submit estimate - the admin's fee
  /// settings can change between when the wali started the flow and when it
  /// was actually charged.
  final int? biaya;

  const JumlahBayarRow({super.key, required this.nominal, this.biaya});

  @override
  Widget build(BuildContext context) {
    if (biaya == null || biaya! <= 0) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Jumlah yang harus dibayar',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatRupiah(nominal),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      );
    }

    final total = nominal + biaya!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baris('Nominal Top Up', formatRupiah(nominal)),
        const SizedBox(height: 4),
        _baris('Biaya Admin Midtrans', formatRupiah(biaya!)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Total Bayar',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatRupiah(total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  Widget _baris(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class ExpiryRow extends StatelessWidget {
  final DateTime expiryTime;

  const ExpiryRow({super.key, required this.expiryTime});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Berlaku hingga ${formatTanggalWaktu(expiryTime)}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'paid' => (const Color(0xFFE7F6EF), const Color(0xFF15803D)),
      'pending' => (const Color(0xFFFEF6E7), const Color(0xFFB45309)),
      _ => (const Color(0xFFFDEBEB), const Color(0xFFB91C1C)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        statusTopupLabel[status] ?? status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TopupStatusCard extends StatelessWidget {
  final Topup topup;

  const TopupStatusCard({super.key, required this.topup});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (topup.status) {
      'paid' => (Icons.check_circle, const Color(0xFF15803D)),
      'pending' => (Icons.hourglass_top, const Color(0xFFB45309)),
      _ => (Icons.error_outline, const Color(0xFFB91C1C)),
    };

    return FlatCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(
            statusTopupLabel[topup.status] ?? topup.status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nominal diminta: ${formatRupiah(topup.nominalDiminta)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          if (topup.isPaid) ...[
            const SizedBox(height: 4),
            if (topup.nominalPotonganTagihan > 0)
              Text(
                topup.isTagihanScoped
                    ? 'Tagihan berhasil dilunasi: ${formatRupiah(topup.nominalPotonganTagihan)}'
                    : 'Dipakai bayar tagihan: ${formatRupiah(topup.nominalPotonganTagihan)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            if (topup.nominalKeSaldo > 0)
              Text(
                'Masuk ke saldo: ${formatRupiah(topup.nominalKeSaldo)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}
