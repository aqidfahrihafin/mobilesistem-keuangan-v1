import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../providers/anak_provider.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/glass_modal_surface.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/saldo_minimum_notice.dart';
import '../widgets/santri_summary_card.dart';
import '../widgets/success_dialog.dart';
import 'pin_setup_screen.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Moves saldo directly between two santri who share the same Kartu
/// Keluarga (KK) - "dari" is whichever anak is currently selected app-wide
/// (see AnakProvider), "ke" is picked from that santri's siblings (server-
/// enforced same-KK, not limited to this wali's own linked anak - see
/// SaudaraController on the server). Entered from the Home quick-actions row.
class TransferSaldoScreen extends StatelessWidget {
  const TransferSaldoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final anakProvider = context.watch<AnakProvider>();
    final dari = anakProvider.selected;

    // See tagihan_tab.dart's identical check - a failed anak-list fetch and
    // "this wali genuinely has no santri" are different situations and
    // deserve different messages.
    Widget body;
    if (anakProvider.error != null) {
      body = ListView(
        children: [
          const SizedBox(height: 100),
          ErrorStateView(
            error: anakProvider.error!,
            onRetry: () => context.read<AnakProvider>().load(),
          ),
        ],
      );
    } else if (dari == null) {
      body = const EmptyStateView(
        icon: Icons.people_outline,
        message: 'Belum ada santri yang tertaut.',
      );
    } else {
      // Keyed by dari.id so switching the sender elsewhere in the app
      // (e.g. the Home balance card switcher) rebuilds this whole form
      // fresh - new sibling list, cleared recipient/nominal - instead of
      // carrying over a stale selection from a different santri. Same
      // pattern as home_tab.dart's _AnakDashboard.
      body = _TransferForm(key: ValueKey(dari.id), dari: dari);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Transfer Saldo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Info transfer',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Transfer keluarga'),
                content: const Text(
                  'Transfer hanya dapat dilakukan ke santri dalam satu Kartu Keluarga. Saldo pengirim juga harus tetap berada di atas batas minimum.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Mengerti'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _TransferForm extends StatefulWidget {
  final Anak dari;

  const _TransferForm({super.key, required this.dari});

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  late Future<List<Anak>> _saudaraFuture;
  final _nominalController = TextEditingController();
  final _nominalFocus = FocusNode();

  Anak? _ke;
  bool _submitting = false;
  String? _nominalError;

  // Resolved once up front (not left as a FutureBuilder threaded through
  // the form) since the whole form's visibility depends on it - if the
  // sender's saldo is already at/under this floor, the form never renders
  // at all (see build() below), not just a disabled nominal field.
  bool _loadingMinimal = true;
  int? _minimalSaldo;

  @override
  void initState() {
    super.initState();
    _saudaraFuture = context.read<WaliApi>().getSaudara(widget.dari.id);
    _nominalFocus.addListener(_refreshNominal);
    _loadMinimal();
  }

  void _refreshNominal() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMinimal() async {
    // Transfer is wali-initiated, not the santri's own spending, so it's
    // subject to the same minimum-saldo floor as paying a tagihan from
    // saldo (see SaldoFloorService on the server) - unlike a kantin
    // purchase, which the santri chooses themselves and isn't floor-gated.
    try {
      final minimal = await context
          .read<WaliApi>()
          .getMinimalSaldoBayarTagihan();
      if (mounted) setState(() => _minimalSaldo = minimal);
    } catch (_) {
      // Non-fatal: fails open (form still shows) - the server still
      // enforces the real floor regardless of whether this succeeded.
    } finally {
      if (mounted) setState(() => _loadingMinimal = false);
    }
  }

  @override
  void dispose() {
    _nominalFocus
      ..removeListener(_refreshNominal)
      ..dispose();
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _pilihPenerima(List<Anak> saudara) async {
    final dipilih = await showModalBottomSheet<Anak>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x520F172A),
      builder: (sheetContext) {
        return GlassModalSurface(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kirim ke Santri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                ...saudara.map((anak) {
                  final isSelected = anak.id == _ke?.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _teal,
                      child: Text(
                        anak.nama.isNotEmpty ? anak.nama[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      anak.nama,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${anak.nis} • ${anak.lembaga ?? 'Pondok Pusat'}',
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: _teal)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(anak),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (dipilih != null) setState(() => _ke = dipilih);
  }

  Future<void> _kirim() async {
    final ke = _ke;
    if (ke == null) return;

    final nominal = int.tryParse(_nominalController.text.replaceAll('.', ''));
    if (nominal == null || nominal <= 0) {
      setState(() => _nominalError = 'Masukkan nominal yang valid.');
      return;
    }
    if (nominal > widget.dari.saldo) {
      setState(
        () => _nominalError = 'Saldo ${widget.dari.nama} tidak mencukupi.',
      );
      return;
    }

    // Pre-check against the minimum-saldo floor (already resolved in
    // initState - see _loadMinimal()) so a wali sees why a transfer is
    // blocked immediately, instead of only after confirming and entering a
    // PIN. The server enforces this regardless (see TransferSaldoService),
    // this is purely for a faster, clearer no.
    final minimalSaldo = _minimalSaldo;
    if (minimalSaldo != null && widget.dari.saldo - nominal < minimalSaldo) {
      setState(
        () => _nominalError =
            'Transfer ini akan membuat saldo ${widget.dari.nama} di bawah batas minimum ${formatRupiah(minimalSaldo)}.',
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      icon: Icons.send_rounded,
      title: 'Transfer ke ${ke.nama}?',
      content: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _ringkasRow('Dari', widget.dari.nama),
            const SizedBox(height: 8),
            _ringkasRow('Ke', ke.nama),
            const SizedBox(height: 8),
            _ringkasRow('Nominal', formatRupiah(nominal), bold: true),
          ],
        ),
      ),
      confirmText: 'Ya, Transfer',
    );

    if (confirmed != true || !mounted) return;

    final hasPin = await context.read<WaliApi>().pinStatus();
    if (!mounted) return;

    if (!hasPin) {
      final berhasilBuatPin = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen(forced: true)),
      );
      if (berhasilBuatPin != true || !mounted) return;
    }

    final pin = await showPinEntrySheet(
      context,
      subtitle: 'Masukkan PIN untuk mengonfirmasi transfer ke ${ke.nama}.',
    );
    if (pin == null || !mounted) return;

    setState(() {
      _submitting = true;
      _nominalError = null;
    });

    try {
      final hasil = await context.read<WaliApi>().transferSaldo(
        dariSantriId: widget.dari.id,
        keSantriId: ke.id,
        nominal: nominal,
        pin: pin,
      );
      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'Transfer Berhasil',
        subtitle:
            '${formatRupiah(hasil.nominal)} telah dikirim ke ${hasil.keNama}.',
        rincian: [
          ('Dari', hasil.dariNama),
          ('Ke', hasil.keNama),
          ('Nominal Transfer', formatRupiah(hasil.nominal)),
        ],
        // Runs while the dialog above is already showing - both balances
        // are already fresh by the time the wali taps "Selesai" and lands
        // back on Home, instead of updating visibly a beat later.
        sinkronkan: () async {
          final anakProvider = context.read<AnakProvider>();
          await anakProvider.refreshSaldoFor(hasil.dariId);
          await anakProvider.refreshSaldoFor(hasil.keId);
        },
      );

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _nominalError = e.errorFor('nominal') ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _ringkasRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 12.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMinimal) {
      return const Center(child: CircularProgressIndicator());
    }

    final minimal = _minimalSaldo;
    // Sender's saldo already sits at/under the floor - there's nothing
    // transferable. Same "can't proceed" fact as the kantin payment floor
    // (see scan_bayar_screen.dart's diBawahMinimum), so it gets the same
    // treatment: keep the form visible (recipient picker, nominal, button)
    // but disabled, with an inline warning explaining why - rather than
    // replacing the whole screen with a blocked-state message, which read
    // as less clear about what's actually going on ("biar langsung faham
    // usernya").
    final diBawahMinimum = minimal != null && widget.dari.saldo <= minimal;

    return FutureBuilder<List<Anak>>(
      future: _saudaraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorStateView(
            error: snapshot.error!,
            onRetry: () => setState(
              () => _saudaraFuture = context.read<WaliApi>().getSaudara(
                widget.dari.id,
              ),
            ),
          );
        }

        final saudara = snapshot.data ?? [];

        if (saudara.isEmpty) {
          return EmptyStateView(
            icon: Icons.family_restroom_outlined,
            message:
                '${widget.dari.nama} tidak memiliki saudara lain (satu Kartu Keluarga) yang terdaftar di aplikasi ini.',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only one status message shown at a time - the specific
              // SaldoMinimumNotice below fully replaces this generic rules
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Dari',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              SantriSummaryCard(anak: widget.dari),
              if (diBawahMinimum) ...[
                const SizedBox(height: 16),
                SaldoMinimumNotice(
                  namaSantri: widget.dari.nama,
                  minimal: minimal,
                  aksi: 'transfer',
                ),
              ],
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Ke',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: diBawahMinimum ? null : () => _pilihPenerima(saudara),
                borderRadius: BorderRadius.circular(10),
                child: _ke == null
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: diBawahMinimum
                              ? const Color(0xBFE8EEED)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: diBawahMinimum
                                ? const Color(0x6694A3A0)
                                : const Color(0xFFE2E8E4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: diBawahMinimum
                                    ? Colors.grey.withValues(alpha: 0.12)
                                    : _teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                diBawahMinimum
                                    ? Icons.lock_outline_rounded
                                    : Icons.person_add_alt_rounded,
                                color: diBawahMinimum
                                    ? Colors.grey[500]
                                    : _teal,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pilih santri penerima',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!diBawahMinimum)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey[400],
                              ),
                          ],
                        ),
                      )
                    : _AnakRow(anak: _ke!, trailing: Icons.unfold_more_rounded),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Nominal',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              TextField(
                controller: _nominalController,
                focusNode: _nominalFocus,
                enabled: !diBawahMinimum,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _nominalError = null),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  prefixText:
                      (_nominalFocus.hasFocus ||
                          _nominalController.text.isNotEmpty)
                      ? 'Rp '
                      : null,
                  hintText: '50.000',
                  errorText: _nominalError,
                  errorMaxLines: 2,
                  suffixIcon: diBawahMinimum
                      ? Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
              ),
              if (minimal != null && !diBawahMinimum)
                Container(
                  margin: const EdgeInsets.only(top: 9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8E4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: _teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Maksimal transfer ${formatRupiah((widget.dari.saldo - minimal).clamp(0, widget.dari.saldo))}. '
                          'Saldo minimum ${formatRupiah(minimal)} tetap disisakan.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (_submitting || _ke == null || diBawahMinimum)
                    ? null
                    : _kirim,
                icon: _submitting
                    ? const SizedBox.shrink()
                    : Icon(
                        diBawahMinimum
                            ? Icons.lock_outline_rounded
                            : Icons.send_rounded,
                        size: 18,
                      ),
                label: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        diBawahMinimum ? 'Saldo Belum Cukup' : 'Kirim Transfer',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnakRow extends StatelessWidget {
  final Anak anak;
  final IconData? trailing;

  const _AnakRow({required this.anak, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _teal,
            child: Text(
              anak.nama.isNotEmpty ? anak.nama[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anak.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${anak.nis} • ${anak.lembaga ?? 'Pondok Pusat'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}
