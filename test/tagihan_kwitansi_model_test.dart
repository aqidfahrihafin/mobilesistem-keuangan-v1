import 'package:flutter_test/flutter_test.dart';
import 'package:wali_santri/models/tagihan.dart';

void main() {
  test('parses every official receipt attached to tagihan installments', () {
    final tagihan = Tagihan.fromJson({
      'id': 7,
      'jenis_tagihan': {
        'kode': 'SPP',
        'nama': 'SPP Bulanan',
        'bisa_dicicil': true,
      },
      'periode_label': '2026-08',
      'nominal': 100000,
      'nominal_terbayar': 40000,
      'sisa': 60000,
      'status': 'sebagian',
      'pembayaran': [
        {
          'id': 11,
          'nominal': 40000,
          'sumber': 'saldo',
          'sumber_label': 'Saldo',
          'dibayar_at': '2026-08-02T09:15:00+07:00',
          'kwitansi': {'id': 21, 'nomor': 'KWT-2026-000021'},
        },
      ],
    });

    expect(tagihan.pembayaran, hasLength(1));
    expect(tagihan.pembayaran.single.nominal, 40000);
    expect(tagihan.pembayaran.single.sumberLabel, 'Saldo');
    expect(tagihan.pembayaran.single.kwitansiId, 21);
    expect(tagihan.pembayaran.single.nomorKwitansi, 'KWT-2026-000021');
    expect(tagihan.pembayaran.single.dibayarAt, isNotNull);
  });
}
