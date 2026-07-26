class Tagihan {
  final int id;
  final String jenisTagihanKode;
  final String jenisTagihanNama;
  final bool bisaDicicil;
  final String periodeLabel;
  final int nominal;
  final int? nominalSebelumDiskon;
  final int? diskonPersen;
  final int nominalTerbayar;
  final int sisa;
  final String status;
  final String? jatuhTempo;

  Tagihan({
    required this.id,
    required this.jenisTagihanKode,
    required this.jenisTagihanNama,
    required this.bisaDicicil,
    required this.periodeLabel,
    required this.nominal,
    this.nominalSebelumDiskon,
    this.diskonPersen,
    required this.nominalTerbayar,
    required this.sisa,
    required this.status,
    this.jatuhTempo,
  });

  bool get lunas => status == 'lunas';

  bool get dibatalkan => status == 'dibatalkan';

  /// Lunas or dibatalkan - either way, no further action (bayar, cicil,
  /// jatuh tempo tracking) makes sense against this tagihan anymore.
  bool get selesai => lunas || dibatalkan;

  bool get adaDiskon => nominalSebelumDiskon != null && diskonPersen != null;

  factory Tagihan.fromJson(Map<String, dynamic> json) {
    final jenisTagihan = json['jenis_tagihan'] as Map<String, dynamic>;

    return Tagihan(
      id: json['id'] as int,
      jenisTagihanKode: jenisTagihan['kode'] as String,
      jenisTagihanNama: jenisTagihan['nama'] as String,
      bisaDicicil: jenisTagihan['bisa_dicicil'] as bool? ?? false,
      periodeLabel: json['periode_label'] as String,
      nominal: (json['nominal'] as num).toInt(),
      nominalSebelumDiskon: (json['nominal_sebelum_diskon'] as num?)?.toInt(),
      diskonPersen: (json['diskon_persen'] as num?)?.toInt(),
      nominalTerbayar: (json['nominal_terbayar'] as num).toInt(),
      sisa: (json['sisa'] as num).toInt(),
      status: json['status'] as String,
      jatuhTempo: json['jatuh_tempo'] as String?,
    );
  }
}

const Map<String, String> statusTagihanLabel = {
  'belum_lunas': 'Belum Lunas',
  'sebagian': 'Dibayar Sebagian',
  'lunas': 'Lunas',
  'dibatalkan': 'Dibatalkan',
};
