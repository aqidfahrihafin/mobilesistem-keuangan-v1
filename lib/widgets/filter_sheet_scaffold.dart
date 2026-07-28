import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_modal_surface.dart';

const _teal = Color(0xFF0F766E);

/// Shared chrome for every "Filter X" bottom sheet in the app (Tagihan,
/// Transaksi, Pengeluaran, Laporan) - drag handle, title + close button,
/// a scrollable body of [sections], and a Reset/Terapkan footer. Filter
/// changes made inside a sheet only take effect on "Terapkan" (deferred
/// apply) - callers hold their own draft state and pass it back via
/// [onTerapkan], matching [onReset] for "clear everything".
class FilterSheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> sections;
  final VoidCallback onReset;
  final VoidCallback onTerapkan;

  const FilterSheetScaffold({
    super.key,
    required this.title,
    required this.sections,
    required this.onReset,
    required this.onTerapkan,
  });

  @override
  Widget build(BuildContext context) {
    return GlassModalSurface(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sections,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                          ),
                          onPressed: onReset,
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.borderRadius,
                            ),
                          ),
                          onPressed: onTerapkan,
                          child: const Text(
                            'Terapkan',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labeled group of chips inside a [FilterSheetScaffold], e.g. "Status
/// Tagihan" or "Periode Waktu".
class FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const FilterSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }
}

/// A single selectable chip inside a [FilterSection] - use with [Wrap] to
/// let a long option list flow onto multiple lines instead of one cramped
/// horizontal scroller.
class FilterChip2 extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const FilterChip2({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: icon != null
          ? Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : Colors.grey[600],
            )
          : null,
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: _teal,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: BorderSide(color: selected ? _teal : const Color(0xFFD8DBE2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
