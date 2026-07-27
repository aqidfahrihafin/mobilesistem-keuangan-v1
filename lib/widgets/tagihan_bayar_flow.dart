import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../providers/anak_provider.dart';
import '../providers/app_info_provider.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/tagihan_topup_screen.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/payment_flow_guard.dart';
import '../utils/struk.dart';
import 'confirm_dialog.dart';
import 'glass_modal_surface.dart';
import 'pin_entry_sheet.dart';
import 'success_dialog.dart';

const _bg = Color(0xFFF7F8FA);
const _teal = Color(0xFF0F766E);

/// The full "Bayar Tagihan" flow - shared between TagihanTab's card and
/// TagihanDetailScreen so both trigger the exact same PIN-gated payment
/// logic instead of two copies drifting apart. Handles both payment paths
/// (from saldo, or via Midtrans without touching saldo) and returns true if
/// the tagihan's state actually changed, so the caller knows to refresh its
/// own view and saldo. Shows its own error feedback (SnackBar) - callers
/// don't need to catch anything themselves.
///
/// The sheet's content lives in its own [_BayarSaldoSheet] StatefulWidget
/// (not a StatefulBuilder inline here) deliberately - a StatefulBuilder
/// nested directly in showModalBottomSheet's builder, combined with a
/// TextField driving MediaQuery-dependent rebuilds on every keystroke,
/// reliably crashed with "_dependents.isEmpty" / "Looking up a
/// deactivated widget's ancestor is unsafe" while typing in the nominal
/// field. A real State object with its own TextEditingController
/// lifecycle avoids that whole class of route/rebuild ordering bug.
Future<bool> bayarTagihanFlow(
  BuildContext context,
  Anak anak,
  Tagihan tagihan,
) async {
  final hasil = await PaymentFlowGuard.run(
    () => _bayarTagihanFlowUnlocked(context, anak, tagihan),
  );

  return hasil ?? false;
}

Future<bool> _bayarTagihanFlowUnlocked(
  BuildContext context,
  Anak anak,
  Tagihan tagihan,
) async {
  int? saldoMinimal;
  try {
    saldoMinimal = await context.read<WaliApi>().getMinimalSaldoBayarTagihan();
  } catch (_) {
    // Non-fatal: falls back to not pre-disabling "Bayar dari Saldo" below -
    // the server still enforces the real floor regardless of whether this
    // pre-check succeeded.
  }

  if (!context.mounted) return false;

  final saldo = anak.saldo;
  final saldoBisaDigunakan = saldoMinimal == null
      ? saldo
      : (saldo - saldoMinimal).clamp(0, saldo);

  final hasil = await showModalBottomSheet<_BayarSaldoHasil>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x520F172A),
    builder: (_) => GlassModalSurface(
      child: _BayarSaldoSheet(
        tagihan: tagihan,
        saldo: saldo,
        saldoMinimal: saldoMinimal,
        saldoBisaDigunakan: saldoBisaDigunakan,
      ),
    ),
  );

  if (hasil == null || !context.mounted) return false;

  if (hasil.viaMidtrans) {
    return _bayarViaMidtrans(context, anak, tagihan);
  }

  final nominalDibayar = hasil.nominal ?? tagihan.sisa;
  final sisaSetelah = (tagihan.sisa - nominalDibayar).clamp(0, tagihan.sisa);
  final saldoSetelah = (saldo - nominalDibayar).clamp(0, saldo);

  // A shared ConfirmDialog (not another bottom sheet) - it opens only
  // after the sheet above has fully closed, so there's no risk of the
  // TextField/StatefulBuilder rebuild-ordering bug that crashed the sheet
  // itself before (see the doc comment above). This is the actual "final
  // answer" tap - nothing is charged until this returns true.
  final konfirmasi = await ConfirmDialog.show(
    context,
    icon: Icons.account_balance_wallet_rounded,
    title: 'Konfirmasi Pembayaran',
    confirmText: 'Ya, Bayar Sekarang',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${formatRupiah(nominalDibayar)} akan didebit dari saldo untuk membayar '
          '${tagihan.jenisTagihanNama} - ${tagihan.periodeLabel}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _RincianRow(
                label: sisaSetelah > 0
                    ? 'Sisa tagihan setelah ini'
                    : 'Status tagihan setelah ini',
                value: sisaSetelah > 0 ? formatRupiah(sisaSetelah) : 'Lunas',
              ),
              const SizedBox(height: 6),
              _RincianRow(
                label: 'Saldo setelah dibayar',
                value: formatRupiah(saldoSetelah),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
        ),
      ],
    ),
  );

  if (konfirmasi != true || !context.mounted) return false;

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
    subtitle: 'Masukkan PIN untuk mengonfirmasi pembayaran tagihan ini.',
  );
  if (pin == null || !context.mounted) return false;

  try {
    await context.read<WaliApi>().bayarTagihanDariSaldo(
      anak.id,
      tagihan.id,
      nominal: tagihan.bisaDicicil ? hasil.nominal : null,
      pin: pin,
    );
    if (!context.mounted) return false;

    final sisaSetelahBayar = (tagihan.sisa - nominalDibayar).clamp(
      0,
      tagihan.sisa,
    );

    await showSuccessDialog(
      context,
      title: 'Pembayaran Berhasil',
      subtitle: sisaSetelahBayar > 0
          ? '${formatRupiah(nominalDibayar)} dibayar dari saldo ${anak.nama}.'
          : '${tagihan.jenisTagihanNama} - ${tagihan.periodeLabel} sekarang lunas.',
      rincian: [
        ('Nominal Dibayar', formatRupiah(nominalDibayar)),
        if (sisaSetelahBayar > 0)
          ('Sisa Tagihan', formatRupiah(sisaSetelahBayar))
        else
          ('Status', 'Lunas'),
        ('Saldo Setelah Dibayar', formatRupiah(saldoSetelah)),
      ],
      // Runs while the dialog above is already showing - by the time the
      // wali taps "Selesai", the balance card behind this is already
      // showing the post-payment saldo instead of updating a beat later.
      sinkronkan: () => context.read<AnakProvider>().refreshSaldoSelected(),
    );

    return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red,
        action: e.code == 'saldo_di_bawah_minimum'
            ? SnackBarAction(
                label: 'Via Midtrans',
                textColor: Colors.white,
                onPressed: () => _bayarViaMidtrans(context, anak, tagihan),
              )
            : null,
      ),
    );
    return false;
  }
}

