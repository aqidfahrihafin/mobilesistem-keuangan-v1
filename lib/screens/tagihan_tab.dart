import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../providers/anak_provider.dart';
import '../providers/tab_index_provider.dart';
import 'tagihan_detail_screen.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../widgets/active_filter_bar.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/filter_sheet_scaffold.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import '../widgets/tagihan_bayar_bulk_flow.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);

/// null = "Semua"; otherwise one of Tagihan's status values.
const _filterOptions = <String?>[
  null,
  'belum_lunas',
  'sebagian',
  'lunas',
  'dibatalkan',
];

String _filterLabel(String? status) =>
    status == null ? 'Semua' : (statusTagihanLabel[status] ?? status);

class TagihanTab extends StatelessWidget {
  const TagihanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final anakProvider = context.watch<AnakProvider>();
    final anak = anakProvider.selected;

    // AnakProvider.error being set means the anak list itself failed to
    // load (network/server issue) - selected is null in that case too, but
    // for a completely different reason than "this wali genuinely has no
    // santri". Showing the same "belum ada santri" message either way is
    // actively misleading (a wali would think their account is broken
    // rather than retrying a transient fetch failure), so this checks error
    // first, same as HomeTab already does.
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
      body = _TagihanList(key: ValueKey(anak.id), anak: anak);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.read<TabIndexProvider>().go(0),
        ),
        title: const Text('Tagihan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: body,
    );
  }
}

class _TagihanList extends StatefulWidget {
  final Anak anak;

  const _TagihanList({super.key, required this.anak});

  @override
  State<_TagihanList> createState() => _TagihanListState();
}

class _TagihanListState extends State<_TagihanList> {
  late Future<List<Tagihan>> _future;
  Timer? _pollTimer;
  List<(int, String, int)>? _fingerprint;

  static const _pollInterval = Duration(seconds: 20);

  static List<(int, String, int)> _fingerprintOf(List<Tagihan> list) =>
      list.map((t) => (t.id, t.status, t.nominalTerbayar)).toList();

  // Default filter is "belum lunas" - that's what a wali most needs to act
  // on; the full history is one tap away via the "Semua" chip.
  String? _filter;
  String? _periodeFilter;

  // Multi-select bulk payment - _selectedIds tracks tagihan.id rather than
  // Tagihan objects so it survives a _load() refresh (the list's own
  // objects get replaced by a fresh fetch, ids don't).
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  // Whether the full (unfiltered) list has anything payable at all - drives
  // whether the "Bayar Beberapa Sekaligus" toggle even appears, from
  // outside the FutureBuilder in build() (see ActiveFilterBar's trailing).
  bool _adaPayable = false;

