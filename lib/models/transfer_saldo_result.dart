/// Result of a successful transfer antar santri (1 KK) - what the success
/// screen needs from both sides of the transfer, not a full Transaksi model.
class TransferSaldoResult {
  final int id;
  final int dariId;
  final String dariNama;
  final int dariSaldoSesudah;
  final int keId;
  final String keNama;
  final int keSaldoSesudah;
  final int nominal;
  final DateTime dibuatAt;

  TransferSaldoResult({
    required this.id,
    required this.dariId,
    required this.dariNama,
    required this.dariSaldoSesudah,
    required this.keId,
    required this.keNama,
    required this.keSaldoSesudah,
    required this.nominal,
    required this.dibuatAt,
  });

  factory TransferSaldoResult.fromJson(Map<String, dynamic> json) {
    final dari = json['dari'] as Map<String, dynamic>;
    final ke = json['ke'] as Map<String, dynamic>;

    return TransferSaldoResult(
      id: (json['id'] as num).toInt(),
      dariId: (dari['id'] as num).toInt(),
      dariNama: dari['nama'] as String,
      dariSaldoSesudah: (dari['saldo_sesudah'] as num).toInt(),
      keId: (ke['id'] as num).toInt(),
      keNama: ke['nama'] as String,
      keSaldoSesudah: (ke['saldo_sesudah'] as num).toInt(),
      nominal: (json['nominal'] as num).toInt(),
      dibuatAt: DateTime.parse(json['dibuat_at'] as String).toLocal(),
    );
  }
}
