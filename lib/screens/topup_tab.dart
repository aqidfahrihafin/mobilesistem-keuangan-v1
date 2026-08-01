import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/biaya_midtrans.dart';
import '../models/topup.dart';
import '../providers/anak_provider.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/metode_topup.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/flat_card.dart';
import '../widgets/santri_summary_card.dart';
import '../widgets/success_dialog.dart';
import '../widgets/topup_result.dart';
import '../widgets/transaction_progress_dialog.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

const _nominalCepat = [100000, 200000, 300000, 400000, 500000];

/// Top up flow built on Midtrans's Core API (WaliApi.mulaiTopupCore) instead
/// of Snap - the server returns a VA number or a QR image URL that this
/// screen renders directly, so the wali never leaves the app. Since payment
/// then happens in their banking app / e-wallet, there's no callback - they
/// come back and tap "Cek Status Sekarang", which pulls the real status
/// straight from Midtrans (TopupWaliService::syncStatusFromMidtrans).
///
/// A top up here always credits 100% to saldo - there's no auto-deduction
/// for outstanding tagihan (that used to be the case; paying a tagihan is
/// now a separate, explicit action from TagihanTab, either from saldo or
/// via its own scoped Midtrans payment - see TagihanTopupScreen).
class TopupTab extends StatefulWidget {
  final bool untukTabungan;

  const TopupTab({super.key, this.untukTabungan = false});

  @override
  State<TopupTab> createState() => _TopupTabState();
}

