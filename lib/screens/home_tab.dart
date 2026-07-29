import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../models/transaksi.dart';
import '../providers/anak_provider.dart';
import '../providers/tab_index_provider.dart';
import '../services/auth_service.dart';
import '../services/wali_api.dart';
import '../utils/formatters.dart';
import '../utils/jatuh_tempo.dart';
import '../widgets/anak_switcher.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/flat_card.dart';
import '../widgets/geometric_pattern.dart';
import '../widgets/skeleton.dart';
import '../widgets/transaksi_list_item.dart';
import 'all_services_screen.dart';
import 'notifications_screen.dart';
import 'santri_profile_screen.dart';
import 'scan_bayar_screen.dart';
import 'topup_tab.dart';
import 'transaksi_detail_screen.dart';
import 'transfer_saldo_screen.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

String _sapaanWaktu() {
  final jam = DateTime.now().hour;
  if (jam < 10) return 'Selamat Pagi';
  if (jam < 15) return 'Selamat Siang';
  if (jam < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final anakProvider = context.watch<AnakProvider>();

    return Scaffold(
      backgroundColor: _bg,
      // No outer SafeArea here - _AnakDashboard's own banner needs to bleed
      // all the way to the top edge (behind the status bar), same as
      // ProfilTab's header. Its internal SafeArea already insets just the
      // greeting text/switcher, not the gradient itself. The loading/error/
      // empty states below have no banner, so they get their own SafeArea.
      body: RefreshIndicator(
        onRefresh: () => context.read<AnakProvider>().load(),
        child: Builder(
          builder: (context) {
            if (anakProvider.loading) {
              return const SafeArea(bottom: false, child: SkeletonHomePage());
            }

            if (anakProvider.error != null) {
              return SafeArea(
                bottom: false,
                child: ListView(
                  children: [
                    const SizedBox(height: 100),
                    ErrorStateView(
                      error: anakProvider.error!,
                      onRetry: () => context.read<AnakProvider>().load(),
                    ),
                  ],
                ),
              );
            }

            if (anakProvider.selected == null) {
              return SafeArea(
                bottom: false,
                child: ListView(
                  children: const [
                    SizedBox(height: 100),
                    EmptyStateView(
                      icon: Icons.people_outline,
                      message: 'Belum ada santri yang tertaut ke akun Anda.',
                    ),
                  ],
                ),
              );
            }

            // Keyed by anak id so Flutter recreates the whole subtree (and
            // its state, including cached tagihan/transaksi futures) the
            // instant a different anak is picked from the switcher.
            return _AnakDashboard(
              key: ValueKey(anakProvider.selected!.id),
              anak: anakProvider.selected!,
            );
          },
        ),
      ),
    );
  }
}

class _AnakDashboard extends StatefulWidget {
  final Anak anak;

  const _AnakDashboard({super.key, required this.anak});

  @override
  State<_AnakDashboard> createState() => _AnakDashboardState();
}

class _AnakDashboardState extends State<_AnakDashboard> {
  late Future<List<Tagihan>> _tagihanFuture;
  late Future<List<Transaksi>> _transaksiFuture;
  late Future<int> _minimalSaldoFuture;
  Timer? _pollTimer;

  // Fingerprints of the currently-displayed lists, so a poll tick that finds
  // no real change can skip setState entirely - see _refreshLists() below.
  List<(int, String, int)>? _tagihanFingerprint;
  List<int>? _transaksiFingerprint;

  static const _pollInterval = Duration(seconds: 20);

  static List<(int, String, int)> _fingerprintTagihan(List<Tagihan> list) =>
      list.map((t) => (t.id, t.status, t.nominalTerbayar)).toList();

  static List<int> _fingerprintTransaksi(List<Transaksi> list) =>
      list.map((t) => t.id).toList();

