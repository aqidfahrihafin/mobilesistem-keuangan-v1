import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../models/anak.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';

/// Loads the wali's anak list once and tracks which one is currently
/// selected, so Home/Tagihan/Riwayat tabs all show the same anak without
/// each needing their own switcher UI or duplicate fetch logic.
///
/// Also keeps the selected anak's saldo "live" while the app is open, via a
/// periodic poll - every screen that reads `selected.saldo` through this
/// provider benefits automatically (Home's balance card, Transfer's "Dari"
/// balance, etc.) without each needing its own timer. No WebSocket/push
/// infra needed for this: a wali only cares that the number is fresh
/// *while they're looking at it*, and a modest poll interval delivers
/// that far more simply than a persistent connection would.
class AnakProvider extends ChangeNotifier {
  final WaliApi _api;

  AnakProvider(this._api);

  static const _pollInterval = Duration(seconds: 20);

  List<Anak> _anakList = [];
  Anak? _selected;
  bool _loading = true;
  Object? _error;
  Timer? _pollTimer;

  List<Anak> get anakList => _anakList;
  Anak? get selected => _selected;
  bool get loading => _loading;

  /// The raw error/exception (not stringified) - so a display widget can
  /// distinguish e.g. an ApiException with no statusCode (connectivity
  /// failure) from a real server error, not just show a flat message.
  Object? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _anakList = await _api.getAnak();

      final previouslySelectedId = _selected?.id;
      _selected = _anakList.isEmpty
          ? null
          : _anakList.firstWhere(
              (a) => a.id == previouslySelectedId,
              orElse: () => _anakList.first,
            );
    } catch (e, stackTrace) {
      _error = e;
      // Temporary diagnostic - ErrorStateView shows a generic message for
      // anything that isn't ApiException, so the real cause (a JSON
      // shape/type mismatch, most likely) is otherwise invisible. Remove
      // once the hosting "gagal memuat data" issue is root-caused.
      debugPrint('AnakProvider.load() failed: $e');
      debugPrint('$stackTrace');
    }

    _loading = false;
    notifyListeners();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
  }

  Future<void> _pollTick() async {
    // Skip while the app isn't actually in the foreground - no point
    // spending battery/data refreshing a screen nobody can see. The next
    // tick after resuming picks up right away (worst case _pollInterval
    // stale, same as any polling approach).
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    try {
      await refreshSaldoSelected();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // The session is gone (logged out, or the token was revoked
        // server-side) - AuthService.logout() has no reference back to
        // this provider to stop it directly, so a 401 here is the signal
        // instead. Clears the stale anak/saldo too, not just the timer -
        // otherwise a different wali logging in on the same device
        // without an app restart would briefly see the previous wali's
        // data before the next load() replaces it.
        _pollTimer?.cancel();
        _anakList = [];
        _selected = null;
        notifyListeners();
      }
      // Any other status - silent, same as below.
    } catch (_) {
      // Silent - a background poll failing shouldn't surface an error UI;
      // the next tick (or a manual pull-to-refresh) retries on its own.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void select(Anak anak) {
    if (_selected?.id == anak.id) return;
    _selected = anak;
    notifyListeners();
  }

  Future<void> refreshSaldoSelected() async {
    final current = _selected;
    if (current == null) return;

    await refreshSaldoFor(current.id);
  }

  /// Refreshes the cached saldo for any santri in [anakList] - not just the
  /// currently selected one. Needed for transfer antar santri, which moves
  /// money on both sides of the transfer, but the recipient sibling isn't
  /// necessarily this wali's own selected (or even linked) anak. A no-op if
  /// [santriId] isn't in this wali's own list, since there's nothing local
  /// to update in that case.
  ///
  /// Only notifies listeners when the saldo actually changed - the periodic
  /// poll calls this every tick regardless of whether anything moved, and
  /// every screen watching this provider (which is most of the app) would
  /// otherwise rebuild every tick for no visible reason - the kind of
  /// pointless rebuild a wali can perceive as the screen "flickering" every
  /// 20 seconds. A real change (e.g. right after a transfer/payment) still
  /// notifies immediately as before.
  Future<void> refreshSaldoFor(int santriId) async {
    final index = _anakList.indexWhere((a) => a.id == santriId);
    if (index == -1) return;

    final saldo = await _api.getSaldo(santriId);
    if (saldo == _anakList[index].saldo) return;

    final updated = _anakList[index].copyWith(saldo: saldo);
    _anakList[index] = updated;

    if (_selected?.id == santriId) _selected = updated;
    notifyListeners();
  }
}