Future<bool> _bayarViaMidtrans(
  BuildContext context,
  Anak anak,
  Tagihan tagihan,
) async {
  final berhasil = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TagihanTopupScreen(anak: anak, tagihan: tagihan),
    ),
  );

  if (berhasil == true && context.mounted) {
    await context.read<AnakProvider>().refreshSaldoSelected();
    return true;
  }

  return false;
}

/// Prints the struk for an already (at least partially) paid tagihan - a
/// thin wrapper so callers don't need to import `utils/struk.dart` directly.
Future<void> cetakTagihanFlow(
  BuildContext context,
  Anak anak,
  Tagihan tagihan,
) async {
  await cetakStrukTagihan(
    anak: anak,
    tagihan: tagihan,
    namaPondok:
        context.read<AppInfoProvider>().namaPondok ?? 'Pondok Pesantren Latee',
  );
}

class _RincianRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _RincianRow({
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
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 16 : 13.5,
          ),
        ),
      ],
    );
  }
}

/// What [_BayarSaldoSheet] hands back to the caller when it's popped with
/// an actual choice (as opposed to null, i.e. dismissed/"Batal").
class _BayarSaldoHasil {
  final bool viaMidtrans;
  final int? nominal;

  const _BayarSaldoHasil.saldo(this.nominal) : viaMidtrans = false;

  const _BayarSaldoHasil.midtrans() : viaMidtrans = true, nominal = null;
}

/// The "Bayar Tagihan" bottom sheet's content - see [bayarTagihanFlow]'s
/// doc comment for why this is a real StatefulWidget rather than a
/// StatefulBuilder inline in showModalBottomSheet's builder. Owns its own
/// nominal TextEditingController end to end, and doubles as the "rincian
/// sebelum bayar" confirmation: nothing is charged until the wali
/// explicitly taps "Ya, Bayar dari Saldo" after reviewing the breakdown
/// below - there's no separate second dialog stacked on top, since that's
/// an unusual pattern for a bottom sheet on mobile.
class _BayarSaldoSheet extends StatefulWidget {
  final Tagihan tagihan;
  final int saldo;
  final int? saldoMinimal;
  final int saldoBisaDigunakan;

