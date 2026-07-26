import 'package:flutter/material.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../utils/formatters.dart';
import '../utils/jatuh_tempo.dart';
import '../widgets/status_badge.dart';
import '../widgets/tagihan_bayar_flow.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Full detail for a single tagihan, on its own page - same rincian
/// content _TagihanCard already shows inline (expanded), plus the real
/// Bayar/Cetak actions via the shared [bayarTagihanFlow]/[cetakTagihanFlow]
/// (also used by TagihanTab, so both entry points share one payment path).
/// Entered by tapping a tagihan preview on Home.
class TagihanDetailScreen extends StatefulWidget {
  final Anak anak;
  final Tagihan tagihan;

  const TagihanDetailScreen({
    super.key,
    required this.anak,
    required this.tagihan,
  });

  @override
  State<TagihanDetailScreen> createState() => _TagihanDetailScreenState();
}

class _TagihanDetailScreenState extends State<TagihanDetailScreen> {
  late Tagihan _tagihan = widget.tagihan;
  bool _berubah = false;
  bool _membukaPembayaran = false;

  Future<void> _bayar() async {
    if (_membukaPembayaran) return;
    setState(() => _membukaPembayaran = true);

    try {
      final berhasil = await bayarTagihanFlow(context, widget.anak, _tagihan);
      // The flow already refreshes AnakProvider's saldo; the tagihan's own
      // fresh state (nominal_terbayar/sisa/status) isn't returned from it
      // though, so this screen falls back to just reflecting "sudah lunas"
      // for a full payment and leaving the rest to whoever refreshes the
      // list behind it (see PopScope below, which reports back via `true`).
      if (berhasil && mounted) {
        setState(() {
          _berubah = true;
          if (_tagihan.bisaDicicil) return;
          _tagihan = Tagihan(
            id: _tagihan.id,
            jenisTagihanKode: _tagihan.jenisTagihanKode,
            jenisTagihanNama: _tagihan.jenisTagihanNama,
            bisaDicicil: _tagihan.bisaDicicil,
            periodeLabel: _tagihan.periodeLabel,
            nominal: _tagihan.nominal,
            nominalSebelumDiskon: _tagihan.nominalSebelumDiskon,
            diskonPersen: _tagihan.diskonPersen,
            nominalTerbayar: _tagihan.nominal,
            sisa: 0,
            status: 'lunas',
            jatuhTempo: _tagihan.jatuhTempo,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _membukaPembayaran = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagihan = _tagihan;
    final (badgeBg, badgeFg) = StatusBadge.colorsFor(tagihan.status);
    final progress = tagihan.nominal > 0
        ? (tagihan.nominalTerbayar / tagihan.nominal).clamp(0.0, 1.0)
        : 0.0;
    final jatuhTempoInfo = hitungJatuhTempo(tagihan);
    final showActions = !tagihan.selesai || tagihan.nominalTerbayar > 0;

    return PopScope(
      // Intercepts every pop path (AppBar back arrow, system back gesture,
      // not just an explicit button) so the caller (Home) always learns
      // whether a payment went through here and can refresh its own
      // tagihan/aktivitas lists - same "pop(true) on success" contract
      // TagihanTopupScreen already uses elsewhere.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_berubah);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Detail Tagihan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE9EBEF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: badgeFg,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tagihan.jenisTagihanNama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tagihan.periodeLabel,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: tagihan.status),
                        ],
                      ),
                      if (jatuhTempoInfo != null ||
                          (tagihan.bisaDicicil && !tagihan.selesai)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (jatuhTempoInfo != null)
                              _Chip(
                                icon: jatuhTempoInfo.icon,
                                label: jatuhTempoInfo.label,
                                color: jatuhTempoInfo.color,
                                background: jatuhTempoInfo.background,
                              ),
                            if (tagihan.bisaDicicil && !tagihan.selesai)
                              const _Chip(
                                icon: Icons.payments_outlined,
                                label: 'Bisa Dicicil',
                                color: _teal,
                                background: Color(0x1A0F766E),
                              ),
                          ],
                        ),
                      ],
                      if (tagihan.status == 'sebagian') ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFEFF1F4),
                            valueColor: const AlwaysStoppedAnimation(_teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).round()}% terbayar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9EBEF)),
                  ),
                  child: Column(
                    children: [
                      if (tagihan.adaDiskon) ...[
                        _row(
                          'Sebelum Diskon',
                          formatRupiah(tagihan.nominalSebelumDiskon!),
                        ),
                        _divider(),
                        _row('Diskon', '${tagihan.diskonPersen}%'),
                        _divider(),
                      ],
                      _row('Nominal', formatRupiah(tagihan.nominal)),
                      _divider(),
                      _row('Terbayar', formatRupiah(tagihan.nominalTerbayar)),
                      if (!tagihan.selesai) ...[
                        _divider(),
                        _row('Sisa', formatRupiah(tagihan.sisa), bold: true),
                      ],
                      if (tagihan.jatuhTempo != null) ...[
                        _divider(),
                        _row('Jatuh Tempo', formatTanggal(tagihan.jatuhTempo!)),
                      ],
                    ],
                  ),
                ),
                if (showActions) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (tagihan.nominalTerbayar > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () => cetakTagihanFlow(
                                context,
                                widget.anak,
                                tagihan,
                              ),
                              icon: const Icon(Icons.print_outlined, size: 18),
                              label: const Text('Cetak Struk'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _teal,
                                side: const BorderSide(
                                  color: Color(0xFFD8DBE2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!tagihan.selesai) const SizedBox(width: 10),
                      ],
                      if (!tagihan.selesai)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _membukaPembayaran ? null : _bayar,
                              icon: _membukaPembayaran
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.wallet_outlined, size: 18),
                              label: Text(
                                _membukaPembayaran ? 'Membuka...' : 'Bayar',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _divider() =>
      const Divider(height: 20, color: Color(0xFFE9EBEF));

  static Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 13.5,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
