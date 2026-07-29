import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/biaya_midtrans.dart';
import '../models/tagihan.dart';
import '../models/topup.dart';
import '../providers/anak_provider.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/metode_topup.dart';
import '../widgets/flat_card.dart';
import '../widgets/topup_result.dart';
import '../widgets/transaction_progress_dialog.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Pays one specific tagihan directly via Midtrans Core API (VA/QRIS),
/// bypassing saldo entirely - the mobile counterpart to the "Bayar Langsung
/// via Midtrans" button on the web wali portal (which uses Snap there,
/// unavailable here since the app has no WebView). Reuses the same
/// method-picker/result-card widgets as TopupTab so it looks and behaves
/// identically, just for a fixed amount (the tagihan's sisa) instead of a
/// free-typed nominal.
///
/// Pops `true` if the tagihan ends up paid before the wali leaves this
/// screen (via the back button or the "Selesai" button), so TagihanTab
/// knows to refresh its list.
class TagihanTopupScreen extends StatefulWidget {
  final Anak anak;
  final Tagihan tagihan;

  const TagihanTopupScreen({
    super.key,
    required this.anak,
    required this.tagihan,
  });

  @override
  State<TagihanTopupScreen> createState() => _TagihanTopupScreenState();
}

class _TagihanTopupScreenState extends State<TagihanTopupScreen> {
  String _metode = daftarMetodeTopup.first.kode;
  bool _submitting = false;
  bool _checking = false;
  String? _error;
  Topup? _topup;
  bool _sudahLunas = false;

  // See TopupTab's identical field - fetched once, best-effort.
  BiayaMidtransSettings? _biaya;

  @override
  void initState() {
    super.initState();
    _loadBiaya();
  }

  Future<void> _loadBiaya() async {
    try {
      final biaya = await context.read<WaliApi>().getBiayaMidtransSettings();
      if (mounted) setState(() => _biaya = biaya);
    } catch (_) {
      // Non-fatal, see TopupTab.
    }
  }

  Future<void> _mulaiBayar() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final topup = await runWithTransactionProgress(
        context,
        message:
            'Sedang membuat instruksi pembayaran. Jangan tutup aplikasi atau menekan tombol berulang kali.',
        action: () => context.read<WaliApi>().bayarTagihanViaMidtrans(
          widget.anak.id,
          widget.tagihan.id,
          _metode,
        ),
      );
      setState(() => _topup = topup);
    } on ApiException catch (e) {
      setState(
        () => _error = e.statusCode == null
            ? 'Instruksi pembayaran belum dapat dipastikan. Jangan membuat pembayaran baru sebelum memeriksa status tagihan.'
            : e.message,
      );
    } catch (e) {
      setState(() => _error = 'Gagal membuat pembayaran: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cekStatus() async {
    final topup = _topup;
    if (topup == null) return;

    setState(() => _checking = true);

    try {
      final updated = await context.read<WaliApi>().syncTopupStatus(topup.id);
      setState(() => _topup = updated);

      if (updated.isPaid && mounted) {
        setState(() => _sudahLunas = true);
        await context.read<AnakProvider>().refreshSaldoSelected();
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

  void _pilihMetodeLain() {
    setState(() {
      _topup = null;
      _error = null;
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
    final tagihan = widget.tagihan;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Bayar Langsung via Midtrans'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(_sudahLunas),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: _teal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tagihan.jenisTagihanNama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tagihan.periodeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFEEF0F3)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Sisa Tagihan',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(tagihan.sisa),
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_topup == null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _teal.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: _teal,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pembayaran ini langsung melunasi tagihan tanpa mengurangi saldo santri yang sudah ada.',
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
              const SizedBox(height: 22),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...daftarMetodeTopup.map(
                (metode) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MetodeTile(
                    metode: metode,
                    selected: _metode == metode.kode,
                    onTap: () => setState(() => _metode = metode.kode),
                    biayaEstimasi: _biaya?.dibebankanWaliTagihan == true
                        ? _biaya!.hitung(metode.kode, tagihan.sisa)
                        : null,
                  ),
                ),
              ),
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
              if (_biaya?.dibebankanWaliTagihan == true) ...[
                const SizedBox(height: 16),
                FlatCard(
                  child: JumlahBayarRow(
                    nominal: tagihan.sisa,
                    biaya: _biaya!.hitung(_metode, tagihan.sisa),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _submitting ? null : _mulaiBayar,
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
                label: Text(_submitting ? 'Memproses...' : 'Bayar Sekarang'),
              ),
            ] else ...[
              if (_topup!.isVa)
                VaCard(topup: _topup!, onSalin: _salinVaNumber)
              else if (_topup!.isQris)
                QrisCard(topup: _topup!)
              else
                TopupStatusCard(topup: _topup!),
              const SizedBox(height: 16),
              CaraBayarCard(metode: metodeTopupByKode(_topup!.paymentType)),
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
                  onPressed: _pilihMetodeLain,
                  child: const Text('Pilih Metode Lain'),
                ),
              ] else if (_topup!.isPaid)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Selesai'),
                )
              else
                OutlinedButton(
                  onPressed: _pilihMetodeLain,
                  child: const Text('Coba Lagi'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
