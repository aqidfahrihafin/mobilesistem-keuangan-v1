import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/unit_usaha.dart';
import '../providers/anak_provider.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/payment_flow_guard.dart';
import '../widgets/anak_switcher.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/qr_scanner_frame.dart';
import '../widgets/saldo_minimum_notice.dart';
import '../widgets/santri_summary_card.dart';
import '../widgets/success_dialog.dart';
import '../widgets/transaction_progress_dialog.dart';
import 'pin_setup_screen.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Scan a kantin's QR code and pay directly from the selected anak's saldo -
/// same "push a screen, don't own a permanent nav slot" shape as Top Up,
/// entered from a quick-action tile on Home rather than a bottom-nav tab or
/// the existing Top Up FAB (see home_tab.dart).
class ScanBayarScreen extends StatefulWidget {
  const ScanBayarScreen({super.key});

  @override
  State<ScanBayarScreen> createState() => _ScanBayarScreenState();
}

class _ScanBayarScreenState extends State<ScanBayarScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _nominalController = TextEditingController();
  final _nominalFocus = FocusNode();

  bool _looking = false;
  String? _lookupError;
  UnitUsaha? _unitUsaha;

  bool _submitting = false;
  String? _payError;

  // Resolved once up front, not re-fetched per keystroke/anak switch - a
  // kantin payment is wali-initiated through the app just like a transfer,
  // so it's subject to the same minimum-saldo floor (see SaldoFloorService
  // on the server / TransferSaldoScreen's identical pattern).
  int? _minimalSaldo;

  @override
  void initState() {
    super.initState();
    _nominalFocus.addListener(_refreshNominal);
    _loadMinimal();
  }

  void _refreshNominal() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMinimal() async {
    try {
      final minimal = await context
          .read<WaliApi>()
          .getMinimalSaldoBayarTagihan();
      if (mounted) setState(() => _minimalSaldo = minimal);
    } catch (_) {
      // Non-fatal: fails open (form stays enabled) - the server still
      // enforces the real floor regardless of whether this succeeded.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nominalFocus
      ..removeListener(_refreshNominal)
      ..dispose();
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_looking || _unitUsaha != null) return;

    final kode = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (kode == null || kode.isEmpty) return;

    setState(() {
      _looking = true;
      _lookupError = null;
    });
    await _controller.stop();
    if (!mounted) return;

    try {
      final unit = await context.read<WaliApi>().lookupUnitUsaha(kode);
      if (!mounted) return;
      setState(() => _unitUsaha = unit);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _lookupError = e.message);
      await _controller.start();
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _scanUlang() {
    setState(() {
      _unitUsaha = null;
      _lookupError = null;
      _payError = null;
      _nominalController.clear();
    });
    _controller.start();
  }

  Future<void> _bayar() async {
    final anak = context.read<AnakProvider>().selected;
    if (anak == null || _unitUsaha == null) return;

    final nominal = int.tryParse(_nominalController.text.replaceAll('.', ''));
    if (nominal == null || nominal <= 0) {
      setState(() => _payError = 'Masukkan nominal yang valid.');
      return;
    }

    // Belt-and-suspenders - the nominal field/button are already disabled
    // whenever saldo is at/under the floor (see _buildBayarForm), this just
    // guards the rare case _bayar() fires anyway.
    final minimal = _minimalSaldo;
    if (minimal != null && anak.saldo - nominal < minimal) {
      setState(
        () => _payError =
            'Pembayaran ini akan membuat saldo ${anak.nama} di bawah batas minimum ${formatRupiah(minimal)}.',
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      icon: Icons.storefront_rounded,
      title: 'Bayar ke ${_unitUsaha!.nama}?',
      content: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _ringkasRow('Untuk', anak.nama),
            const SizedBox(height: 8),
            _ringkasRow('Nominal', formatRupiah(nominal), bold: true),
          ],
        ),
      ),
      confirmText: 'Ya, Bayar',
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
      subtitle:
          'Masukkan PIN untuk mengonfirmasi pembayaran ke ${_unitUsaha!.nama}.',
    );
    if (pin == null || !mounted) return;

    setState(() {
      _submitting = true;
      _payError = null;
    });
    final startedAt = DateTime.now();
    final requestId = transactionRequestId('kantin', [
      anak.id,
      _unitUsaha!.kode,
      nominal,
    ]);

    try {
      final hasil = await runWithTransactionProgress(
        context,
        message:
            'Sedang memproses pembayaran. Jangan tutup aplikasi atau membayar ulang.',
        action: () => context.read<WaliApi>().bayarKantin(
          anak.id,
          _unitUsaha!.kode,
          nominal,
          pin: pin,
          requestId: requestId,
        ),
      );
      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'Pembayaran Berhasil',
        subtitle:
            '${formatRupiah(hasil.nominal)} telah dibayarkan ke ${hasil.unitUsahaNama}.',
        rincian: [
          ('Kantin', hasil.unitUsahaNama),
          ('Nominal', formatRupiah(hasil.nominal)),
          ('Sisa Saldo', formatRupiah(hasil.saldoSesudah)),
        ],
        // Runs while the dialog above is already showing, so the balance
        // card behind it is already fresh by the time "Selesai" is tapped.
        sinkronkan: () => context.read<AnakProvider>().refreshSaldoSelected(),
      );

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (e.statusCode == null && mounted) {
        try {
          final transaksi = await runWithTransactionProgress(
            context,
            message:
                'Koneksi terputus. Sedang memastikan hasil pembayaran...',
            action: () => context.read<WaliApi>().getTransaksi(anak.id),
          );
          final tercatat = transaksi.any(
            (item) =>
                item.jenis == 'pembayaran_kantin' &&
                item.nominal == nominal &&
                item.createdAt.isAfter(
                  startedAt.subtract(const Duration(seconds: 30)),
                ),
          );
          if (tercatat && mounted) {
            await showSuccessDialog(
              context,
              title: 'Pembayaran Terkonfirmasi',
              subtitle:
                  'Server telah mencatat pembayaran meskipun koneksi sempat terputus.',
              rincian: [
                ('Kantin', _unitUsaha!.nama),
                ('Nominal', formatRupiah(nominal)),
              ],
              sinkronkan: () =>
                  context.read<AnakProvider>().refreshSaldoSelected(),
            );
            if (mounted) Navigator.of(context).pop();
            return;
          }
        } catch (_) {
          // Leave the result guarded and explain that it must not be retried.
        }
        if (mounted) {
          setState(
            () => _payError =
                'Hasil pembayaran belum dapat dipastikan. Jangan bayar ulang; periksa Riwayat Transaksi terlebih dahulu.',
          );
        }
        return;
      }
      setState(() => _payError = e.errorFor('nominal') ?? e.message);
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
    // Only the camera-scanner state wants a black canvas (behind the
    // transparent app bar) - leaving the whole Scaffold permanently black
    // was the cause of a real bug: once past the scanner, any area not
    // covered by the form's own white/_bg containers (e.g. while the
    // keyboard animates in/out) showed through as solid black instead of
    // the page background.
    return Scaffold(
      backgroundColor: _unitUsaha == null ? Colors.black : _bg,
      appBar: AppBar(
        backgroundColor: _unitUsaha == null ? Colors.transparent : Colors.white,
        foregroundColor: _unitUsaha == null ? Colors.white : Colors.black87,
        elevation: 0,
        title: const Text('Scan & Bayar'),
        leading: _unitUsaha == null
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: _unitUsaha == null
            ? [
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, child) {
                    final on = state.torchState == TorchState.on;
                    return IconButton(
                      icon: Icon(
                        on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      ),
                      onPressed: () => _controller.toggleTorch(),
                    );
                  },
                ),
              ]
            : null,
      ),
      extendBodyBehindAppBar: _unitUsaha == null,
      body: _unitUsaha == null ? _buildScanner() : _buildBayarForm(_unitUsaha!),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Darkens the camera feed a touch so the white corner brackets and
        // text read clearly regardless of what's behind them - the reference
        // design's scanner is never a plain, undimmed live feed either.
        Container(color: Colors.black.withValues(alpha: 0.15)),
        Center(child: IgnorePointer(child: QrScannerFrame(size: 240))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 56,
          child: Column(
            children: [
              if (_looking)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              const Text(
                'Arahkan ke Kode QRIS Kantin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mendukung pembayaran kantin di lingkungan pondok',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12.5,
                ),
              ),
              if (_lookupError != null) ...[
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _lookupError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBayarForm(UnitUsaha unitUsaha) {
    final anak = context.watch<AnakProvider>().selected;
    final anakList = context.watch<AnakProvider>().anakList;
    final minimal = _minimalSaldo;
    // Blocked, not just "not enough for this specific nominal" - the santri
    // has nothing spendable left at all. The anak switcher below stays
    // enabled regardless, since picking a different anak may resolve this
    // without leaving the screen.
    final diBawahMinimum =
        anak != null && minimal != null && anak.saldo <= minimal;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9EBEF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: _teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unitUsaha.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kode: ${unitUsaha.kode}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _scanUlang,
                    child: const Text('Scan Ulang'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 2),
              child: Text(
                'Bayar dari saldo',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (anak != null)
              SantriSummaryCard(
                anak: anak,
                onTap: anakList.length > 1
                    ? () =>
                          openAnakPicker(context, context.read<AnakProvider>())
                    : null,
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE9EBEF)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _teal,
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (diBawahMinimum) ...[
              const SizedBox(height: 16),
              SaldoMinimumNotice(
                namaSantri: anak.nama,
                minimal: minimal,
                aksi: 'membayar kantin',
              ),
            ],
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
              onChanged: (_) => setState(() => _payError = null),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText:
                    (_nominalFocus.hasFocus ||
                        _nominalController.text.isNotEmpty)
                    ? 'Rp '
                    : null,
                hintText: '15.000',
                errorText: _payError,
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
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (_submitting || anak == null || diBawahMinimum)
                  ? null
                  : _bayar,
              icon: _submitting
                  ? const SizedBox.shrink()
                  : Icon(
                      diBawahMinimum
                          ? Icons.lock_outline_rounded
                          : Icons.storefront_rounded,
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
                      diBawahMinimum ? 'Saldo Belum Cukup' : 'Bayar',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
