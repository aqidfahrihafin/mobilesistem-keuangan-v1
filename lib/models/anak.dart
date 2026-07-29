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
    int readInt(Object? value, {int fallback = 0}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    String readString(Object? value, {String fallback = ''}) {
      return value?.toString() ?? fallback;
    }

    return Anak(
      id: readInt(json['id']),
      nis: readString(json['nis'], fallback: '-'),
      nama: readString(json['nama'], fallback: 'Santri'),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      tempatLahir: json['tempat_lahir']?.toString(),
      tanggalLahir: json['tanggal_lahir']?.toString(),
      alamat: json['alamat']?.toString(),
      status: readString(json['status'], fallback: 'aktif'),
      lembaga: json['lembaga']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      // Tolerant of a missing/null saldo (e.g. a santri with no
      // SaldoSantri row yet) - defaults to 0 rather than crashing the
      // whole anak list over one santri's balance not being ready yet.
      saldo: readInt(json['saldo']),
      hubungan: json['hubungan']?.toString(),
    );
  }
}