  @override
  void initState() {
    super.initState();
    final api = context.read<WaliApi>();
    _tagihanFuture = api.getTagihan(widget.anak.id);
    _transaksiFuture = api.getTransaksi(widget.anak.id);
    _minimalSaldoFuture = api.getMinimalSaldoBayarTagihan();

    // Keeps "Tagihan Terbaru"/"Aktivitas Terbaru" (and the stat tiles
    // above them) fresh without the wali needing to pull-to-refresh -
    // AnakProvider only polls saldo, not these two lists, since they're
    // specific to this screen.
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshLists());
  }

  /// Fetches fresh data *before* swapping the Future fields, so by the
  /// time setState() runs, _tagihanFuture/_transaksiFuture are already-
  /// resolved (Future.value(...)) rather than freshly-started network
  /// calls - every FutureBuilder below sees a new Future reference and
  /// briefly reports ConnectionState.waiting either way, but an
  /// already-resolved one clears on the very next frame instead of
  /// showing a "..." flash for the length of a real request. Silently
  /// gives up on failure (offline blip, etc.) - a background refresh
  /// failing shouldn't disrupt the screen; the next tick tries again.
  ///
  /// Only actually calls setState when the fetched data is different from
  /// what's already on screen (compared via a cheap id/status/nominal
  /// fingerprint, not full object equality) - most ticks find nothing new,
  /// and rebuilding the whole dashboard for no visible reason every 20
  /// seconds is exactly what reads as the screen "flickering" to a wali who
  /// isn't doing anything.
  Future<void> _refreshLists() async {
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final api = context.read<WaliApi>();

    try {
      final tagihan = await api.getTagihan(widget.anak.id);
      final transaksi = await api.getTransaksi(widget.anak.id);

      if (!mounted) return;

      final tagihanFp = _fingerprintTagihan(tagihan);
      final transaksiFp = _fingerprintTransaksi(transaksi);
      final berubah =
          !listEquals(tagihanFp, _tagihanFingerprint) ||
          !listEquals(transaksiFp, _transaksiFingerprint);

      if (!berubah) return;

      setState(() {
        _tagihanFuture = Future.value(tagihan);
        _transaksiFuture = Future.value(transaksi);
        _tagihanFingerprint = tagihanFp;
        _transaksiFingerprint = transaksiFp;
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
    final user = context.watch<AuthService>().user;

    // Header sits outside the scrollable so it stays fixed on screen - only
    // the cards below it (balance card onward) scroll underneath it. A
    // plain Column+Expanded is enough here since the header has no
    // gradient/parallax to manage, unlike the old pinned teal SliverAppBar
    // this replaced.
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _HomeHeader(
              userName: user?.name,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BalanceCard(
                      anak: widget.anak,
                      minimalSaldoFuture: _minimalSaldoFuture,
                    ),
                    const SizedBox(height: 20),
                    const _QuickActionsRow(),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Tagihan>>(
                      future: _tagihanFuture,
                      builder: (context, snapshot) {
                        final tagihanList = snapshot.data ?? [];
                        final belumLunas = tagihanList
                            .where(
                              (t) =>
                                  t.status != 'lunas' &&
                                  t.status != 'dibatalkan',
                            )
                            .toList();
                        final totalTunggakan = belumLunas.fold<int>(
                          0,
                          (sum, t) => sum + t.sisa,
                        );
                        // Reminder folded straight into the stat tile itself
                        // (a small badge) instead of a separate banner above
                        // the balance card - same information, without an
                        // extra block competing for attention with the saldo
                        // number.
                        final urgentCount = tagihanList
                            .map(hitungJatuhTempo)
                            .whereType<JatuhTempoInfo>()
                            .length;
                        // "Bulan ini" is judged by periode_label (which billing
                        // period the tagihan is FOR), not a payment timestamp -
                        // the API doesn't return one. Arguably the more useful
                        // reading anyway: how many of *this month's* bills are
                        // already settled, not "paid in the last 30 days".
                        final now = DateTime.now();
                        final periodeIni =
                            '${now.year}-${now.month.toString().padLeft(2, '0')}';
                        final lunasBulanIni = tagihanList
                            .where(
                              (t) =>
                                  t.status == 'lunas' &&
                                  t.periodeLabel == periodeIni,
                            )
                            .length;

                        // Three separate tinted chip cards (not one white
                        // strip) - each carries its own color (matching the
                        // semantics: teal/neutral for "aktif", amber for
                        // money owed, green for a completed/positive state),
                        // so this reads as a splash of color right after the
                        // bare icon row above instead of yet another plain
                        // white rectangle. IntrinsicHeight keeps all three
                        // the same height even though "Lunas Bulan Ini"'s
                        // label is longer than "Tunggakan"'s.
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.receipt_long_outlined,
                                  label: 'Tagihan Aktif',
                                  color: _teal,
                                  value:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? '...'
                                      : '${belumLunas.length}',
                                  badgeCount: urgentCount > 0
                                      ? urgentCount
                                      : null,
                                  // Lands pre-filtered to "belum lunas" -
                                  // same status this tile itself counts by
                                  // - instead of just switching tabs and
                                  // leaving whatever filter Tagihan
                                  // happened to be on last.
                                  onTap: () => context
                                      .read<TabIndexProvider>()
                                      .goToTagihanWithFilter(
                                        status: 'belum_lunas',
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Tunggakan',
                                  color: const Color(0xFFB45309),
                                  value:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? '...'
                                      : formatRupiah(totalTunggakan),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: 'Lunas Bulan Ini',
                                  color: const Color(0xFF15803D),
                                  value:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? '...'
                                      : '$lunasBulanIni',
                                  // Lands on Tagihan pre-filtered to exactly
                                  // what this tile counted (lunas + this
                                  // month), instead of the tab's own default
                                  // "belum lunas" filter, which would show
                                  // this santri's own count as 0.
                                  onTap: () => context
                                      .read<TabIndexProvider>()
                                      .goToTagihanWithFilter(
                                        status: 'lunas',
                                        periode: periodeIni,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const BannerCarousel(),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Transaksi Terakhir',
                      onLihatSemua: () => _goToTab(context, 2),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Transaksi>>(
                      future: _transaksiFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SkeletonPreviewCard();
                        }

                        final items = (snapshot.data ?? []).take(3).toList();

                        if (items.isEmpty) {
                          return FlatCard(
                            color: Colors.white,
                            child: const EmptyStateView(
                              icon: Icons.swap_horiz_rounded,
                              message: 'Belum ada transaksi.',
                              compact: true,
                            ),
                          );
                        }

                        return FlatCard(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                TransaksiListItem(
                                  tx: items[i],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TransaksiDetailScreen(
                                        transaksi: items[i],
                                      ),
                                    ),
                                  ),
                                ),
                                if (i < items.length - 1)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFE8ECEF),
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _goToTab(BuildContext context, int index) {
    context.read<TabIndexProvider>().go(index);
  }
}

/// A single FlatCard holding a short preview list with a centered "Lihat
/// Semua" link as its own row at the bottom of the card - matching the
/// reference design's grouped-list-with-footer-link pattern, instead of a
/// separate header row with the link floating above the card. Each row is
/// individually tappable too (see _TagihanPreviewRow/_AktivitasPreviewRow)
/// so a wali can jump straight to that item's tab without hunting for the
/// footer link.
/// Section title + "Lihat Semua" link in one row, matching the reference
/// design - was previously a link bar docked to the bottom of the card
/// below, which visually detached it from the section it belonged to.
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onLihatSemua;

  const _SectionHeader({required this.title, required this.onLihatSemua});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onLihatSemua,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: _teal),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Plain, non-teal greeting row - "Selamat Malam / Yanto 👋 / Kelola
/// keuangan dengan mudah" plus a notification bell (dot shown when there
/// are unread items in the persistent notification inbox)
/// and the wali's own avatar. Replaces the previous teal full-bleed banner
/// that carried the greeting - the balance card below is now the one teal
/// surface on the page.
class _HomeHeader extends StatelessWidget {
  final String? userName;

  const _HomeHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    final initial = (userName?.isNotEmpty ?? false)
        ? userName![0].toUpperCase()
        : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sapaanWaktu(),
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${userName?.split(' ').first ?? 'Wali'} \u{1F44B}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Kelola keuangan dengan mudah',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _NotifBell(),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.read<TabIndexProvider>().go(3),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: _teal,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifBell extends StatefulWidget {
  const _NotifBell();

  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final inbox = await context.read<WaliApi>().getNotifications();
      if (mounted) setState(() => _unread = inbox.unreadCount);
    } catch (_) {
      // Badge is best-effort; the inbox itself provides a retry action.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) await _refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _openNotifications,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: Colors.grey[700],
              size: 23,
            ),
            if (_unread > 0)
              Positioned(
                top: 6,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB91C1C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Anak anak;
  final Future<int> minimalSaldoFuture;

  const _BalanceCard({required this.anak, required this.minimalSaldoFuture});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_teal, _tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: GeometricPatternBackground(opacity: 0.07),
          ),
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Saldo Tersedia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Moved out from under the big balance number (was a
                    // wrapping sentence there, cluttering the primary
                    // number) - now a small tap-to-reveal info icon so the
                    // detail is still one tap away without competing for
                    // attention.
                    FutureBuilder<int>(
                      future: minimalSaldoFuture,
                      builder: (context, snapshot) {
                        final minimal = snapshot.data ?? 0;
                        if (minimal <= 0) return const SizedBox.shrink();

                        final bisaDigunakan = (anak.saldo - minimal).clamp(
                          0,
                          anak.saldo,
                        );

                        return Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          message:
                              'Saldo bisa digunakan: ${formatRupiah(bisaDigunakan)}\n'
                              '${formatRupiah(minimal)} disisakan sebagai batas minimum saldo.',
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatRupiah(anak.saldo),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                // Nested translucent pill holding the santri switcher - was
                // a plain row directly on the white card before; now sits
                // on its own darker surface within the teal card so it
                // still reads as a distinct tappable element.
                Builder(
                  builder: (context) {
                    final provider = context.watch<AnakProvider>();
                    final bisaGanti = provider.anakList.length > 1;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: bisaGanti
                          ? () => openAnakPicker(context, provider)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, color: _teal, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    anak.nama,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${anak.nis} • ${anak.lembaga ?? 'Pondok Pusat'}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 11.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (bisaGanti) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Ganti Akun',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// A small count badge on the icon corner - e.g. how many of this tile's
  /// items need attention (due soon/overdue). Null/0 hides it entirely.
  final int? badgeCount;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // One shared teal card background/border across all three tiles
    // (matching the quick-action icons' background below) - only the icon
    // itself still carries each tile's own semantic color (teal/amber/
    // green), instead of every part of the card being tinted differently.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 14, color: color),
                  ),
                  if ((badgeCount ?? 0) > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB91C1C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // FittedBox+scaleDown (not maxLines: 2) - a label wrapping to
              // 2 lines while its sibling columns stay on 1 made the strip
              // look mismatched even with IntrinsicHeight equalizing the
              // outer height. Shrinking the text just enough to stay on one
              // line keeps every column's content the same shape.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five primary entry points below the balance card. Less frequently used
/// features live in a grouped "Semua Layanan" page so this row stays clear
/// as the application grows.
/// existing screen exactly like their other entry points elsewhere (the
/// FAB, the Laporan tab). Transfer opens TransferSaldoScreen, moving saldo
/// between santri sharing the same Kartu Keluarga (server-enforced).
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final raw = (constraints.maxWidth - gap * 4) / 5;
          final size = raw.clamp(38.0, 46.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuickActionButton(
                size: size,
                icon: Icons.send_rounded,
                label: 'Transfer',
                color: const Color(0xFF0F8F83),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TransferSaldoScreen(),
                  ),
                ),
              ),
              _QuickActionButton(
                size: size,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Top Up',
                color: const Color(0xFF028E86),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const TopupTab())),
              ),
              _QuickActionButton(
                size: size,
                icon: Icons.qr_code_scanner_rounded,
                label: 'Bayar',
                color: const Color(0xFF8B4BE8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanBayarScreen()),
                ),
              ),
              _QuickActionButton(
                size: size,
                icon: Icons.badge_rounded,
                label: 'Profil',
                color: const Color(0xFFE23483),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SantriProfileScreen(),
                  ),
                ),
              ),
              _QuickActionButton(
                size: size,
                icon: Icons.grid_view_rounded,
                label: 'Lainnya',
                color: const Color(0xFF475569),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllServicesScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          // Fixed width (matching the icon box) rather than letting the
          // Column auto-size to its widest child - if a label were ever
          // wider than the icon, that would silently re-center the icon
          // inward again for whichever button has the longest label,
          // undoing the point of spaceBetween anchoring the outer two
          // icons flush with the row's true edges.
          child: SizedBox(
            width: size,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.08)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: size * 0.4),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
