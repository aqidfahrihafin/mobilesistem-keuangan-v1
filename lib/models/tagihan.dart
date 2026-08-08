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
  final List<TagihanPembayaran> pembayaran;

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
    this.pembayaran = const [],
  });

  bool get lunas => status == 'lunas';

  bool get dibatalkan => status == 'dibatalkan';

  /// Lunas or dibatalkan - either way, no further action (bayar, cicil,
  /// jatuh tempo tracking) makes sense against this tagihan anymore.
  bool get selesai => lunas || dibatalkan;

  bool get adaDiskon => nominalSebelumDiskon != null && diskonPersen != null;

  factory Tagihan.fromJson(Map<String, dynamic> json) {
    final jenisTagihan =
        json['jenis_tagihan'] as Map<String, dynamic>? ?? const {};

    int readInt(Object? value, {int fallback = 0}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int? readNullableInt(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    bool readBool(Object? value) {
      if (value is bool) return value;
      return value == 1 ||
          value?.toString() == '1' ||
          value?.toString() == 'true';
    }

    return Tagihan(
      id: readInt(json['id']),
      jenisTagihanKode: jenisTagihan['kode']?.toString() ?? '-',
      jenisTagihanNama: jenisTagihan['nama']?.toString() ?? 'Tagihan',
      bisaDicicil: readBool(jenisTagihan['bisa_dicicil']),
      periodeLabel: json['periode_label']?.toString() ?? '-',
      nominal: readInt(json['nominal']),
      nominalSebelumDiskon: readNullableInt(json['nominal_sebelum_diskon']),
      diskonPersen: readNullableInt(json['diskon_persen']),
      nominalTerbayar: readInt(json['nominal_terbayar']),
      sisa: readInt(json['sisa']),
      status: json['status']?.toString() ?? 'belum_lunas',
      jatuhTempo: json['jatuh_tempo']?.toString(),
      pembayaran: (json['pembayaran'] as List? ?? const [])
          .map(
            (e) =>
                TagihanPembayaran.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

class TagihanPembayaran {
  final int id;
  final int nominal;
  final String sumber;
  final String sumberLabel;
  final DateTime? dibayarAt;
  final int? kwitansiId;
  final String? nomorKwitansi;

  const TagihanPembayaran({
    required this.id,
    required this.nominal,
    required this.sumber,
    required this.sumberLabel,
    this.dibayarAt,
    this.kwitansiId,
    this.nomorKwitansi,
  });

  factory TagihanPembayaran.fromJson(Map<String, dynamic> json) {
    final kwitansi = json['kwitansi'] as Map<String, dynamic>?;
    return TagihanPembayaran(
      id: (json['id'] as num).toInt(),
      nominal: (json['nominal'] as num).toInt(),
      sumber: json['sumber']?.toString() ?? '-',
      sumberLabel: json['sumber_label']?.toString() ?? '-',
      dibayarAt: json['dibayar_at'] == null
          ? null
          : DateTime.tryParse(json['dibayar_at'].toString())?.toLocal(),
      kwitansiId: kwitansi?['id'] == null
          ? null
          : (kwitansi!['id'] as num).toInt(),
      nomorKwitansi: kwitansi?['nomor']?.toString(),
    );
  }
}

const Map<String, String> statusTagihanLabel = {
  'belum_lunas': 'Belum Lunas',
  'sebagian': 'Dibayar Sebagian',
  'lunas': 'Lunas',
  'dibatalkan': 'Dibatalkan',
};
