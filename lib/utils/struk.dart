import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/anak.dart';
import '../models/tagihan.dart';
import '../models/unit_usaha.dart';
import 'formatters.dart';

const _brand = PdfColors.teal700;

/// Renders a current tagihan status slip (80mm thermal roll width), then
/// hands it to the OS
/// print sheet - which also covers "save as PDF" and "share" without extra
/// UI.
///
/// This is deliberately not called a kwitansi: official receipts use the
/// server-issued permanent KWT number and are downloaded from transaction
/// detail. This local document is a cumulative snapshot of the bill.
Future<void> cetakStrukTagihan({
  required Anak anak,
  required Tagihan tagihan,
  required String namaPondok,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();
  final referensi = 'TGH-${tagihan.id.toString().padLeft(6, '0')}';

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
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: _brand,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'RINGKASAN STATUS TAGIHAN',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1.2, color: _brand),
          pw.SizedBox(height: 8),
          _row('Referensi Tagihan', referensi, bold: true),
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
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                border: pw.Border.all(color: _brand, width: 0.7),
              ),
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
              'Ringkasan ini bukan kwitansi resmi. Unduh kwitansi resmi bernomor KWT dari detail transaksi.',
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

/// Local transaction proof for a just-completed kantin payment. The
/// official KWT-numbered receipt remains the signed server PDF.
Future<void> cetakStrukKantin(
  KantinPembayaranResult hasil, {
  required String namaPondok,
}) async {
  final doc = pw.Document();
  final referensi = 'TX-${hasil.id.toString().padLeft(6, '0')}';

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
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: _brand,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'BUKTI TRANSAKSI KANTIN',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1.2, color: _brand),
          pw.SizedBox(height: 8),
          _row('Referensi Transaksi', referensi, bold: true),
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
              'Bukti ini bukan kwitansi resmi. Kwitansi resmi bernomor KWT tersedia di detail transaksi.',
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
