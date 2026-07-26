/// Snapshot of the tagihan a `pembayaran_tagihan` transaksi paid against -
/// only present (non-null on [Transaksi.tagihan]) when the transaksi is
/// actually linked to a tagihan; null for topup/penarikan/penyesuaian rows.
class TagihanRingkas {
  final int id;
  final String jenisTagihanNama;
  final String periodeLabel;
  final int nominal;
  final int nominalTerbayar;
  final int sisa;
  final String status;

  TagihanRingkas({
    required this.id,
    required this.jenisTagihanNama,
    required this.periodeLabel,
    required this.nominal,
    required this.nominalTerbayar,
    required this.sisa,
    required this.status,
  });

  /// Whether this is one of possibly several installments still in
  /// progress - the only case the riwayat row bothers surfacing a
  /// terbayar/sisa breakdown for (a fully-paid or non-cicilan tagihan has
  /// nothing extra worth showing beyond the transaksi amount itself).
  bool get sedangDicicil => status == 'sebagian';

  factory TagihanRingkas.fromJson(Map<String, dynamic> json) {
    return TagihanRingkas(
      id: json['id'] as int,
      jenisTagihanNama: json['jenis_tagihan_nama'] as String,
      periodeLabel: json['periode_label'] as String,
      nominal: (json['nominal'] as num).toInt(),
      nominalTerbayar: (json['nominal_terbayar'] as num).toInt(),
      sisa: (json['sisa'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}

/// The counterparty on the other side of a transaksi - who a kantin payment
/// went to, or which santri a transfer antar santri moved money to/from.
/// Null for transaksi types with no meaningful counterparty (topup,
/// penarikan, pembayaran_tagihan, penyesuaian).
class TransaksiReferensi {
  final String type;
  final String nama;
  final String? nis;
  final String? kode;

  TransaksiReferensi({required this.type, required this.nama, this.nis, this.kode});

  bool get isSantri => type == 'santri';
  bool get isUnitUsaha => type == 'unit_usaha';

  factory TransaksiReferensi.fromJson(Map<String, dynamic> json) {
    return TransaksiReferensi(
      type: json['type'] as String,
      nama: json['nama'] as String,
      nis: json['nis'] as String?,
      kode: json['kode'] as String?,
    );
  }
}

class Transaksi {
  final int id;
  final String uuid;
  final String jenis;
  final String arah;
  final int nominal;
  final int saldoSebelum;
  final int saldoSesudah;
  final String status;
  final String metode;

  /// The specific Midtrans channel (bni_va/bca_va/bri_va/qris - same kode
  /// as MetodeTopup.kode) when known, e.g. for a topup transaksi - null for
  /// anything else (tunai/transfer_bank/sistem never have one), or for an
  /// older Midtrans transaksi recorded before this was tracked. Screens
  /// should fall back to the coarse [metode] label when this is null.
  final String? metodeDetail;

  /// The Midtrans fee recorded on the topup that generated this transaksi,
  /// and who bore it - both null unless [jenis] is topup_transfer_wali and
  /// the fee feature (MidtransFeeService) has actually run for it. See
  /// TransaksiDetailScreen's Nominal Transfer/Biaya/Total Transfer rows.
  final int? biayaMidtrans;
  final bool? biayaDitanggungWali;

  final String? catatan;
  final DateTime createdAt;
  final TagihanRingkas? tagihan;
  final TransaksiReferensi? referensi;

  /// Present once a kwitansi resmi has been issued for this transaksi
  /// (pembayaran_tagihan from saldo, pembayaran_kantin) - null for every
  /// other jenis, and for a tunai_langsung/transfer_wali_tagihan tagihan
  /// payment, which never gets a Transaksi row at all (see KwitansiService).
  final int? kwitansiId;

  Transaksi({
    required this.id,
    required this.uuid,
    required this.jenis,
    required this.arah,
    required this.nominal,
    required this.saldoSebelum,
    required this.saldoSesudah,
    required this.status,
    required this.metode,
    this.metodeDetail,
    this.biayaMidtrans,
    this.biayaDitanggungWali,
    this.catatan,
    required this.createdAt,
    this.tagihan,
    this.referensi,
    this.kwitansiId,
  });

  bool get isKredit => arah == 'kredit';

  factory Transaksi.fromJson(Map<String, dynamic> json) {
    final tagihanJson = json['tagihan'] as Map<String, dynamic>?;
    final referensiJson = json['referensi'] as Map<String, dynamic>?;

    return Transaksi(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      jenis: json['jenis'] as String,
      arah: json['arah'] as String,
      nominal: (json['nominal'] as num).toInt(),
      saldoSebelum: (json['saldo_sebelum'] as num).toInt(),
      saldoSesudah: (json['saldo_sesudah'] as num).toInt(),
      status: json['status'] as String,
      metode: json['metode'] as String,
      metodeDetail: json['metode_detail'] as String?,
      biayaMidtrans: (json['biaya_midtrans'] as num?)?.toInt(),
      biayaDitanggungWali: json['biaya_ditanggung_wali'] as bool?,
      catatan: json['catatan'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      tagihan: tagihanJson != null
          ? TagihanRingkas.fromJson(tagihanJson)
          : null,
      referensi: referensiJson != null
          ? TransaksiReferensi.fromJson(referensiJson)
          : null,
      kwitansiId: (json['kwitansi_id'] as num?)?.toInt(),
    );
  }
}

const Map<String, String> jenisTransaksiLabel = {
  'topup_tunai': 'Top Up Tunai',
  'topup_transfer_wali': 'Top Up Wali',
  'penarikan_tunai': 'Penarikan Tunai',
  'pembayaran_tagihan': 'Pembayaran Tagihan',
  'penyesuaian': 'Penyesuaian',
  'pembayaran_kantin': 'Pembayaran Kantin',
  'transfer_antar_santri': 'Transfer Antar Santri',
};
