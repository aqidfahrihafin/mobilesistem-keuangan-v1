import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../services/wali_api.dart';

/// Holds the branding fetched from /wali/app-info (public, no auth), so the
/// splash/login/about screens can show the real uploaded logo and app/pondok
/// name instead of their hardcoded defaults, once available.
///
/// Starts fully null and stays that way on failure (offline, server down,
/// nothing configured yet) - every consumer already has a correct hardcoded
/// fallback, so this is purely decorative and never worth surfacing an error
/// for. Deliberately not persisted to disk - the fetch is small and runs in
/// parallel with the splash screen's own minimum-display timer, so by the
/// time a user could actually see a screen, it has almost always already
/// resolved.
///
/// Also re-fetches periodically (much less often than saldo - this rarely
/// changes) so an admin updating the logo/app name/pondok name on the web
/// shows up in an already-open app without needing a restart.
class AppInfoProvider extends ChangeNotifier {
  final WaliApi _api;

  AppInfoProvider(this._api) {
    _load();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
  }

  static const _pollInterval = Duration(minutes: 2);

  Timer? _pollTimer;

  String? namaAplikasi;
  String? namaPondok;
  String? logoUrl;

  Future<void> _load() async {
    try {
      final info = await _api.getAppInfo();
      namaAplikasi = info.namaAplikasi;
      namaPondok = info.namaPondok;
      logoUrl = info.logoUrl;
      notifyListeners();
    } catch (_) {
      // Non-fatal - see class doc.
    }
  }

  Future<void> _pollTick() async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
