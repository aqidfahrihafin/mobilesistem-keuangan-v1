class Topup {
  final int id;
  final String uuid;
  final int santriId;
  final int? tagihanId;
  final int nominalDiminta;
  final String status;
  final int nominalPotonganTagihan;
  final int nominalKeSaldo;
  final int biayaMidtrans;
  final bool biayaDitanggungWali;
  final String? snapToken;
  final String? redirectUrl;
  final String? paymentType;
  final String? vaBank;
  final String? vaNumber;
  final String? qrUrl;
  final DateTime? expiryTime;
  final String? paidAt;

  Topup({
    required this.id,
    required this.uuid,
    required this.santriId,
    this.tagihanId,
    required this.nominalDiminta,
    required this.status,
    required this.nominalPotonganTagihan,
    required this.nominalKeSaldo,
    this.biayaMidtrans = 0,
    this.biayaDitanggungWali = false,
    this.snapToken,
    this.redirectUrl,
    this.paymentType,
    this.vaBank,
    this.vaNumber,
    this.qrUrl,
    this.expiryTime,
    this.paidAt,
  });

  /// True when this top up was created scoped to a single tagihan (see
  /// WaliApi.bayarTagihanViaMidtrans) rather than a generic saldo top up -
  /// it settles straight into that bill instead of saldo.
  bool get isTagihanScoped => tagihanId != null;

  bool get isPaid => status == 'paid';

  bool get isPending => status == 'pending';

  static const _metodeVa = {'bni_va', 'bca_va', 'bri_va'};

  bool get isVa => _metodeVa.contains(paymentType);

  bool get isQris => paymentType == 'qris';

  factory Topup.fromJson(Map<String, dynamic> json) {
    return Topup(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      santriId: json['santri_id'] as int,
      tagihanId: json['tagihan_id'] as int?,
      nominalDiminta: (json['nominal_diminta'] as num).toInt(),
      status: json['status'] as String,
      nominalPotonganTagihan: (json['nominal_potongan_tagihan'] as num).toInt(),
      nominalKeSaldo: (json['nominal_ke_saldo'] as num).toInt(),
      biayaMidtrans: (json['biaya_midtrans'] as num?)?.toInt() ?? 0,
      biayaDitanggungWali: json['biaya_ditanggung_wali'] as bool? ?? false,
      snapToken: json['snap_token'] as String?,
      redirectUrl: json['redirect_url'] as String?,
      paymentType: json['payment_type'] as String?,
      vaBank: json['va_bank'] as String?,
      vaNumber: json['va_number'] as String?,
      qrUrl: json['qr_url'] as String?,
      expiryTime: json['expiry_time'] != null
          ? DateTime.tryParse(json['expiry_time'] as String)?.toLocal()
          : null,
      paidAt: json['paid_at'] as String?,
    );
  }
}

const Map<String, String> statusTopupLabel = {
  'pending': 'Menunggu Pembayaran',
  'paid': 'Berhasil',
  'expired': 'Kedaluwarsa',
  'failed': 'Gagal',
  'cancelled': 'Dibatalkan',
  'refunded': 'Dikembalikan',
};
