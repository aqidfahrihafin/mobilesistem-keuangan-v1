import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../providers/anak_provider.dart';
import '../screens/pin_setup_screen.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/payment_flow_guard.dart';
import 'glass_modal_surface.dart';
import 'pin_entry_sheet.dart';

const _bg = Color(0xFFF7F8FA);
const _teal = Color(0xFF0F766E);

/// One tagihan's outcome from the bulk-pay loop below - kept even for a
/// success (not just failures), so the results screen can list every
/// selected tagihan with its own icon, not just complain about the ones
/// that failed.
class _HasilBayar {
  final Tagihan tagihan;
  final bool sukses;
  final String? error;

  const _HasilBayar({required this.tagihan, required this.sukses, this.error});
}

/// Pays several tagihan in one wali action - one PIN entry, then a
/// sequential loop over the existing single-tagihan payment endpoint
/// (WaliApi.bayarTagihanDariSaldo), once per selected tagihan. This is
/// deliberate: it's what makes each payment land as its own separate
/// TagihanPembayaran + Transaksi row server-side with zero backend changes,
/// since that's already what the single-payment endpoint does per call.
/// Saldo-only - Midtrans stays a per-tagihan-only path, untouched by this.
///
/// Returns true if at least one payment succeeded (the caller should
/// refresh its tagihan list either way, but this signals whether a saldo
/// refresh actually happened).
Future<bool> bayarTagihanBulkFlow(
  BuildContext context,
  Anak anak,
  List<Tagihan> selected,
) async {
  final hasil = await PaymentFlowGuard.run(
    () => _bayarTagihanBulkFlowUnlocked(context, anak, selected),
  );

  return hasil ?? false;
}

Future<bool> _bayarTagihanBulkFlowUnlocked(
  BuildContext context,
  Anak anak,
  List<Tagihan> selected,
) async {
  int? saldoMinimal;
  try {
    saldoMinimal = await context.read<WaliApi>().getMinimalSaldoBayarTagihan();
  } catch (_) {
    // Non-fatal, same reasoning as the single-payment flow - falls back to
    // not pre-disabling the button; the server still enforces the real
    // floor regardless.
  }

  if (!context.mounted) return false;

  final total = selected.fold<int>(0, (sum, t) => sum + t.sisa);
  final saldo = anak.saldo;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x520F172A),
    builder: (_) => GlassModalSurface(
      child: _BulkKonfirmasiSheet(
        anak: anak,
        selected: selected,
        total: total,
        saldo: saldo,
        saldoMinimal: saldoMinimal,
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  final hasPin = await context.read<WaliApi>().pinStatus();
  if (!context.mounted) return false;

  if (!hasPin) {
    final berhasilBuatPin = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen(forced: true)),
    );
    if (berhasilBuatPin != true || !context.mounted) return false;
  }

  final pin = await showPinEntrySheet(
    context,
    subtitle:
        'Masukkan PIN untuk mengonfirmasi pembayaran ${selected.length} tagihan ini.',
  );
  if (pin == null || !context.mounted) return false;

  final hasilList = await showDialog<List<_HasilBayar>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BulkProsesDialog(anak: anak, selected: selected, pin: pin),
  );

  if (hasilList == null || !context.mounted) return false;

  final adaYangBerhasil = hasilList.any((h) => h.sukses);
  if (adaYangBerhasil) {
    // Mirrors what the single-payment flow already does - the loop just
    // ran, mutating saldo up to N times, and AnakProvider has no way to
    // know that on its own.
    await context.read<AnakProvider>().refreshSaldoSelected();
  }

  return adaYangBerhasil;
}

class _BulkKonfirmasiSheet extends StatelessWidget {
  final Anak anak;
  final List<Tagihan> selected;
  final int total;
  final int saldo;
  final int? saldoMinimal;

  const _BulkKonfirmasiSheet({
    required this.anak,
    required this.selected,
    required this.total,
    required this.saldo,
    required this.saldoMinimal,
  });

