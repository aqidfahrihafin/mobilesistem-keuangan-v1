class Anak {
  final int id;
  final String nis;
  final String nama;
  final String? jenisKelamin;
  final String? tempatLahir;
  final String? tanggalLahir;
  final String? alamat;
  final String status;
  final String? lembaga;
  final String? fotoUrl;
  final int saldo;
  final String? hubungan;

  Anak({
    required this.id,
    required this.nis,
    required this.nama,
    this.jenisKelamin,
    this.tempatLahir,
    this.tanggalLahir,
    this.alamat,
    required this.status,
    this.lembaga,
    this.fotoUrl,
    required this.saldo,
    this.hubungan,
  });

  Anak copyWith({int? saldo}) {
    return Anak(
      id: id,
      nis: nis,
      nama: nama,
      jenisKelamin: jenisKelamin,
      tempatLahir: tempatLahir,
      tanggalLahir: tanggalLahir,
      alamat: alamat,
      status: status,
      lembaga: lembaga,
      fotoUrl: fotoUrl,
      saldo: saldo ?? this.saldo,
      hubungan: hubungan,
    );
  }

  factory Anak.fromJson(Map<String, dynamic> json) {
    return Anak(
      id: json['id'] as int,
      nis: json['nis'] as String,
      nama: json['nama'] as String,
      jenisKelamin: json['jenis_kelamin'] as String?,
      tempatLahir: json['tempat_lahir'] as String?,
      tanggalLahir: json['tanggal_lahir'] as String?,
      alamat: json['alamat'] as String?,
      status: json['status'] as String,
      lembaga: json['lembaga'] as String?,
      fotoUrl: json['foto_url'] as String?,
      // Tolerant of a missing/null saldo (e.g. a santri with no
      // SaldoSantri row yet) - defaults to 0 rather than crashing the
      // whole anak list over one santri's balance not being ready yet.
      saldo: (json['saldo'] as num?)?.toInt() ?? 0,
      hubungan: json['hubungan'] as String?,
    );
  }
}
