class TransaksiTabungan {
  final int id;
  final String jenis;
  final String kanal;
  final String arah;
  final int nominal;
  final int saldoSesudah;
  final DateTime dibuatAt;

  const TransaksiTabungan({
    required this.id,
    required this.jenis,
    required this.kanal,
    required this.arah,
    required this.nominal,
    required this.saldoSesudah,
    required this.dibuatAt,
  });

  factory TransaksiTabungan.fromJson(Map<String, dynamic> json) {
    int angka(dynamic nilai) =>
        nilai is num ? nilai.toInt() : int.tryParse('$nilai') ?? 0;

    return TransaksiTabungan(
      id: angka(json['id']),
      jenis: '${json['jenis'] ?? ''}',
      kanal: '${json['kanal'] ?? ''}',
      arah: '${json['arah'] ?? ''}',
      nominal: angka(json['nominal']),
      saldoSesudah: angka(json['saldo_sesudah']),
      dibuatAt: DateTime.parse('${json['dibuat_at']}'),
    );
  }
}

class RingkasanTabungan {
  final int saldoSantri;
  final int saldo;
  final int saldoBisaDipindahkan;
  final String status;
  final List<TransaksiTabungan> transaksi;

  const RingkasanTabungan({
    required this.saldoSantri,
    required this.saldo,
    required this.saldoBisaDipindahkan,
    required this.status,
    required this.transaksi,
  });

  factory RingkasanTabungan.fromJson(Map<String, dynamic> json) {
    int angka(dynamic nilai) =>
        nilai is num ? nilai.toInt() : int.tryParse('$nilai') ?? 0;

    return RingkasanTabungan(
      saldoSantri: angka(json['saldo_santri']),
      saldo: angka(json['saldo_tabungan']),
      saldoBisaDipindahkan: angka(json['saldo_bisa_dipindahkan']),
      status: '${json['status'] ?? 'belum_dibuka'}',
      transaksi: ((json['transaksi'] as List?) ?? const [])
          .map((item) => TransaksiTabungan.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}

class HasilPindahTabungan {
  final int transaksiId;
  final int nominal;
  final int saldoSantri;
  final int saldoTabungan;

  const HasilPindahTabungan({
    required this.transaksiId,
    required this.nominal,
    required this.saldoSantri,
    required this.saldoTabungan,
  });

  factory HasilPindahTabungan.fromJson(Map<String, dynamic> json) {
    int angka(dynamic nilai) =>
        nilai is num ? nilai.toInt() : int.tryParse('$nilai') ?? 0;

    return HasilPindahTabungan(
      transaksiId: angka(json['transaksi_id']),
      nominal: angka(json['nominal']),
      saldoSantri: angka(json['saldo_santri']),
      saldoTabungan: angka(json['saldo_tabungan']),
    );
  }
}
