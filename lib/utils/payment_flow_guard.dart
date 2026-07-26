/// Mencegah lebih dari satu alur pembayaran membuka route/dialog secara
/// bersamaan akibat double-tap atau tap cepat pada dua tombol berbeda.
class PaymentFlowGuard {
  static bool _locked = false;

  static bool get isLocked => _locked;

  static Future<T?> run<T>(Future<T> Function() action) async {
    if (_locked) return null;

    _locked = true;
    try {
      return await action();
    } finally {
      _locked = false;
    }
  }
}
