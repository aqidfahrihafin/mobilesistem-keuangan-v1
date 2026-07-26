import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../models/unit_usaha.dart';
import 'formatters.dart';

/// Renders an official numbered kwitansi (80mm thermal roll width) for a
/// tagihan that has at least one payment recorded, then hands it to the OS
/// print sheet - which also covers "save as PDF" and "share" without extra
/// UI.
///
/// The kwitansi number is derived client-side from the tagihan's own
/// (stable, unique, database-assigned) id - `GET /wali/anak/{santri}/tagihan`
/// still doesn't expose a separately-tracked kwitansi-number sequence or
/// `dicatat_oleh`, so there's no "who recorded this" line; everything else
/// needed for a real numbered receipt (jenis, periode, nominal, status) is
/// already available.
Future<void> cetakStrukTagihan({
  required Anak anak,
  required Tagihan tagihan,
  required String namaPondok,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();
  final nomorKwitansi =
      '${tagihan.jenisTagihanKode.toUpperCase()}/${tagihan.id}/${now.year}';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              namaPondok.toUpperCase(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'KWITANSI PEMBAYARAN',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _row('No. Kwitansi', nomorKwitansi, bold: true),
          _row('Tanggal', formatTanggalWaktu(now)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          _row('Santri', anak.nama),
          _row('NIS', anak.nis),
          _row('Kelas/Lembaga', anak.lembaga ?? 'Pondok Pusat'),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          _row('Jenis Tagihan', tagihan.jenisTagihanNama),
          _row('Periode', tagihan.periodeLabel),
          if (tagihan.jatuhTempo != null)
            _row('Jatuh Tempo', formatTanggal(tagihan.jatuhTempo!)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          if (tagihan.adaDiskon)
            _row('Sebelum Diskon', formatRupiah(tagihan.nominalSebelumDiskon!)),
          if (tagihan.adaDiskon) _row('Diskon', '${tagihan.diskonPersen}%'),
          _row('Nominal Tagihan', formatRupiah(tagihan.nominal)),
          _row('Terbayar', formatRupiah(tagihan.nominalTerbayar), bold: true),
          if (!tagihan.lunas)
            _row('Sisa', formatRupiah(tagihan.sisa), bold: true),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Terbilang:',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '${terbilang(tagihan.nominalTerbayar)} rupiah',
            style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
              child: pw.Text(
                statusTagihanLabel[tagihan.status]?.toUpperCase() ??
                    tagihan.status.toUpperCase(),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'Dicetak otomatis oleh sistem',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Terima kasih',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

/// Same idea as [cetakStrukTagihan] but for a kantin/unit-usaha purchase -
/// the kwitansi number is derived from the underlying Transaksi's own id,
/// the one stable reference the API already returns for this payment.
Future<void> cetakStrukKantin(
  KantinPembayaranResult hasil, {
  required String namaPondok,
}) async {
  final doc = pw.Document();
  final nomorKwitansi = 'KANTIN/${hasil.id}/${hasil.dibayarAt.year}';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              namaPondok.toUpperCase(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'KWITANSI PEMBAYARAN KANTIN',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _row('No. Kwitansi', nomorKwitansi, bold: true),
          _row('Tanggal', formatTanggalWaktu(hasil.dibayarAt)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          _row('Santri', hasil.santriNama),
          _row('NIS', hasil.santriNis),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          _row('Dibayar ke', hasil.unitUsahaNama),
          _row('Nominal', formatRupiah(hasil.nominal), bold: true),
          _row('Sisa Saldo', formatRupiah(hasil.saldoSesudah)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Terbilang:',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '${terbilang(hasil.nominal)} rupiah',
            style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'Dicetak otomatis oleh sistem',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Terima kasih',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

pw.Widget _dashedDivider() {
  return pw.Container(
    height: 0.7,
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.7, style: pw.BorderStyle.dashed),
      ),
    ),
  );
}

pw.Widget _row(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(width: 6),
        pw.Flexible(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

const _satuan = [
  '',
  'satu',
  'dua',
  'tiga',
  'empat',
  'lima',
  'enam',
  'tujuh',
  'delapan',
  'sembilan',
  'sepuluh',
  'sebelas',
];

String _eja(int n) {
  if (n < 12) return _satuan[n];
  if (n < 20) return '${_eja(n - 10)} belas';
  if (n < 100) {
    final sisa = n % 10;
    return '${_eja(n ~/ 10)} puluh${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  if (n < 200) {
    final sisa = n - 100;
    return 'seratus${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  if (n < 1000) {
    final sisa = n % 100;
    return '${_eja(n ~/ 100)} ratus${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  if (n < 2000) {
    final sisa = n - 1000;
    return 'seribu${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  if (n < 1000000) {
    final sisa = n % 1000;
    return '${_eja(n ~/ 1000)} ribu${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  if (n < 1000000000) {
    final sisa = n % 1000000;
    return '${_eja(n ~/ 1000000)} juta${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
  }
  final sisa = n % 1000000000;
  return '${_eja(n ~/ 1000000000)} miliar${sisa != 0 ? ' ${_eja(sisa)}' : ''}';
}

/// Indonesian amount-in-words, capitalized - standard on a real kwitansi
/// alongside the numeric nominal, so the paid amount can't be silently
/// altered/misread. Exposed (not private) so it can be unit-tested.
String terbilang(int nominal) {
  if (nominal == 0) return 'Nol';
  final hasil = _eja(nominal).trim();
  return '${hasil[0].toUpperCase()}${hasil.substring(1)}';
}
