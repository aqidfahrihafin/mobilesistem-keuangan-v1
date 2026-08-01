import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/anak.dart';
import '../models/transaksi.dart';
import 'formatters.dart';

const _border = PdfColors.grey300;
const _metodePdfLabel = {
  'tunai': 'Tunai',
  'transfer_bank': 'Transfer Bank',
  'midtrans': 'Midtrans',
};

/// A single-line "dd/MM/yy HH:mm" - deliberately more compact than
/// formatTanggalWaktu()'s "1 Jul 2026, 08:00" (used elsewhere on-screen),
/// since that format wraps onto 2-3 lines in the Tanggal column's narrow
/// width, making rows look taller/uneven than the rest of the table.
String _tanggalRincian(DateTime dateTime) {
  // See formatters.dart's formatTanggalWaktu - same fix, same reasoning
  // (createdAt is already local as of the model fix, but this stays
  // defensive rather than relying on every caller having converted).
  final dt = dateTime.toLocal();
  String p2(int n) => n.toString().padLeft(2, '0');
  final yy = p2(dt.year % 100);

  return '${p2(dt.day)}/${p2(dt.month)}/$yy ${p2(dt.hour)}:${p2(dt.minute)}';
}

/// Renders an A4 "evaluasi wali" report - a bank-statement-style summary
/// (opening/closing balance + a full transaction table) rather than a
/// charts dashboard, so it reads clearly both on screen and once printed -
/// then hands it to the OS print/share sheet (covers "save as PDF" too).
Future<void> cetakLaporanTransaksi({
  required Anak anak,
  required List<Transaksi> items,
  required String periodeLabel,
  required String namaPondok,
  int? saldoTabungan,
}) async {
  final doc = await buildLaporanTransaksiDocument(
    anak: anak,
    items: items,
    periodeLabel: periodeLabel,
    namaPondok: namaPondok,
    saldoTabungan: saldoTabungan,
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

/// Document-building half of [cetakLaporanTransaksi], split out so it can
/// be exercised directly (e.g. saved to a file for a visual check) without
/// going through the OS print/share sheet.
Future<pw.Document> buildLaporanTransaksiDocument({
  required Anak anak,
  required List<Transaksi> items,
  required String periodeLabel,
  required String namaPondok,
  int? saldoTabungan,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();

  final saldoMasuk = items
      .where((t) => t.ledger == 'saldo' && t.isKredit)
      .fold<int>(0, (s, t) => s + t.nominal);
  final belanjaDanPenarikan = items
      .where(
        (t) =>
            t.ledger == 'saldo' &&
            !t.isKredit &&
            t.jenis != 'transfer_ke_tabungan',
      )
      .fold<int>(0, (s, t) => s + t.nominal);
  final tabunganDariSaldo = items
      .where((t) => t.jenis == 'transfer_ke_tabungan')
      .fold<int>(0, (s, t) => s + t.nominal);
  final tabunganDariLuar = items
      .where((t) => t.ledger == 'tabungan' && t.isKredit)
      .fold<int>(0, (s, t) => s + t.nominal);
  final pembayaranDiLuarSaldo = items
      .where((t) => t.ledger == 'tagihan')
      .fold<int>(0, (s, t) => s + t.nominal);

  final sorted = [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  namaPondok.toUpperCase(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  'Laporan Transaksi Santri',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 0.7, color: _border),
                pw.SizedBox(height: 12),
              ],
            )
          : pw.SizedBox(),
      footer: (context) => pw.Column(
        children: [
          pw.Container(height: 0.7, color: _border),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dicetak otomatis ${formatTanggalWaktu(now)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Santri', anak.nama),
                  _infoRow('NIS', anak.nis),
                  _infoRow('Kelas/Lembaga', anak.lembaga ?? 'Pondok Pusat'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Periode', periodeLabel),
                  _infoRow('Jumlah Transaksi', '${items.length}'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Posisi Saldo Saat Ini',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(),
            1: pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _ringkasanHeader('Saldo Belanja (IDR)'),
                _ringkasanHeader('Saldo Tabungan (IDR)'),
              ],
            ),
            pw.TableRow(
              children: [
                _ringkasanValue(formatRupiah(anak.saldo), bold: true),
                _ringkasanValue(
                  saldoTabungan == null
                      ? 'Tidak tersedia'
                      : formatRupiah(saldoTabungan),
                  bold: true,
                  color: PdfColors.deepPurple700,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Mutasi Periode',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(),
          },
          children: [
            _mutasiRow('Saldo masuk', saldoMasuk, PdfColors.green800),
            _mutasiRow(
              'Belanja dan penarikan',
              belanjaDanPenarikan,
              PdfColors.red800,
            ),
            _mutasiRow(
              'Dipindah ke tabungan',
              tabunganDariSaldo,
              PdfColors.deepPurple700,
            ),
            _mutasiRow(
              'Setoran tabungan dari luar',
              tabunganDariLuar,
              PdfColors.deepPurple700,
            ),
            if (pembayaranDiLuarSaldo > 0)
              _mutasiRow(
                'Tagihan dibayar di luar saldo',
                pembayaranDiLuarSaldo,
                PdfColors.grey800,
              ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Catatan: perpindahan ke tabungan bukan pengeluaran. Saldo tabungan tidak dapat digunakan untuk membayar tagihan.',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Rincian Transaksi',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 8),
        if (sorted.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 16),
            child: pw.Text(
              'Tidak ada transaksi pada periode ini.',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder(
              top: const pw.BorderSide(color: _border, width: 0.6),
              bottom: const pw.BorderSide(color: _border, width: 0.6),
              left: const pw.BorderSide(color: _border, width: 0.6),
              right: const pw.BorderSide(color: _border, width: 0.6),
              horizontalInside: const pw.BorderSide(color: _border, width: 0.6),
              verticalInside: pw.BorderSide.none,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(80),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FixedColumnWidth(62),
              3: pw.FixedColumnWidth(62),
              4: pw.FixedColumnWidth(48),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _rincianHeader('Tanggal'),
                  _rincianHeader('Transaksi'),
                  _rincianHeader('Keluar (IDR)', alignRight: true),
                  _rincianHeader('Masuk (IDR)', alignRight: true),
                  _rincianHeader('Ledger'),
                ],
              ),
              ...sorted.map(
                (t) => pw.TableRow(
                  children: [
                    _rincianCell(_tanggalRincian(t.createdAt)),
                    _transaksiCell(t),
                    _rincianCell(
                      t.isKredit ? '-' : formatRupiah(t.nominal),
                      alignRight: true,
                      color: t.isKredit ? PdfColors.grey400 : PdfColors.red800,
                    ),
                    _rincianCell(
                      t.isKredit ? formatRupiah(t.nominal) : '-',
                      alignRight: true,
                      color: t.isKredit
                          ? PdfColors.green800
                          : PdfColors.grey400,
                    ),
                    _rincianCell(_ledgerLabel(t.ledger), bold: true),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
  );

  return doc;
}

String _ledgerLabel(String ledger) {
  switch (ledger) {
    case 'tabungan':
      return 'Tabungan';
    case 'tagihan':
      return 'Di luar saldo';
    default:
      return 'Saldo';
  }
}

pw.TableRow _mutasiRow(String label, int value, PdfColor color) {
  return pw.TableRow(
    children: [
      _ringkasanHeader(label),
      _ringkasanValue(formatRupiah(value), bold: true, color: color),
    ],
  );
}

/// The subtitle under a transaksi's jenis label - whatever gives the most
/// useful "what/who was this" context at a glance: the kantin's name, which
/// tagihan this settled, the transfer's counterparty, or (falling back)
/// the payment metode - mirrors the same context TransaksiDetailScreen
/// shows on-screen, just condensed into a table cell.
String? _subtitleFor(Transaksi t) {
  final referensi = t.referensi;
  if (referensi != null) {
    if (referensi.isUnitUsaha) return referensi.nama;
    if (referensi.isSantri) {
      return '${t.isKredit ? 'Dari' : 'Ke'} ${referensi.nama}';
    }
  }

  final tagihan = t.tagihan;
  if (tagihan != null) {
    // A plain hyphen, not "•" - the PDF's base Helvetica font has no glyph
    // for the bullet character (confirmed via a real render: it logs
    // "Unable to find a font to draw..." and drops the glyph silently).
    return '${tagihan.jenisTagihanNama} - ${tagihan.periodeLabel}';
  }

  return _metodePdfLabel[t.metode];
}

pw.Widget _transaksiCell(Transaksi t) {
  final subtitle = _subtitleFor(t);

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          jenisTransaksiLabel[t.jenis] ?? t.jenis,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 1.5),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _rincianHeader(String text, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
    ),
  );
}

pw.Widget _rincianCell(
  String text, {
  bool alignRight = false,
  bool bold = false,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.black,
      ),
    ),
  );
}

pw.Widget _ringkasanHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
    ),
  );
}

pw.Widget _ringkasanValue(String text, {bool bold = false, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.black,
      ),
    ),
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
