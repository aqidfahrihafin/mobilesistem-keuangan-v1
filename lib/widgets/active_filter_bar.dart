import 'package:flutter/material.dart';

const _teal = Color(0xFF0F766E);

/// One always-visible pill in an [ActiveFilterBar] - shows the current
/// selection for one filter dimension (or its "Semua ..." default), tinted
/// teal when [active] (a non-default value is picked).
class ActiveFilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const ActiveFilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _teal.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _teal : const Color(0xFFD8DBE2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? _teal : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// "FILTER AKTIF" label + a horizontally-scrollable row of [pills]
/// (current value per filter dimension) + a circular button opening the
/// full filter sheet - the summary-of-current-state pattern used across
/// Tagihan/Transaksi/Pengeluaran/Laporan instead of a single always-open
/// chip row.
class ActiveFilterBar extends StatelessWidget {
  final List<ActiveFilterPill> pills;
  final VoidCallback onOpenFilter;
  final bool anyActive;

  /// Optional extra action rendered on the same row as the filter pills,
  /// between them and the circular filter button - e.g. Tagihan's "Bayar
  /// Beberapa Sekaligus" toggle, which needs to sit aligned with the filter
  /// button rather than floating on a row of its own. Null everywhere else,
  /// so every other screen using this bar is unaffected.
  final Widget? trailing;

  const ActiveFilterBar({
    super.key,
    required this.pills,
    required this.onOpenFilter,
    required this.anyActive,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER AKTIF',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pills.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => pills[index],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              const SizedBox(width: 10),
              InkWell(
                onTap: onOpenFilter,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: anyActive ? _teal : const Color(0xFFF1F2F4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: anyActive ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
