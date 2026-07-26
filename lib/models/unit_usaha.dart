class UnitUsaha {
  final String kode;
  final String nama;

  UnitUsaha({required this.kode, required this.nama});

  factory UnitUsaha.fromJson(Map<String, dynamic> json) {
    return UnitUsaha(
      kode: json['kode'] as String,
      nama: json['nama'] as String,
    );
  }
}

/// Result of a successful kantin payment - just what the receipt-style
/// success screen (and the printed struk) needs, not a full Transaksi model.
class KantinPembayaranResult {
  final int id;
  final String unitUsahaNama;
  final String santriNama;
  final String santriNis;
  final int nominal;
  final int saldoSesudah;
  final DateTime dibayarAt;

  KantinPembayaranResult({
    required this.id,
    required this.unitUsahaNama,
    required this.santriNama,
    required this.santriNis,
    required this.nominal,
    required this.saldoSesudah,
    required this.dibayarAt,
  });

  factory KantinPembayaranResult.fromJson(Map<String, dynamic> json) {
    final santri = json['santri'] as Map<String, dynamic>;

    return KantinPembayaranResult(
      id: (json['id'] as num).toInt(),
      unitUsahaNama:
          (json['unit_usaha'] as Map<String, dynamic>)['nama'] as String,
      santriNama: santri['nama'] as String,
      santriNis: santri['nis'] as String,
      nominal: (json['nominal'] as num).toInt(),
      saldoSesudah: (json['saldo_sesudah'] as num).toInt(),
      dibayarAt: DateTime.parse(json['dibayar_at'] as String).toLocal(),
    );
  }
}