  const _BayarSaldoSheet({
    required this.tagihan,
    required this.saldo,
    required this.saldoMinimal,
    required this.saldoBisaDigunakan,
  });

  @override
  State<_BayarSaldoSheet> createState() => _BayarSaldoSheetState();
}

class _BayarSaldoSheetState extends State<_BayarSaldoSheet> {
  late final TextEditingController _nominalController;

  @override
  void initState() {
    super.initState();
    _nominalController = TextEditingController(
      text: widget.tagihan.sisa.toString(),
    );
  }

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagihan = widget.tagihan;
    final saldo = widget.saldo;
    final saldoMinimal = widget.saldoMinimal;

    final nominalDibayar =
        int.tryParse(_nominalController.text) ?? tagihan.sisa;
    final nominalValid = nominalDibayar > 0 && nominalDibayar <= tagihan.sisa;
    final saldoCukup = nominalValid && saldo >= nominalDibayar;
    final saldoBolehDipakai =
        nominalValid &&
        (saldoMinimal == null || (saldo - nominalDibayar) >= saldoMinimal);
    final saldoBisaDipakai = saldoCukup && saldoBolehDipakai;
    final sisaSetelah = nominalValid
        ? (tagihan.sisa - nominalDibayar).clamp(0, tagihan.sisa)
        : tagihan.sisa;

    return SafeArea(
      // Wrapped in SingleChildScrollView - with both payment options plus
      // the saldo breakdown, this sheet's content can be slightly taller
      // than the available height on shorter screens/larger font scales,
      // which would otherwise overflow instead of just scrolling.
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _teal,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bayar Tagihan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '${tagihan.jenisTagihanNama} • ${tagihan.periodeLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (tagihan.bisaDicicil) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nominal yang dibayar dari saldo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    isDense: true,
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nominalValid
                      ? 'Tagihan ini boleh dicicil - boleh kurang dari sisa tagihan (${formatRupiah(tagihan.sisa)}).'
                      : 'Nominal harus antara Rp 1 dan sisa tagihan (${formatRupiah(tagihan.sisa)}).',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: nominalValid ? Colors.grey[500] : Colors.red[700],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _RincianRow(
                      label: 'Nominal dibayar',
                      value: formatRupiah(nominalDibayar),
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE9EBEF)),
                    const SizedBox(height: 8),
                    _RincianRow(
                      label: sisaSetelah > 0
                          ? 'Sisa tagihan setelah ini'
                          : 'Status tagihan setelah ini',
                      value: sisaSetelah > 0
                          ? formatRupiah(sisaSetelah)
                          : 'Lunas',
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE9EBEF)),
                    const SizedBox(height: 8),
                    _RincianRow(
                      label: 'Saldo bisa digunakan',
                      value: formatRupiah(widget.saldoBisaDigunakan),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE9EBEF)),
                    const SizedBox(height: 8),
                    _RincianRow(
                      label: 'Saldo setelah dibayar',
                      value: formatRupiah(
                        (saldo - nominalDibayar).clamp(0, saldo),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                !nominalValid
                    ? 'Perbaiki nominal di atas terlebih dahulu.'
                    : !saldoCukup
                    ? 'Saldo santri tidak mencukupi untuk nominal ini.'
                    : !saldoBolehDipakai
                    ? 'Membayar dari saldo akan membuat saldo santri di bawah batas minimum.'
                    : 'Saldo santri akan langsung dipotong sebesar jumlah ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: saldoBisaDipakai
                        ? _teal
                        : Colors.grey[300],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: saldoBisaDipakai
                      ? () => Navigator.of(
                          context,
                        ).pop(_BayarSaldoHasil.saldo(nominalDibayar))
                      : null,
                  child: const Text(
                    'Ya, Bayar dari Saldo',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE9EBEF))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'atau',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE9EBEF))),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: Color(0xFFD8DBE2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const _BayarSaldoHasil.midtrans()),
                  child: const Text(
                    'Bayar Langsung via Midtrans',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
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
      ),
    );
  }
}