  // Populated once the tagihan list loads (see _load()) - options are
  // derived from whatever periode labels actually appear in the data
  // rather than a separate API call, since the list already carries them.
  List<String> _periodeOptions = [];

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps this list current without a manual pull-to-refresh - e.g. a
    // wali who pays a tagihan from a different screen (Home's preview card,
    // TagihanDetailScreen) sees it reflected here on its own within one
    // poll tick instead of needing to leave and re-enter the tab.
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
  }

  /// Applies a filter Home's "Lunas Bulan Ini" tile (or any future caller)
  /// asked for via TabIndexProvider.goToTagihanWithFilter - consumed once
  /// here since MainScreen's IndexedStack keeps this State alive across tab
  /// switches (initState only runs once), so this is the hook that actually
  /// fires on every subsequent navigation back to this tab, not just the
  /// first. Requires build() to `context.watch<TabIndexProvider>()` so this
  /// is even called when the provider changes - see build() below.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = context
        .read<TabIndexProvider>()
        .consumePendingTagihanFilter();
    if (pending != null) {
      _filter = pending.status;
      _periodeFilter = pending.periode;
    }
  }

  void _load() {
    _future = context.read<WaliApi>().getTagihan(widget.anak.id);
    _future
        .then((list) {
          if (!mounted) return;
          final periodes = list.map((t) => t.periodeLabel).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          setState(() {
            _periodeOptions = periodes;
            _adaPayable = list.any((t) => !t.selesai);
          });
        })
        .catchError((_) {});
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  /// Background counterpart to [_load] - fetches first, then swaps in an
  /// already-resolved Future (see home_tab.dart's identical technique) so
  /// the FutureBuilder below doesn't flash its loading skeleton every tick.
  /// Silent on failure and skipped while the app is backgrounded, same
  /// reasoning as AnakProvider's poll.
  Future<void> _refreshSilently() async {
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    // MainScreen keeps every tab mounted via IndexedStack (never disposed),
    // so without this check this timer would keep firing every tick even
    // while a wali is sitting on Home/Laporan/Profil - wasted requests, and
    // stacked on top of every other tab's own poller it's enough concurrent
    // traffic to trip up a single-threaded dev server (php artisan serve).
    // Tab index 1 = Tagihan, see MainScreen's _tabs list.
    if (context.read<TabIndexProvider>().index != 1) return;

    try {
      final list = await context.read<WaliApi>().getTagihan(widget.anak.id);
      if (!mounted) return;

      final fp = _fingerprintOf(list);
      if (listEquals(fp, _fingerprint)) return;

      final periodes = list.map((t) => t.periodeLabel).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      setState(() {
        _future = Future.value(list);
        _periodeOptions = periodes;
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

  Future<void> _bukaDetail(Tagihan tagihan) async {
    final berubah = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TagihanDetailScreen(anak: widget.anak, tagihan: tagihan),
      ),
    );
    if (berubah == true && mounted) setState(_load);
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(int tagihanId) {
    setState(() {
      if (!_selectedIds.remove(tagihanId)) _selectedIds.add(tagihanId);
    });
  }

  Future<void> _bayarSekaligus(List<Tagihan> selected) async {
    final berhasil = await bayarTagihanBulkFlow(context, widget.anak, selected);
    if (!mounted) return;

    if (berhasil) {
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
        _load();
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final result =
        await showModalBottomSheet<({String? status, String? periode})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: const Color(0x520F172A),
          builder: (_) => _TagihanFilterSheet(
            initialFilter: _filter,
            initialPeriode: _periodeFilter,
            periodeOptions: _periodeOptions,
          ),
        );

    if (result == null || !mounted) return;
    setState(() {
      _filter = result.status;
      _periodeFilter = result.periode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Establishes the subscription didChangeDependencies() above relies on
    // - the return value itself isn't needed here (TabIndexProvider.index
    // isn't used in this widget), only the rebuild-on-change it triggers.
    context.watch<TabIndexProvider>();

    return Column(
      children: [
        ActiveFilterBar(
          anyActive: _filter != null || _periodeFilter != null,
          onOpenFilter: _openFilterSheet,
          pills: [
            ActiveFilterPill(
              label: _filterLabel(_filter),
              active: _filter != null,
              onTap: _openFilterSheet,
            ),
            if (_periodeOptions.length > 1)
              ActiveFilterPill(
                label: _periodeFilter ?? 'Semua Periode',
                active: _periodeFilter != null,
                onTap: _openFilterSheet,
              ),
          ],
          // Sits aligned with the filter button on the same row, not
          // floating on a row of its own - only shown when there's
          // something payable at all (once already in selection mode, kept
          // visible regardless so "Batal Pilih" stays reachable).
          trailing: (_adaPayable || _selectionMode)
              ? _BayarSekaligusToggle(
                  active: _selectionMode,
                  onTap: _toggleSelectionMode,
                )
              : null,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Tagihan>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }

                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      ErrorStateView(
                        error: snapshot.error!,
                        onRetry: () => setState(_load),
                      ),
                    ],
                  );
                }

                final all = snapshot.data ?? [];
                final items = all.where((t) {
                  final statusOk = _filter == null || t.status == _filter;
                  final periodeOk =
                      _periodeFilter == null ||
                      t.periodeLabel == _periodeFilter;
                  return statusOk && periodeOk;
                }).toList();
                const statusOrder = {
                  'belum_lunas': 0,
                  'sebagian': 1,
                  'lunas': 2,
                  'dibatalkan': 3,
                };
                items.sort((a, b) {
                  final byStatus = (statusOrder[a.status] ?? 9).compareTo(
                    statusOrder[b.status] ?? 9,
                  );
                  if (byStatus != 0) return byStatus;
                  final aDue = DateTime.tryParse(a.jatuhTempo ?? '');
                  final bDue = DateTime.tryParse(b.jatuhTempo ?? '');
                  if (aDue != null && bDue != null) {
                    final byDue = aDue.compareTo(bDue);
                    if (byDue != 0) return byDue;
                  } else if (aDue != null) {
                    return -1;
                  } else if (bDue != null) {
                    return 1;
                  }
                  return b.id.compareTo(a.id);
                });

                if (items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 100),
                      EmptyStateView(
                        icon: all.isEmpty
                            ? Icons.receipt_long_outlined
                            : Icons.filter_alt_off_outlined,
                        message: all.isEmpty
                            ? 'Belum ada tagihan.'
                            : 'Tidak ada tagihan dengan status "${_filterLabel(_filter)}"'
                                  '${_periodeFilter != null ? ' pada periode $_periodeFilter' : ''}.',
                      ),
                    ],
                  );
                }

                final selectedTagihan = items
                    .where((t) => _selectedIds.contains(t.id))
                    .toList();
                final totalDipilih = selectedTagihan.fold<int>(
                  0,
                  (sum, t) => sum + t.sisa,
                );
                final groups = <(String, List<Tagihan>)>[];
                for (final status in statusOrder.keys) {
                  final group = items.where((t) => t.status == status).toList();
                  if (group.isNotEmpty) groups.add((status, group));
                }
                final knownStatuses = statusOrder.keys.toSet();
                for (final tagihan in items) {
                  if (knownStatuses.contains(tagihan.status) ||
                      groups.any((group) => group.$1 == tagihan.status)) {
                    continue;
                  }
                  groups.add((
                    tagihan.status,
                    items.where((t) => t.status == tagihan.status).toList(),
                  ));
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.zero,
                              border: const Border(
                                top: BorderSide(color: Color(0xFFE2E8E4)),
                                bottom: BorderSide(color: Color(0xFFE2E8E4)),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (final (status, group) in groups) ...[
                                  _TagihanStatusHeader(status: status),
                                  for (
                                    var index = 0;
                                    index < group.length;
                                    index++
                                  ) ...[
                                    Builder(
                                      builder: (context) {
                                        final tagihan = group[index];
                                        final payable = !tagihan.selesai;
                                        return _TagihanCard(
                                          key: ValueKey(tagihan.id),
                                          tagihan: tagihan,
                                          onOpen: () => _bukaDetail(tagihan),
                                          selectionMode: _selectionMode,
                                          selected: _selectedIds.contains(
                                            tagihan.id,
                                          ),
                                          onToggleSelected:
                                              (_selectionMode && payable)
                                              ? () =>
                                                    _toggleSelected(tagihan.id)
                                              : null,
                                        );
                                      },
                                    ),
                                    if (index < group.length - 1)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 64),
                                        child: Divider(
                                          height: 1,
                                          color: Color(0xFFEEF0F3),
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectionMode && selectedTagihan.isNotEmpty)
                      _BulkSelectionBar(
                        count: selectedTagihan.length,
                        total: totalDipilih,
                        onBayar: () => _bayarSekaligus(selectedTagihan),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Collapsed by default (jenis/periode/status/progress only) - nominal
/// breakdown and the Bayar/Cetak Struk actions only reveal on tap, so the
/// list reads as a clean scan-able summary instead of every card dumping
/// its full numeric detail (and both action buttons) up front.
class _TagihanCard extends StatefulWidget {
  final Tagihan tagihan;
  final VoidCallback onOpen;

  /// Multi-select bulk-payment mode - see _TagihanListState. [onToggleSelected]
  /// is null for a tagihan that can't be paid (lunas/dibatalkan) even while
  /// [selectionMode] is on, which is what keeps the checkbox from appearing
  /// on cards that have nothing to select.
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;

  const _TagihanCard({
    super.key,
    required this.tagihan,
    required this.onOpen,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
  });

  @override
  State<_TagihanCard> createState() => _TagihanCardState();
}

class _TagihanCardState extends State<_TagihanCard> {
  @override
  Widget build(BuildContext context) {
    final tagihan = widget.tagihan;
    final (badgeBg, badgeFg) = StatusBadge.colorsFor(tagihan.status);
    final canSelect = widget.onToggleSelected != null;

    return Material(
      color: widget.selected
          ? _teal.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: widget.selectionMode ? widget.onToggleSelected : widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          child: Row(
            children: [
              if (widget.selectionMode)
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: canSelect
                        ? Checkbox(
                            value: widget.selected,
                            activeColor: _teal,
                            onChanged: (_) => widget.onToggleSelected!(),
                          )
                        : Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.grey[300],
                          ),
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: badgeFg,
                    size: 17,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tagihan.jenisTagihanNama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagihan.periodeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(
                      tagihan.selesai ? tagihan.nominal : tagihan.sisa,
                    ),
                    style: TextStyle(
                      color: tagihan.lunas
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusTagihanLabel[tagihan.status] ?? tagihan.status,
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!widget.selectionMode) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagihanStatusHeader extends StatelessWidget {
  final String status;

  const _TagihanStatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      color: const Color(0xFFF8FAF9),
      child: Text(
        (statusTagihanLabel[status] ?? status).toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

/// Enters/exits multi-select mode - rendered as [ActiveFilterBar.trailing]
/// so it sits aligned with the circular filter button rather than on its
/// own row. Sized to the same 34px height as that button and the filter
/// pills next to it.
class _BayarSekaligusToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _BayarSekaligusToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _teal : const Color(0xFFD8DBE2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.close_rounded : Icons.checklist_rounded,
              size: 15,
              color: active ? Colors.white : _teal,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Batal Pilih' : 'Bayar Beberapa Sekaligus',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sits at the bottom of the list (not floating/overlapping it) once at
/// least one tagihan is selected in selection mode - summary + the one
/// action that starts the bulk-pay flow.
class _BulkSelectionBar extends StatelessWidget {
  final int count;
  final int total;
  final VoidCallback onBayar;

  const _BulkSelectionBar({
    required this.count,
    required this.total,
    required this.onBayar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count Tagihan Dipilih',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatRupiah(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onBayar,
              child: const Text('Bayar Sekarang'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Filter Tagihan" bottom sheet - Status + (optionally) Periode sections,
/// each a [Wrap] of [FilterChip2]s. Holds its own draft state and only
/// reports back to the caller on "Terapkan" (deferred-apply, matching the
/// reference screenshots); "Reset" clears the draft without closing.
class _TagihanFilterSheet extends StatefulWidget {
  final String? initialFilter;
  final String? initialPeriode;
  final List<String> periodeOptions;

  const _TagihanFilterSheet({
    required this.initialFilter,
    required this.initialPeriode,
    required this.periodeOptions,
  });

  @override
  State<_TagihanFilterSheet> createState() => _TagihanFilterSheetState();
}

class _TagihanFilterSheetState extends State<_TagihanFilterSheet> {
  late String? _draftFilter = widget.initialFilter;
  late String? _draftPeriode = widget.initialPeriode;

  @override
  Widget build(BuildContext context) {
    return FilterSheetScaffold(
      title: 'Filter Tagihan',
      onReset: () => setState(() {
        _draftFilter = null;
        _draftPeriode = null;
      }),
      onTerapkan: () => Navigator.of(
        context,
      ).pop((status: _draftFilter, periode: _draftPeriode)),
      sections: [
        FilterSection(
          title: 'Status Tagihan',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filterOptions
                .map(
                  (status) => FilterChip2(
                    label: _filterLabel(status),
                    selected: _draftFilter == status,
                    onTap: () => setState(() => _draftFilter = status),
                  ),
                )
                .toList(),
          ),
        ),
        if (widget.periodeOptions.length > 1)
          FilterSection(
            title: 'Periode',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip2(
                  label: 'Semua Periode',
                  selected: _draftPeriode == null,
                  onTap: () => setState(() => _draftPeriode = null),
                ),
                ...widget.periodeOptions.map(
                  (p) => FilterChip2(
                    label: p,
                    selected: _draftPeriode == p,
                    onTap: () => setState(() => _draftPeriode = p),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
