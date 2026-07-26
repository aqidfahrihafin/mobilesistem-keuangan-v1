import 'package:flutter/foundation.dart';

/// Lets a widget nested inside one bottom-nav tab (e.g. the "Lihat Semua"
/// link on Home) switch to another tab, without MainScreen needing to pass
/// callbacks down through every layer.
class TabIndexProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  /// Set by [goToTagihanWithFilter] and consumed once by TagihanTab - lets
  /// Home's "Lunas Bulan Ini" tile land on Tagihan with that filter already
  /// applied instead of always resetting to the tab's own default filter.
  /// A one-shot signal, not persistent state: a later manual tap on the
  /// Tagihan bottom-nav item should NOT keep reapplying a stale filter from
  /// whatever Home tile was tapped once, arbitrarily long ago.
  ({String? status, String? periode})? _pendingTagihanFilter;

  void go(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  void goToTagihanWithFilter({String? status, String? periode}) {
    _pendingTagihanFilter = (status: status, periode: periode);
    go(1);
  }

  /// Returns the pending filter (if any) and clears it - "consume" rather
  /// than "peek", so it's only ever applied once.
  ({String? status, String? periode})? consumePendingTagihanFilter() {
    final pending = _pendingTagihanFilter;
    _pendingTagihanFilter = null;
    return pending;
  }
}
