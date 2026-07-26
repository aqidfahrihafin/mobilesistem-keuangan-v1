/// Fee schedule for one Midtrans channel (bni_va/bca_va/bri_va/qris), as
/// configured by the admin in Pengaturan > Midtrans. Mirrors
/// MidtransFeeService::hitungBiaya() so the app can compute a live estimate
/// as the wali types a custom nominal, without a round trip per keystroke.
class ChannelBiaya {
  final String tipe;
  final num nilai;

  const ChannelBiaya({required this.tipe, required this.nilai});

  bool get isPersen => tipe == 'persen';

  /// The fee for [nominal] under this channel's configured schedule. A
  /// percentage fee rounding to 0 on a very small nominal isn't a bug -
  /// same reasoning as the server-side MidtransFeeService::hitungBiaya().
  int hitung(int nominal) {
    return isPersen ? (nominal * nilai / 100).round() : nilai.round();
  }

  factory ChannelBiaya.fromJson(Map<String, dynamic> json) {
    return ChannelBiaya(
      tipe: json['tipe'] as String? ?? 'tetap',
      nilai: (json['nilai'] as num?) ?? 0,
    );
  }
}

/// GET /wali/topup/pengaturan's biaya_dibebankan_wali/biaya_channel fields -
/// whether the Midtrans fee is charged on top to the wali, and the fee
/// schedule per channel used to compute the live estimate.
class BiayaMidtransSettings {
  final bool dibebankanWali;

  /// Same setting, but for a direct-to-tagihan Midtrans payment - the admin
  /// can configure this independently of the plain top-up [dibebankanWali]
  /// (mis. pondok menanggung biaya untuk tagihan, wali menanggung untuk top
  /// up biasa). Used by TagihanTopupScreen; TopupTab keeps using
  /// [dibebankanWali] as before.
  final bool dibebankanWaliTagihan;

  final Map<String, ChannelBiaya> channel;

  const BiayaMidtransSettings({
    required this.dibebankanWali,
    required this.dibebankanWaliTagihan,
    required this.channel,
  });

  /// The fee for [metode]/[nominal] - 0 if the channel isn't in the
  /// schedule at all (shouldn't happen once the backend is deployed, but
  /// keeps this a safe no-op rather than a crash if it does).
  int hitung(String metode, int nominal) {
    return channel[metode]?.hitung(nominal) ?? 0;
  }

  factory BiayaMidtransSettings.fromJson(Map<String, dynamic> json) {
    final channelJson = json['biaya_channel'] as Map<String, dynamic>? ?? {};

    return BiayaMidtransSettings(
      dibebankanWali: json['biaya_dibebankan_wali'] as bool? ?? false,
      dibebankanWaliTagihan: json['biaya_dibebankan_wali_tagihan'] as bool? ?? false,
      channel: channelJson.map(
        (kode, value) => MapEntry(
          kode,
          ChannelBiaya.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  static const kosong = BiayaMidtransSettings(
    dibebankanWali: false,
    dibebankanWaliTagihan: false,
    channel: {},
  );
}
