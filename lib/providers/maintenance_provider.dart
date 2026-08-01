import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class MaintenanceProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  Timer? _pollTimer;
  MaintenanceInfo? _info;
  bool _checking = false;

  MaintenanceProvider(this._apiClient) {
    _apiClient.setMaintenanceHandler(_handleMaintenance);
    unawaited(check());
  }

  bool get active => _info?.active == true;
  bool get checking => _checking;
  String get message => _info?.message ??
      'Sistem sedang dalam pemeliharaan. Silakan coba lagi nanti.';
  DateTime? get expectedEndAt => _info?.expectedEndAt;

  void _handleMaintenance(MaintenanceInfo info) {
    _info = info;
    _startPolling();
    notifyListeners();
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    notifyListeners();
    final status = await _apiClient.fetchMaintenanceStatus();
    _checking = false;
    if (status != null) {
      final wasActive = active;
      _info = status;
      if (status.active) {
        _startPolling();
      } else if (wasActive) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(check()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
