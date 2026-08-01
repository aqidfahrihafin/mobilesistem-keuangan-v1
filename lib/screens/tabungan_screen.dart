import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tabungan.dart';
import '../providers/anak_provider.dart';
import '../providers/tab_index_provider.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/payment_flow_guard.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/flat_card.dart';
import '../widgets/loading_state_view.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/success_dialog.dart';
import '../widgets/transaction_progress_dialog.dart';
import 'topup_tab.dart';

class TabunganScreen extends StatefulWidget {
  const TabunganScreen({super.key});

  @override
  State<TabunganScreen> createState() => _TabunganScreenState();
}

class _TabunganScreenState extends State<TabunganScreen> {
  final _nominal = TextEditingController();
  RingkasanTabungan? _data;
  Object? _error;
  bool _memuat = true;
  bool _menyimpan = false;
  bool _formPindahTerbuka = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _nominal.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final santri = context.read<AnakProvider>().selected;
    if (santri == null) {
      setState(() => _memuat = false);
      return;
    }

    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final data = await context.read<WaliApi>().getTabungan(santri.id);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _pindahDariSaldo() async {
    final santri = context.read<AnakProvider>().selected;
    final nominal = int.tryParse(_nominal.text.replaceAll('.', '')) ?? 0;
    if (santri == null) return;
    if (nominal < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal minimal adalah Rp1.000.')),
      );
      return;
    }
    if (nominal > (_data?.saldoBisaDipindahkan ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal melebihi saldo yang dapat dipindahkan.'),
        ),
      );
      return;
    }

    final dikonfirmasi = await ConfirmDialog.show(
      context,
      icon: Icons.savings_outlined,
      title: 'Pindahkan ke tabungan?',
      content: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.borderRadius,
        ),
        child: Column(
          children: [
            _ringkasanBaris('Santri', santri.nama),
            const SizedBox(height: 8),
            _ringkasanBaris('Nominal', formatRupiah(nominal), tebal: true),
            const SizedBox(height: 8),
            _ringkasanBaris(
              'Sisa saldo',
              formatRupiah((_data?.saldoSantri ?? santri.saldo) - nominal),
            ),
          ],
        ),
      ),
      confirmText: 'Lanjut Masukkan PIN',
    );
    if (dikonfirmasi != true || !mounted) return;

    final pin = await showPinEntrySheet(
      context,
      title: 'Konfirmasi Setoran Tabungan',
      subtitle: 'Masukkan PIN transaksi untuk memindahkan saldo ke tabungan.',
    );
    if (pin == null || !mounted) return;

    setState(() => _menyimpan = true);
    try {
      final hasil = await PaymentFlowGuard.run(
        () => runWithTransactionProgress(
          context,
          message: 'Memindahkan saldo ke tabungan...',
          action: () => context.read<WaliApi>().pindahSaldoKeTabungan(
            santri.id,
            nominal,
            pin: pin,
            requestId: transactionRequestId('tabungan', [santri.id, nominal]),
          ),
        ),
      );
      if (hasil == null || !mounted) return;
      _nominal.clear();
      await showSuccessDialog(
        context,
        title: 'Berhasil Dipindahkan',
        subtitle:
            '${formatRupiah(hasil.nominal)} telah masuk ke tabungan ${santri.nama}.',
        rincian: [
          ('Sisa saldo', formatRupiah(hasil.saldoSantri)),
          ('Saldo tabungan', formatRupiah(hasil.saldoTabungan)),
        ],
        sinkronkan: () async {
          await Future.wait([
            context.read<AnakProvider>().refreshSaldoSelected(),
            _muat(),
          ]);
        },
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Widget _ringkasanBaris(String label, String nilai, {bool tebal = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text(
          nilai,
          style: TextStyle(
            fontWeight: tebal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final santri = context.watch<AnakProvider>().selected;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tabungan Santri')),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            if (santri == null)
              const EmptyStateView(
                icon: Icons.people_outline,
                message: 'Belum ada santri yang tertaut.',
              )
            else if (_memuat)
              const SizedBox(
                height: 360,
                child: LoadingStateView(
                  title: 'Memuat tabungan',
                  message: 'Saldo dan riwayat tabungan sedang disiapkan.',
                  icon: Icons.savings_outlined,
                ),
              )
            else if (_error != null)
              ErrorStateView(error: _error!, onRetry: _muat)
            else ...[
              _TabunganSummary(
                nama: santri.nama,
                nis: santri.nis,
                lembaga: santri.lembaga,
                saldo: _data?.saldoSantri ?? santri.saldo,
                tabungan: _data?.saldo ?? 0,
                status: _data?.status ?? 'belum_dibuka',
              ),
              const SizedBox(height: 12),
              FlatCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: AppRadius.borderRadius,
                      onTap: () => setState(
                        () => _formPindahTerbuka = !_formPindahTerbuka,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5F3),
                              child: Icon(
                                Icons.swap_vert_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pindahkan dari saldo',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Maksimal ${formatRupiah(_data?.saldoBisaDipindahkan ?? 0)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: _formPindahTerbuka ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      sizeCurve: Curves.easeOut,
                      crossFadeState: _formPindahTerbuka
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tabungan terpisah dari saldo belanja dan tidak dapat digunakan untuk membayar tagihan.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nominal,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Nominal pemindahan',
                                prefixText: 'Rp ',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _menyimpan ? null : _pindahDariSaldo,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _menyimpan
                                    ? 'Memproses...'
                                    : 'Tinjau & Pindahkan',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TopupTab(untukTabungan: true),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_rounded, size: 18),
                              label: const Text('Setor melalui VA / QRIS'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FlatCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5F3),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Riwayat transaksi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Saldo dan tabungan tampil dalam satu daftar.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    context.read<TabIndexProvider>().go(2);
                  },
                ),
              ),
              for (final transaksi in const <TransaksiTabungan>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FlatCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFEDE9FE),
                          child: Icon(
                            Icons.savings_outlined,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaksi.jenis.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                transaksi.kanal.replaceAll('_', ' '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${transaksi.arah == 'kredit' ? '+' : '−'}${formatRupiah(transaksi.nominal)}',
                          style: TextStyle(
                            color: transaksi.arah == 'kredit'
                                ? AppColors.primary
                                : AppColors.danger,
                            fontWeight: FontWeight.bold,
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
    );
  }
}

class _TabunganSummary extends StatelessWidget {
  final String nama;
  final String nis;
  final String? lembaga;
  final int saldo;
  final int tabungan;
  final String status;

  const _TabunganSummary({
    required this.nama,
    required this.nis,
    required this.lembaga,
    required this.saldo,
    required this.tabungan,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primary,
                child: Text(
                  nama.isEmpty ? '?' : nama[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$nis • ${lembaga ?? 'Pondok Pusat'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status == 'belum_dibuka'
                      ? 'Belum dibuka'
                      : status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Color(0xFF6D28D9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _NilaiTabungan(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Saldo belanja',
                  nilai: saldo,
                  color: AppColors.primary,
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              const SizedBox(width: 14),
              Expanded(
                child: _NilaiTabungan(
                  icon: Icons.savings_outlined,
                  label: 'Tabungan',
                  nilai: tabungan,
                  color: const Color(0xFF6D28D9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NilaiTabungan extends StatelessWidget {
  final IconData icon;
  final String label;
  final int nilai;
  final Color color;

  const _NilaiTabungan({
    required this.icon,
    required this.label,
    required this.nilai,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
              const SizedBox(height: 2),
              Text(
                formatRupiah(nilai),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
