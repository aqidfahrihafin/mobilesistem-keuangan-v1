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
    int readInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TagihanRingkas(
      id: readInt(json['id']),
      jenisTagihanNama: json['jenis_tagihan_nama']?.toString() ?? 'Tagihan',
      periodeLabel: json['periode_label']?.toString() ?? '-',
      nominal: readInt(json['nominal']),
      nominalTerbayar: readInt(json['nominal_terbayar']),
      sisa: readInt(json['sisa']),
      status: json['status']?.toString() ?? 'belum_lunas',
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

  TransaksiReferensi({
    required this.type,
    required this.nama,
    this.nis,
    this.kode,
  });

  bool get isSantri => type == 'santri';
  bool get isUnitUsaha => type == 'unit_usaha';

  factory TransaksiReferensi.fromJson(Map<String, dynamic> json) {
    return TransaksiReferensi(
      type: json['type']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '-',
      nis: json['nis']?.toString(),
      kode: json['kode']?.toString(),
    );
  }
}

class TransaksiSantri {
  final int id;
  final String nama;
  final String? nis;
  final String? lembaga;

  TransaksiSantri({
    required this.id,
    required this.nama,
    this.nis,
    this.lembaga,
  });

  factory TransaksiSantri.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawLembaga = json['lembaga'];
    return TransaksiSantri(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      nama: json['nama']?.toString() ?? '-',
      nis: json['nis']?.toString(),
      // New API versions return the institution name directly. Keep this
      // map fallback so a mobile release remains readable while a hosting
      // deployment is briefly still serving the older object-shaped value.
      lembaga: rawLembaga is Map
          ? rawLembaga['nama']?.toString()
          : rawLembaga?.toString(),
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
  final String ledger;

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
  final TransaksiSantri? santri;

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
    this.ledger = 'saldo',
    this.metodeDetail,
    this.biayaMidtrans,
    this.biayaDitanggungWali,
    this.catatan,
    required this.createdAt,
    this.tagihan,
    this.referensi,
    this.santri,
    this.kwitansiId,
  });

  bool get isKredit => arah == 'kredit';

  factory Transaksi.fromJson(Map<String, dynamic> json) {
    final tagihanJson = json['tagihan'] as Map<String, dynamic>?;
    final referensiJson = json['referensi'] as Map<String, dynamic>?;
    final santriJson = json['santri'] as Map<String, dynamic>?;

    int readInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? readNullableInt(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    bool? readNullableBool(Object? value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value == 1 || value.toString() == '1' || value.toString() == 'true') {
        return true;
      }
      if (value == 0 ||
          value.toString() == '0' ||
          value.toString() == 'false') {
        return false;
      }
      return null;
    }

    return Transaksi(
      id: readInt(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      jenis: json['jenis']?.toString() ?? 'penyesuaian',
      arah: json['arah']?.toString() ?? 'debit',
      nominal: readInt(json['nominal']),
      saldoSebelum: readInt(json['saldo_sebelum']),
      saldoSesudah: readInt(json['saldo_sesudah']),
      status: json['status']?.toString() ?? 'berhasil',
      metode: json['metode']?.toString() ?? 'sistem',
      ledger: json['ledger']?.toString() ?? 'saldo',
      metodeDetail: json['metode_detail']?.toString(),
      biayaMidtrans: readNullableInt(json['biaya_midtrans']),
      biayaDitanggungWali: readNullableBool(json['biaya_ditanggung_wali']),
      catatan: json['catatan']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tagihan: tagihanJson != null
          ? TagihanRingkas.fromJson(tagihanJson)
          : null,
      referensi: referensiJson != null
          ? TransaksiReferensi.fromJson(referensiJson)
          : null,
      santri: santriJson != null ? TransaksiSantri.fromJson(santriJson) : null,
      kwitansiId: readNullableInt(json['kwitansi_id']),
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
  'transfer_ke_tabungan': 'Dipindahkan ke Tabungan',
  'setoran_tunai': 'Setoran Tabungan Tunai',
  'setoran_dari_saldo': 'Setoran dari Saldo',
  'setoran_midtrans': 'Setoran Tabungan',
  'koreksi_masuk': 'Koreksi Tabungan Masuk',
  'koreksi_keluar': 'Koreksi Tabungan Keluar',
};
