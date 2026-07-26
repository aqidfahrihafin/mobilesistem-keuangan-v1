import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/transaksi.dart';
import '../providers/anak_provider.dart';
import '../providers/app_info_provider.dart';
import '../providers/tab_index_provider.dart';
import '../services/wali_api.dart';
import '../utils/date_group.dart';
import '../utils/date_range_filter.dart';
import '../utils/formatters.dart';
import '../utils/laporan_pdf.dart';
import '../widgets/active_filter_bar.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/filter_sheet_scaffold.dart';
import '../widgets/skeleton.dart';
import '../widgets/transaksi_list_item.dart';
import 'transaksi_detail_screen.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);

String _jenisLabel(String? jenis) =>
    jenis == null ? 'Semua Jenis' : (jenisTransaksiLabel[jenis] ?? jenis);

/// [periode]'s label, except when it's [DateRangePreset.kustom] - then the
/// actual picked [custom] range is shown instead of the generic "Rentang
/// Kustom" placeholder, both on the filter pill and the PDF header.
String _periodeLabel(DateRangePreset periode, DateTimeRange? custom) {
  if (periode == DateRangePreset.kustom && custom != null) {
    return '${formatTanggal(custom.start.toIso8601String())} - '
        '${formatTanggal(custom.end.toIso8601String())}';
  }
  return periode.label;
}

/// [DateRangePreset.includes] can't resolve `kustom` on its own (the picked
/// range lives outside the enum) - this is the one place that special-cases
/// it, shared by every screen filtering a transaksi list by period.
bool _cocokPeriode(
  DateTime dt,
  DateRangePreset periode,
  DateTimeRange? custom,
) {
  if (periode == DateRangePreset.kustom) {
    if (custom == null) return true;
    final awal = DateTime(
      custom.start.year,
      custom.start.month,
      custom.start.day,
    );
    final akhir = DateTime(
      custom.end.year,
      custom.end.month,
      custom.end.day,
    ).add(const Duration(days: 1));
    return !dt.isBefore(awal) && dt.isBefore(akhir);
  }
  return periode.includes(dt);
}

class LaporanTab extends StatelessWidget {
  const LaporanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final anakProvider = context.watch<AnakProvider>();
    final anak = anakProvider.selected;