class _TopupTabState extends State<TopupTab> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();

  String _metode = daftarMetodeTopup.first.kode;
  bool _submitting = false;
  bool _checking = false;
  bool _nominalLainnya = false;
  String? _error;
  Topup? _topup;

  // Fetched once, best-effort - a failed fetch just means no live fee
  // estimate is shown pre-submit (purely decorative); the actual charge is
  // still computed correctly server-side from the real settings regardless.
  BiayaMidtransSettings? _biaya;

  @override
  void initState() {
    super.initState();
    // Rebuilds the quick-nominal chips so the matching one un/highlights as
    // the wali types a custom amount instead of tapping a chip.
    _nominalController.addListener(_onNominalChanged);
    _loadBiaya();
  }

  Future<void> _loadBiaya() async {
    try {
      final biaya = await context.read<WaliApi>().getBiayaMidtransSettings();
      if (mounted) setState(() => _biaya = biaya);
    } catch (_) {
      // Non-fatal, see the _biaya field doc comment above.
    }
  }

  int get _nominalTerketik =>
      int.tryParse(_nominalController.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _nominalController.removeListener(_onNominalChanged);
    _nominalController.dispose();
    super.dispose();
  }

  void _onNominalChanged() => setState(() {});

  void _pilihNominalCepat(int nominal) {
    setState(() => _nominalLainnya = false);
    _nominalController.text = nominal.toString();
  }

  void _pilihNominalLainnya() {
    setState(() {
      _nominalLainnya = true;
      _nominalController.clear();
      _error = null;
    });
  }

  Future<void> _pilihMetodePembayaran() async {
    final dipilih = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih metode pembayaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih satu kanal. Detail pembayaran ditampilkan setelah dikonfirmasi.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),
              for (final metode in daftarMetodeTopup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MetodeTile(
                    metode: metode,
                    selected: _metode == metode.kode,
                    onTap: () => Navigator.pop(context, metode.kode),
                    biayaEstimasi: _biaya?.dibebankanWali == true
                        ? _biaya!.hitung(metode.kode, _nominalTerketik)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (dipilih != null && mounted) setState(() => _metode = dipilih);
  }

  Future<void> _mulaiTopup(int santriId) async {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    if (_nominalTerketik < 10000) {
      setState(() => _error = 'Pilih nominal minimal Rp 10.000.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final nominal = int.parse(_nominalController.text.replaceAll('.', ''));
      final api = context.read<WaliApi>();
      final topup = await runWithTransactionProgress(
        context,
        message:
            'Sedang membuat instruksi pembayaran. Jangan tutup aplikasi atau menekan tombol berulang kali.',
        action: () => widget.untukTabungan
            ? api.mulaiSetoranTabunganMidtrans(santriId, nominal, _metode)
            : api.mulaiTopupCore(santriId, nominal, _metode),
      );
      setState(() => _topup = topup);
    } on ApiException catch (e) {
      setState(
        () => _error = e.statusCode == null
            ? 'Instruksi top up belum dapat dipastikan karena koneksi bermasalah. Periksa riwayat sebelum membuat top up baru.'
            : e.errorFor('nominal') ?? e.message,
      );
    } catch (e) {
      // Anything other than ApiException (a parsing bug, a malformed server
      // response, ...) used to fail silently here - the spinner would just
      // stop with no feedback at all. Surface it instead so a real problem
      // is visible/reportable rather than looking like nothing happened.
      setState(() => _error = 'Gagal membuat top up: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cekStatus() async {
    final topup = _topup;
    if (topup == null) return;

    setState(() => _checking = true);

    try {
      final wasPaidAlready = topup.isPaid;
      final updated = await context.read<WaliApi>().syncTopupStatus(topup.id);
      setState(() => _topup = updated);

      // wasPaidAlready guards against showing the dialog again if a wali
      // taps "Cek Status Sekarang" a second time after it's already paid -
      // this should only fire once, the moment it actually transitions.
      if (updated.isPaid && !wasPaidAlready && mounted) {
        final anak = context.read<AnakProvider>().selected;
        // Computed directly (cached saldo + this top up) rather than read
        // from the provider - refreshSaldoSelected() below runs in the
        // background while the dialog is showing, so anak.saldo here is
        // still the pre-top-up value at the moment this list is built.
        final saldoSetelah = anak != null && !widget.untukTabungan
            ? anak.saldo + updated.nominalDiminta
            : null;

        await showSuccessDialog(
          context,
          title: widget.untukTabungan ? 'Setoran Berhasil' : 'Top Up Berhasil',
          subtitle: anak != null
              ? '${formatRupiah(updated.nominalDiminta)} telah masuk ke ${widget.untukTabungan ? 'tabungan' : 'saldo'} ${anak.nama}.'
              : '${formatRupiah(updated.nominalDiminta)} telah berhasil diterima.',
          rincian: [
            ('Nominal', formatRupiah(updated.nominalDiminta)),
            if (updated.biayaDitanggungWali && updated.biayaMidtrans > 0)
              ('Biaya Admin Midtrans', formatRupiah(updated.biayaMidtrans)),
            if (saldoSetelah != null)
              ('Saldo Setelah Top Up', formatRupiah(saldoSetelah)),
          ],
          // Fires while the dialog above is already showing, so the balance
          // card behind it is already fresh by the time "Selesai" is tapped.
          sinkronkan: widget.untukTabungan
              ? null
              : () => context.read<AnakProvider>().refreshSaldoSelected(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _mulaiLagi() {
    setState(() {
      _topup = null;
      _error = null;
      _nominalLainnya = false;
      _nominalController.clear();
    });
  }

  Future<void> _salinVaNumber(String vaNumber) async {
    await Clipboard.setData(ClipboardData(text: vaNumber));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomor VA disalin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final anakProvider = context.watch<AnakProvider>();
    final anak = anakProvider.selected;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.untukTabungan ? 'Setor Tabungan' : 'Top Up Saldo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // See tagihan_tab.dart's identical check - a failed anak-list fetch
      // and "this wali genuinely has no santri" are different situations
      // and deserve different messages.
      body: anakProvider.error != null
          ? ListView(
              children: [
                const SizedBox(height: 100),
                ErrorStateView(
                  error: anakProvider.error!,
                  onRetry: () => context.read<AnakProvider>().load(),
                ),
              ],
            )
          : anak == null
          ? const EmptyStateView(
              icon: Icons.people_outline,
              message: 'Belum ada santri yang tertaut.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SantriSummaryCard(anak: anak),
                  const SizedBox(height: 16),
                  if (_topup == null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8E4)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.untukTabungan
                                ? 'Pilih Nominal Setoran'
                                : 'Pilih Nominal Top Up',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = 8.0;
                              final itemWidth =
                                  (constraints.maxWidth - gap) / 2;

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  ..._nominalCepat.map(
                                    (nominal) => SizedBox(
                                      width: itemWidth,
                                      child: _NominalChip(
                                        label: formatRupiah(nominal),
                                        selected:
                                            !_nominalLainnya &&
                                            _nominalController.text ==
                                                nominal.toString(),
                                        onTap: () =>
                                            _pilihNominalCepat(nominal),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _NominalChip(
                                      label: 'Lainnya',
                                      selected: _nominalLainnya,
                                      onTap: _pilihNominalLainnya,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_nominalLainnya) ...[
                            const SizedBox(height: 12),
                            Form(
                              key: _formKey,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAF9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFB9D8D3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 9),
                                      child: Text(
                                        'Rp',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _teal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _nominalController,
                                        keyboardType: TextInputType.number,
                                        autofocus: true,
                                        style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: _teal,
                                          letterSpacing: -0.5,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          hintText: 'Minimal 10.000',
                                          hintStyle: TextStyle(
                                            color: _teal.withValues(alpha: 0.3),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                          errorMaxLines: 2,
                                        ),
                                        validator: (value) {
                                          final nominal = int.tryParse(
                                            (value ?? '').replaceAll('.', ''),
                                          );
                                          if (nominal == null) {
                                            return 'Wajib diisi angka';
                                          }
                                          if (nominal < 10000) {
                                            return 'Minimal Rp 10.000';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_nominalTerketik > 0) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final metode =
                              metodeTopupByKode(_metode) ??
                              daftarMetodeTopup.first;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _pilihMetodePembayaran,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE8F5F3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        metode.icon,
                                        color: _teal,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            metode.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Ketuk untuk mengganti metode',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: _teal,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_biaya?.dibebankanWali == true &&
                        _nominalTerketik > 0) ...[
                      const SizedBox(height: 16),
                      FlatCard(
                        child: JumlahBayarRow(
                          nominal: _nominalTerketik,
                          biaya: _biaya!.hitung(_metode, _nominalTerketik),
                        ),
                      ),
                    ],
                    if (_nominalTerketik > 0) ...[
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _submitting
                            ? null
                            : () => _mulaiTopup(anak.id),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          _submitting
                              ? 'Memproses...'
                              : widget.untukTabungan
                              ? 'Buat Setoran'
                              : 'Buat Top Up',
                        ),
                      ),
                    ],
                  ] else ...[
                    if (_topup!.isVa)
                      VaCard(topup: _topup!, onSalin: _salinVaNumber)
                    else if (_topup!.isQris)
                      QrisCard(topup: _topup!)
                    else
                      TopupStatusCard(topup: _topup!),
                    const SizedBox(height: 16),
                    CaraBayarCard(
                      metode: metodeTopupByKode(_topup!.paymentType),
                    ),
                    const SizedBox(height: 16),
                    if (_topup!.isPending) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _checking ? null : _cekStatus,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(
                          _checking ? 'Memeriksa...' : 'Cek Status Sekarang',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _mulaiLagi,
                        child: const Text('Batalkan & Buat Top Up Baru'),
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: _mulaiLagi,
                        child: const Text('Top Up Lagi'),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _NominalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NominalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5F4F1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE2E8F0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _teal : const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? _teal : const Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
