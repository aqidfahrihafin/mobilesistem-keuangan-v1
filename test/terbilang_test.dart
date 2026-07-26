import 'package:flutter_test/flutter_test.dart';
import 'package:wali_santri/utils/struk.dart';

void main() {
  group('terbilang', () {
    test('handles zero', () {
      expect(terbilang(0), 'Nol');
    });

    test('handles single digits and teens', () {
      expect(terbilang(5), 'Lima');
      expect(terbilang(11), 'Sebelas');
      expect(terbilang(17), 'Tujuh belas');
    });

    test('handles tens and hundreds', () {
      expect(terbilang(50), 'Lima puluh');
      expect(terbilang(175), 'Seratus tujuh puluh lima');
      expect(terbilang(100), 'Seratus');
    });

    test('handles seribu (not "satu ribu")', () {
      expect(terbilang(1000), 'Seribu');
      expect(terbilang(2000), 'Dua ribu');
    });

    test('handles typical tagihan nominals', () {
      expect(terbilang(100000), 'Seratus ribu');
      expect(terbilang(175000), 'Seratus tujuh puluh lima ribu');
      expect(terbilang(1500000), 'Satu juta lima ratus ribu');
    });

    test('handles millions and billions', () {
      expect(terbilang(1000000), 'Satu juta');
      expect(terbilang(2500000), 'Dua juta lima ratus ribu');
      expect(terbilang(1000000000), 'Satu miliar');
    });
  });
}