    // See tagihan_tab.dart's identical check - error and "genuinely no
    // santri" are different situations and deserve different messages.
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
    } else if (anak == null) {
      body = const EmptyStateView(
        icon: Icons.people_outline,
        message: 'Belum ada santri yang tertaut.',
      );
    } else {
      body = _LaporanBody(key: ValueKey(anak.id), anak: anak);
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.read<TabIndexProvider>().go(0),
          ),
          title: const Text('Laporan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: TabBar(
            labelColor: _teal,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: _teal,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Transaksi'),
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Laporan'),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

/// Fetches the santri's full transaksi list once and shares it across all
/// 3 sub-tabs (instead of each sub-tab issuing its own network call) - the
/// Transaksi/Pengeluaran/Laporan views are all just different slices/
/// aggregations of the same underlying list.
class _LaporanBody extends StatefulWidget {
  final Anak anak;

  const _LaporanBody({super.key, required this.anak});

  @override
  State<_LaporanBody> createState() => _LaporanBodyState();
}

class _LaporanBodyState extends State<_LaporanBody> {
  late Future<List<Transaksi>> _future;
  Timer? _pollTimer;
  List<int>? _fingerprint;

  static const _pollInterval = Duration(seconds: 20);

  static List<int> _fingerprintOf(List<Transaksi> list) =>
      list.map((t) => t.id).toList();

  @override
  void initState() {
    super.initState();
    _future = context.read<WaliApi>().getTransaksi(widget.anak.id);
    // Keeps Transaksi/Pengeluaran/Laporan (all 3 sub-tabs share this one
    // list) current on their own - e.g. after a kantin payment made from
    // Scan Bayar, this list picks it up within one tick without the wali
    // needing to pull-to-refresh.
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
  }

  Future<void> _refresh() async {
    final future = context.read<WaliApi>().getTransaksi(widget.anak.id);
    setState(() => _future = future);
    await future;
  }

  /// Background counterpart to [_refresh] - fetches first, then swaps in an
  /// already-resolved Future (same flicker-avoidance technique as
  /// home_tab.dart) so the FutureBuilder below doesn't flash its loading
  /// skeleton every tick. Silent on failure and skipped while backgrounded.
  Future<void> _refreshSilently() async {
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    // See tagihan_tab.dart's identical check - MainScreen's IndexedStack
    // keeps this tab mounted (and its timer running) even while a wali is
    // elsewhere in the app. Tab index 2 = Laporan, see MainScreen's _tabs.
    if (context.read<TabIndexProvider>().index != 2) return;

    try {
      final list = await context.read<WaliApi>().getTransaksi(widget.anak.id);
      if (!mounted) return;

      final fp = _fingerprintOf(list);
      if (listEquals(fp, _fingerprint)) return;

      setState(() {
        _future = Future.value(list);
        _fingerprint = fp;
      });
    } catch (_) {
      // Silent - see doc comment above.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Transaksi>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList();
        }

        if (snapshot.hasError) {
          return ErrorStateView(error: snapshot.error!, onRetry: _refresh);
        }

        final all = snapshot.data ?? [];

        return TabBarView(
          children: [
            _TransaksiListView(
              items: all,
              onRefresh: _refresh,
              emptyMessage: 'Belum ada transaksi.',
              sheetTitle: 'Filter Transaksi',
            ),
            _TransaksiListView(
              items: all.where((t) => !t.isKredit).toList(),
              onRefresh: _refresh,
              emptyMessage: 'Belum ada pengeluaran.',
              sheetTitle: 'Filter Pengeluaran',
            ),
            _LaporanRingkasan(anak: widget.anak, all: all),
          ],
        );
      },
    );
  }
}

/// Shared list view for both the "Transaksi" (everything) and "Pengeluaran"
/// (debit-only, pre-filtered by the caller) sub-tabs - same card UI, same
/// ActiveFilterBar + bottom-sheet filter pattern already established on
/// Tagihan (Jenis + Periode Waktu here instead of Status + Periode).
class _TransaksiListView extends StatefulWidget {
  final List<Transaksi> items;
  final Future<void> Function() onRefresh;
  final String emptyMessage;
  final String sheetTitle;

  const _TransaksiListView({
    required this.items,
    required this.onRefresh,
    required this.emptyMessage,
    required this.sheetTitle,
  });

  @override
  State<_TransaksiListView> createState() => _TransaksiListViewState();
}

class _TransaksiListViewState extends State<_TransaksiListView> {
  String? _jenis;
  DateRangePreset _periode = DateRangePreset.bulanIni;
  DateTimeRange? _customRange;

  List<String?> get _jenisOptions => <String?>[
    null,
    ...{for (final t in widget.items) t.jenis},
  ];

  Future<void> _openFilterSheet() async {
    final result =
        await showModalBottomSheet<
          ({String? jenis, DateRangePreset periode, DateTimeRange? customRange})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: const Color(0x520F172A),
          builder: (_) => _RiwayatFilterSheet(
            title: widget.sheetTitle,
            initialJenis: _jenis,
            initialPeriode: _periode,
            initialCustomRange: _customRange,
            jenisOptions: _jenisOptions,
          ),
        );

