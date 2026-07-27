import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../models/banner_item.dart';
import '../services/wali_api.dart';

/// Holds the active Home tab banners fetched from /wali/banners (public, no
/// auth) - same "decorative, non-fatal" shape as AppInfoProvider: starts
/// empty, stays empty on failure (offline, nothing configured), and never
/// surfaces an error since BannerCarousel already renders nothing for an
/// empty list.
///
/// Polls (rather than fetching once) so an admin activating/deactivating a
/// banner shows up in an already-open app without needing a restart -
/// same interval as AppInfoProvider, since both are equally low-urgency.
class BannerProvider extends ChangeNotifier {
  final WaliApi _api;

  BannerProvider(this._api) {
    _load();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
  }

  static const _pollInterval = Duration(minutes: 2);

  Timer? _pollTimer;

  List<BannerItem> banners = [];

  Future<void> _load() async {
    try {
      final data = await _api.getBanners();
      final unchanged =
          data.length == banners.length &&
          List.generate(data.length, (i) => i).every(
            (i) =>
                data[i].id == banners[i].id &&
                data[i].judul == banners[i].judul &&
                data[i].gambarUrl == banners[i].gambarUrl &&
                data[i].linkUrl == banners[i].linkUrl,
          );
      if (unchanged) return;
      banners = data;
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