  @override
  Widget build(BuildContext context) {
    final saldoCukup = saldo >= total;
    final saldoBolehDipakai =
        saldoMinimal == null || (saldo - total) >= saldoMinimal!;
    final bisaBayar = saldoCukup && saldoBolehDipakai;
    final saldoSetelah = (saldo - total).clamp(0, saldo);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${selected.length} Tagihan Dipilih',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Dibayar dari saldo ${anak.nama}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: selected.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: Color(0xFFE9EBEF),
                  indent: 14,
                  endIndent: 14,
                ),
                itemBuilder: (context, index) {
                  final t = selected[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.jenisTagihanNama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                t.periodeLabel,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatRupiah(t.sisa),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _RingkasBulkRow(
                    label: 'Total dibayar',
                    value: formatRupiah(total),
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE9EBEF)),
                  const SizedBox(height: 8),
                  _RingkasBulkRow(
                    label: 'Saldo saat ini',
                    value: formatRupiah(saldo),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE9EBEF)),
                  const SizedBox(height: 8),
                  _RingkasBulkRow(
                    label: 'Saldo setelah dibayar',
                    value: formatRupiah(saldoSetelah),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !saldoCukup
                  ? 'Saldo ${anak.nama} tidak cukup untuk membayar semua tagihan ini sekaligus. Coba pilih lebih sedikit tagihan, atau bayar salah satunya langsung via Midtrans.'
                  : !saldoBolehDipakai
                  ? 'Membayar semua tagihan ini akan membuat saldo di bawah batas minimum. Coba pilih lebih sedikit tagihan.'
                  : 'Saldo akan langsung dipotong sebesar total di atas untuk seluruh tagihan yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: bisaBayar ? Colors.grey[500] : const Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: bisaBayar ? _teal : Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: bisaBayar
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('Bayar Sekarang'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingkasBulkRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _RingkasBulkRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 16 : 13.5,
          ),
        ),
      ],
    );
  }
}

/// Non-dismissible (the wali shouldn't be able to swipe away mid-payment) -
/// runs the sequential pay loop on arrival, shows which tagihan is
/// currently being paid (several sequential HTTP calls can take a few
/// seconds - a silent block would read as hung), then flips in place to a
/// results list once every tagihan has been attempted. Continue-on-error:
/// one failure (rare, since the confirmation step already pre-checked total
/// saldo) doesn't stop the rest from being attempted, so the results screen
/// can report exactly what happened to each one.
class _BulkProsesDialog extends StatefulWidget {
  final Anak anak;
  final List<Tagihan> selected;
  final String pin;

  const _BulkProsesDialog({
    required this.anak,
    required this.selected,
    required this.pin,
  });

  @override
  State<_BulkProsesDialog> createState() => _BulkProsesDialogState();
}

class _BulkProsesDialogState extends State<_BulkProsesDialog> {
  int _sedangDiproses = 0;
  List<_HasilBayar>? _hasil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proses());
  }

  Future<void> _proses() async {
    final hasil = <_HasilBayar>[];

    for (var i = 0; i < widget.selected.length; i++) {
      if (!mounted) return;
      setState(() => _sedangDiproses = i);

      final tagihan = widget.selected[i];
      try {
        await context.read<WaliApi>().bayarTagihanDariSaldo(
          widget.anak.id,
          tagihan.id,
          pin: widget.pin,
        );
        hasil.add(_HasilBayar(tagihan: tagihan, sukses: true));
      } on ApiException catch (e) {
        hasil.add(
          _HasilBayar(tagihan: tagihan, sukses: false, error: e.message),
        );
      } catch (e) {
        hasil.add(_HasilBayar(tagihan: tagihan, sukses: false, error: '$e'));
      }
    }

    if (mounted) setState(() => _hasil = hasil);
  }

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: hasil == null ? _buildProgress() : _buildHasil(hasil),
      ),
    );
  }

  Widget _buildProgress() {
    final tagihan = widget.selected[_sedangDiproses];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: _teal, strokeWidth: 3),
        const SizedBox(height: 18),
        Text(
          'Membayar ${_sedangDiproses + 1} dari ${widget.selected.length}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          '${tagihan.jenisTagihanNama} • ${tagihan.periodeLabel}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHasil(List<_HasilBayar> hasil) {
    final berhasil = hasil.where((h) => h.sukses).toList();
    final totalTerbayar = berhasil.fold<int>(
      0,
      (sum, h) => sum + h.tagihan.sisa,
    );
    final semuaBerhasil = berhasil.length == hasil.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (semuaBerhasil ? _teal : const Color(0xFFB45309))
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              semuaBerhasil ? Icons.check_circle_rounded : Icons.info_rounded,
              color: semuaBerhasil ? _teal : const Color(0xFFB45309),
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          semuaBerhasil
              ? 'Semua Tagihan Berhasil Dibayar'
              : '${berhasil.length} dari ${hasil.length} Tagihan Berhasil Dibayar',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Total ${formatRupiah(totalTerbayar)} terbayar dari saldo ${widget.anak.nama}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: hasil.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: Color(0xFFE9EBEF),
              indent: 14,
              endIndent: 14,
            ),
            itemBuilder: (context, index) {
              final h = hasil[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      h.sukses
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 16,
                      color: h.sukses
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${h.tagihan.jenisTagihanNama} • ${h.tagihan.periodeLabel}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!h.sukses && h.error != null)
                            Text(
                              h.error!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (h.sukses)
                      Text(
                        formatRupiah(h.tagihan.sisa),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(hasil),
            child: const Text('Selesai'),
          ),
        ),
      ],
    );
  }
}