    if (result == null || !mounted) return;
    setState(() {
      _jenis = result.jenis;
      _periode = result.periode;
      _customRange = result.customRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((t) {
      final jenisOk = _jenis == null || t.jenis == _jenis;
      final periodeOk = _cocokPeriode(t.createdAt, _periode, _customRange);
      return jenisOk && periodeOk;
    }).toList();

    return Column(
      children: [
        ActiveFilterBar(
          // "Hari Ini" is this list's own default (not "Semua Waktu"), so
          // the active-filter highlight compares against that baseline -
          // otherwise it would show as permanently "active" from first
          // load, which isn't true.
          anyActive: _jenis != null || _periode != DateRangePreset.bulanIni,
          onOpenFilter: _openFilterSheet,
          pills: [
            ActiveFilterPill(
              label: _jenisLabel(_jenis),
              active: _jenis != null,
              onTap: _openFilterSheet,
            ),
            ActiveFilterPill(
              label: _periodeLabel(_periode, _customRange),
              active: _periode != DateRangePreset.bulanIni,
              onTap: _openFilterSheet,
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      EmptyStateView(
                        icon: widget.items.isEmpty
                            ? Icons.receipt_long_outlined
                            : Icons.filter_alt_off_outlined,
                        message: widget.items.isEmpty
                            ? widget.emptyMessage
                            : 'Tidak ada transaksi yang cocok dengan filter.',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final (label, group) in groupByRelativeDate(
                        items,
                        (t) => t.createdAt,
                      ))
                        ..._buildRiwayatGroup(context, label, group),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _RiwayatFilterSheet extends StatefulWidget {
  final String title;
  final String? initialJenis;
  final DateRangePreset initialPeriode;
  final DateTimeRange? initialCustomRange;
  final List<String?> jenisOptions;

  const _RiwayatFilterSheet({
    required this.title,
    required this.initialJenis,
    required this.initialPeriode,
    required this.initialCustomRange,
    required this.jenisOptions,
  });

  @override
  State<_RiwayatFilterSheet> createState() => _RiwayatFilterSheetState();
}

class _RiwayatFilterSheetState extends State<_RiwayatFilterSheet> {
  late String? _draftJenis = widget.initialJenis;
  late DateRangePreset _draftPeriode = widget.initialPeriode;
  late DateTimeRange? _draftCustomRange = widget.initialCustomRange;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _draftCustomRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      saveText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _draftCustomRange = picked;
      _draftPeriode = DateRangePreset.kustom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FilterSheetScaffold(
      title: widget.title,
      onReset: () => setState(() {
        _draftJenis = null;
        _draftPeriode = DateRangePreset.semua;
        _draftCustomRange = null;
      }),
      onTerapkan: () => Navigator.of(context).pop((
        jenis: _draftJenis,
        periode: _draftPeriode,
        customRange: _draftCustomRange,
      )),
      sections: [
        FilterSection(
          title: 'Periode Waktu',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DateRangePreset.values.map((p) {
              if (p == DateRangePreset.kustom) {
                return FilterChip2(
                  label: _periodeLabel(p, _draftCustomRange),
                  icon: Icons.calendar_month_outlined,
                  selected: _draftPeriode == p,
                  onTap: _pickCustomRange,
                );
              }
              return FilterChip2(
                label: p.label,
                selected: _draftPeriode == p,
                onTap: () => setState(() => _draftPeriode = p),
              );
            }).toList(),
          ),
        ),
        if (widget.jenisOptions.length > 1)
          FilterSection(
            title: 'Jenis Transaksi',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.jenisOptions
                  .map(
                    (jenis) => FilterChip2(
                      label: _jenisLabel(jenis),
                      selected: _draftJenis == jenis,
                      onTap: () => setState(() => _draftJenis = jenis),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// Builds one date-grouped section for the flat Transaksi/Pengeluaran list:
/// an uppercase grey label followed by its rows, each separated by a
/// hairline divider instead of individual card borders - the borderless
/// list look the redesign uses specifically for transaction history
/// (Tagihan cards elsewhere in the app stay boxed; this is a deliberate,
/// separate visual language for money-movement lists).
List<Widget> _buildRiwayatGroup(
  BuildContext context,
  String label,
  List<Transaksi> group,
) {
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey[500],
        ),
      ),
    ),
    for (var i = 0; i < group.length; i++) ...[
      TransaksiListItem(
        tx: group[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransaksiDetailScreen(transaksi: group[i]),
          ),
        ),
      ),
      if (i < group.length - 1)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: Color(0xFFEEF0F3)),
        ),
    ],
  ];
}

/// The "Laporan" sub-tab - a scannable statement-style summary (period
/// totals + breakdown by jenis) for a chosen period, with a PDF export the
/// wali can use as an "evaluasi" record, rather than a charts dashboard.
class _LaporanRingkasan extends StatefulWidget {
  final Anak anak;
  final List<Transaksi> all;

  const _LaporanRingkasan({required this.anak, required this.all});

  @override
  State<_LaporanRingkasan> createState() => _LaporanRingkasanState();
}

class _LaporanRingkasanState extends State<_LaporanRingkasan> {
  DateRangePreset _periode = DateRangePreset.bulanIni;
  DateTimeRange? _customRange;
  bool _mengunduh = false;

  List<Transaksi> get _items => widget.all
      .where((t) => _cocokPeriode(t.createdAt, _periode, _customRange))
      .toList();

  Future<void> _openFilterSheet() async {
    final result =
        await showModalBottomSheet<
          ({String? jenis, DateRangePreset periode, DateTimeRange? customRange})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: const Color(0x520F172A),
          builder: (_) => _RiwayatFilterSheet(
            title: 'Filter Laporan',
            initialJenis: null,
            initialPeriode: _periode,
            initialCustomRange: _customRange,
            jenisOptions: const [null],
          ),
        );

    if (result == null || !mounted) return;
    setState(() {
      _periode = result.periode;
      _customRange = result.customRange;
    });
  }

  Future<void> _unduh() async {
    setState(() => _mengunduh = true);
    try {
      await cetakLaporanTransaksi(
        anak: widget.anak,
        items: _items,
        periodeLabel: _periodeLabel(_periode, _customRange),
        namaPondok:
            context.read<AppInfoProvider>().namaPondok ??
            'Pondok Pesantren Latee',
      );
    } finally {
      if (mounted) setState(() => _mengunduh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final totalMasuk = items
        .where((t) => t.isKredit)
        .fold<int>(0, (s, t) => s + t.nominal);
    final totalKeluar = items
        .where((t) => !t.isKredit)
        .fold<int>(0, (s, t) => s + t.nominal);

    final perJenis = <String, ({int jumlah, int total})>{};
    for (final t in items) {
      final prev = perJenis[t.jenis] ?? (jumlah: 0, total: 0);
      perJenis[t.jenis] = (
        jumlah: prev.jumlah + 1,
        total: prev.total + t.nominal,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          ActiveFilterBar(
            anyActive: _periode != DateRangePreset.bulanIni,
            onOpenFilter: _openFilterSheet,
            pills: [
              ActiveFilterPill(
                label: _periodeLabel(_periode, _customRange),
                active: _periode != DateRangePreset.bulanIni,
                onTap: _openFilterSheet,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total Masuk',
                        value: formatRupiah(totalMasuk),
                        color: const Color(0xFF15803D),
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total Keluar',
                        value: formatRupiah(totalKeluar),
                        color: const Color(0xFFB91C1C),
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SummaryCard(
                  label: 'Selisih Periode Ini',
                  value: formatRupiah(totalMasuk - totalKeluar),
                  color: _teal,
                  icon: Icons.account_balance_wallet_outlined,
                  full: true,
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rincian per Jenis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (perJenis.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: EmptyStateView(
                      icon: Icons.event_busy_outlined,
                      message: 'Tidak ada transaksi pada periode ini.',
                      compact: true,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE9EBEF)),
                    ),
                    child: Column(
                      children: perJenis.entries.map((entry) {
                        final isLast = entry.key == perJenis.keys.last;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFF1F2F4),
                                    ),
                                  ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  jenisTransaksiLabel[entry.key] ?? entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value.jumlah}x',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Expanded + textAlign.end - see the identical
                              // comment on the transaksi list row above.
                              Expanded(
                                child: Text(
                                  formatRupiah(entry.value.total),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _mengunduh ? null : _unduh,
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: _mengunduh
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _mengunduh ? 'Menyiapkan...' : 'Unduh Laporan (PDF)',
                    ),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool full;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.full = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Row(
        crossAxisAlignment: full
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
