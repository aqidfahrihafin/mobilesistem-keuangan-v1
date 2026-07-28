import 'dart:typed_data';

import '../models/anak.dart';
import '../models/app_info.dart';
import '../models/banner_item.dart';
import '../models/biaya_midtrans.dart';
import '../models/tagihan.dart';
import '../models/topup.dart';
import '../models/transaksi.dart';
import '../models/transfer_saldo_result.dart';
import '../models/unit_usaha.dart';
import 'api_client.dart';

/// Typed wrapper around the /api/wali/* endpoints documented at
/// /dev/api/wali in the main app. Auth (login/logout/me/password) lives in
/// AuthService instead, since it also owns session/token state.
class WaliApi {
  final ApiClient _api;

  WaliApi(this._api);

  /// Public (no auth) branding info - callable before login, see AppInfo.
  Future<AppInfo> getAppInfo() async {
    final data = await _api.get('/wali/app-info');
    return AppInfo.fromJson(data as Map<String, dynamic>);
  }

  /// Public (no auth) active Home tab banners, admin-managed, see BannerItem.
  Future<List<BannerItem>> getBanners() async {
    final data = await _api.get('/wali/banners');
    return (data['data'] as List)
        .map((e) => BannerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Anak>> getAnak() async {
    final data = await _api.get('/wali/anak');
    return (data['data'] as List)
        .map((e) => Anak.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getSaldo(int santriId) async {
    final data = await _api.get('/wali/anak/$santriId/saldo');
    return (data['saldo'] as num?)?.toInt() ?? 0;
  }

  Future<List<Transaksi>> getTransaksi(int santriId) async {
    final data = await _api.get('/wali/anak/$santriId/transaksi');
    return (data['data'] as List)
        .map((e) => Transaksi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Tagihan>> getTagihan(int santriId) async {
    final data = await _api.get('/wali/anak/$santriId/tagihan');
    return (data['data'] as List)
        .map((e) => Tagihan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [nominal] is optional - omitted pays the full remaining sisa (same as
  /// before this param existed). A smaller amount is only accepted server-
  /// side when the tagihan's jenis has bisa_dicicil enabled (see
  /// [Tagihan.bisaDicicil]); otherwise the API returns 422 with
  /// ApiException.code == 'nominal_tidak_valid'. [pin] is the wali's 6-digit
  /// transaction PIN, verified server-side before the payment goes through -
  /// see PinService on the server.
  Future<void> bayarTagihanDariSaldo(
    int santriId,
    int tagihanId, {
    int? nominal,
    required String pin,
  }) async {
    await _api.post('/wali/anak/$santriId/tagihan/$tagihanId/bayar', {
      if (nominal != null) 'nominal': nominal,
      'pin': pin,
    });
  }

  /// Pays a tagihan directly via Midtrans Core API (VA/QRIS) for exactly its
  /// remaining amount - never touches saldo. `metode` is one of 'bni_va',
  /// 'bca_va', 'bri_va', 'qris', same as [mulaiTopupCore]. The returned
  /// [Topup] has `tagihanId` set and renders the same way a regular Core API
  /// top up does (VA number / QR code card, poll via [syncTopupStatus]).
  Future<Topup> bayarTagihanViaMidtrans(
    int santriId,
    int tagihanId,
    String metode,
  ) async {
    final data = await _api.post(
      '/wali/anak/$santriId/tagihan/$tagihanId/topup/core',
      {'metode': metode},
    );
    return Topup.fromJson(data as Map<String, dynamic>);
  }

  Future<Topup> mulaiTopup(int santriId, int nominal) async {
    final data = await _api.post('/wali/anak/$santriId/topup', {
      'nominal': nominal,
    });
    return Topup.fromJson(data as Map<String, dynamic>);
  }

  /// Charges via Midtrans's Core API instead of Snap (`mulaiTopup` above) -
  /// returns a VA number or QR image URL to render directly in-app instead
  /// of a redirect_url that needs an external browser. `metode` is one of
  /// 'bni_va', 'bca_va', 'bri_va', 'qris', matching TopupWaliService::METODE_*
  /// on the server.
  Future<Topup> mulaiTopupCore(int santriId, int nominal, String metode) async {
    final data = await _api.post('/wali/anak/$santriId/topup/core', {
      'nominal': nominal,
      'metode': metode,
    });
    return Topup.fromJson(data as Map<String, dynamic>);
  }

  /// The minimum saldo a wali must leave untouched when paying a tagihan
  /// *from saldo* (SaldoFloorService on the server) - no longer related to
  /// top up despite the endpoint path/JSON key (kept for backward
  /// compatibility with already-shipped app builds). Admin editable via
  /// /admin/pengaturan/midtrans, so it can't be hardcoded client-side.
  Future<int> getMinimalSaldoBayarTagihan() async {
    final data = await _api.get('/wali/topup/pengaturan');
    return (data['minimal_saldo_setelah_topup'] as num).toInt();
  }

  /// Same endpoint as getMinimalSaldoBayarTagihan(), parsed for its
  /// biaya_dibebankan_wali/biaya_channel fields instead - the Midtrans fee
  /// schedule, admin-editable via /admin/pengaturan/midtrans, used to show
  /// a live "+Rp X biaya admin" estimate on the channel picker.
  Future<BiayaMidtransSettings> getBiayaMidtransSettings() async {
    final data = await _api.get('/wali/topup/pengaturan');
    return BiayaMidtransSettings.fromJson(data as Map<String, dynamic>);
  }

  Future<Topup> getTopupStatus(int topupId) async {
    final data = await _api.get('/wali/topup/$topupId');
    return Topup.fromJson(data as Map<String, dynamic>);
  }

  /// Pulls status directly from Midtrans rather than waiting for their
  /// webhook - see the "Cek Status Sekarang" note in /dev/api/wali. Needed
  /// because a VA transfer or QRIS scan happens entirely outside the app
  /// (banking app / e-wallet), so the app has no other way to know the
  /// moment it finishes.
  Future<Topup> syncTopupStatus(int topupId) async {
    final data = await _api.post('/wali/topup/$topupId/sync');
    return Topup.fromJson(data as Map<String, dynamic>);
  }

  /// Resolves a scanned kantin QR code to a friendly name before asking the
  /// wali for a nominal - the QR itself only encodes the plain `kode`.
  /// Throws ApiException (404 kode unknown, 422 kantin nonaktif).
  Future<UnitUsaha> lookupUnitUsaha(String kode) async {
    final data = await _api.get('/wali/unit-usaha/$kode');
    return UnitUsaha.fromJson(data as Map<String, dynamic>);
  }

  /// Pays a kantin/unit-usaha purchase directly out of the santri's saldo -
  /// unlike a tagihan payment there's no Midtrans alternative and no saldo
  /// floor (SaldoFloorService doesn't apply here, see KantinPembayaranService
  /// on the server). ApiException.code == 'saldo_tidak_cukup' on 422. [pin]
  /// is the wali's 6-digit transaction PIN, verified server-side.
  Future<KantinPembayaranResult> bayarKantin(
    int santriId,
    String kode,
    int nominal, {
    required String pin,
  }) async {
    final data = await _api.post('/wali/anak/$santriId/bayar-kantin', {
      'kode': kode,
      'nominal': nominal,
      'pin': pin,
    });
    return KantinPembayaranResult.fromJson(data as Map<String, dynamic>);
  }

  /// Whether the wali has already set a transaction PIN - screens gating a
  /// sensitive action check this first so a wali with no PIN yet is routed
  /// to set one up instead of being shown a PIN pad that can never succeed.
  Future<bool> pinStatus() async {
    final data = await _api.get('/wali/pin/status');
    return data['has_pin'] as bool;
  }

  /// Checks the account password on its own, with no side effect - lets the
  /// PIN setup screen verify it for real before revealing the PIN form.
  /// Throws ApiException with a field error on 'password' if wrong.
  Future<void> confirmPassword(String password) async {
    await _api.post('/wali/pin/confirm-password', {'password': password});
  }

  /// Sets (or replaces) the transaction PIN - requires the account password
  /// to prove it's really the account owner, same as changing the password
  /// itself. Throws ApiException with field errors on 'current_password' or
  /// 'pin' (e.g. confirmation mismatch).
  Future<void> setPin({
    required String currentPassword,
    required String pin,
    required String pinConfirmation,
  }) async {
    await _api.post('/wali/pin', {
      'current_password': currentPassword,
      'pin': pin,
      'pin_confirmation': pinConfirmation,
    });
  }

  /// Fetches the official PDF through its short-lived signed URL and returns
  /// the bytes for an in-app preview. The browser is never opened.
  Future<({String nomor, Uint8List bytes})> getKwitansiPdf(
    int kwitansiId,
  ) async {
    final data = await _api.get('/wali/kwitansi/$kwitansiId');
    final bytes = await _api.downloadBytes(data['pdf_url'] as String);

    return (
      nomor: data['nomor_kwitansi'] as String? ?? 'kwitansi-$kwitansiId',
      bytes: bytes,
    );
  }

  /// Santri sharing the same Kartu Keluarga as [santriId] - the candidate
  /// recipient list for a transfer. Not limited to this wali's own anak,
  /// since a keluarga can have more than one wali account.
  Future<List<Anak>> getSaudara(int santriId) async {
    final data = await _api.get('/wali/anak/$santriId/saudara');
    return (data['data'] as List)
        .map((e) => Anak.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Moves saldo directly from [dariSantriId] to [keSantriId] - both must
  /// share the same Kartu Keluarga (enforced server-side). ApiException.code
  /// == 'saldo_tidak_cukup' on 422 when the sender's saldo is insufficient.
  Future<TransferSaldoResult> transferSaldo({
    required int dariSantriId,
    required int keSantriId,
    required int nominal,
    required String pin,
  }) async {
    final data = await _api.post('/wali/anak/$dariSantriId/transfer', {
      'ke_santri_id': keSantriId,
      'nominal': nominal,
      'pin': pin,
    });
    return TransferSaldoResult.fromJson(data as Map<String, dynamic>);
  }

  /// Upserts by [fcmToken] server-side, re-pointing it at whichever wali is
  /// currently signed in - safe to call on every login/session-restore.
  Future<void> registerDeviceToken(String fcmToken) async {
    await _api.post('/wali/device-token', {'fcm_token': fcmToken});
  }

  /// Only called on a hard sign-out (see AuthService.logout()) - a soft lock
  /// keeps the session alive, so the device should keep receiving pushes.
  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _api.delete('/wali/device-token', {'fcm_token': fcmToken});
  }
}
