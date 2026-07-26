import 'package:flutter/material.dart';

import '../models/tagihan.dart';

enum JatuhTempoUrgensi { akanJatuhTempo, hariIni, terlambat }

class JatuhTempoInfo {
  final JatuhTempoUrgensi urgensi;

  /// Days until due (positive), 0 = today, negative = days overdue.
  final int hari;

  const JatuhTempoInfo(this.urgensi, this.hari);

  String get label => switch (urgensi) {
    JatuhTempoUrgensi.terlambat => 'Terlambat ${-hari} hari',
    JatuhTempoUrgensi.hariIni => 'Jatuh tempo hari ini',
    JatuhTempoUrgensi.akanJatuhTempo => hari == 1
        ? 'Jatuh tempo besok'
        : 'Jatuh tempo $hari hari lagi',
  };

  Color get color => switch (urgensi) {
    JatuhTempoUrgensi.terlambat => const Color(0xFFB91C1C),
    JatuhTempoUrgensi.hariIni => const Color(0xFFB91C1C),
    JatuhTempoUrgensi.akanJatuhTempo => const Color(0xFF9A6700),
  };

  Color get background => switch (urgensi) {
    JatuhTempoUrgensi.terlambat => const Color(0xFFFDECEC),
    JatuhTempoUrgensi.hariIni => const Color(0xFFFDECEC),
    JatuhTempoUrgensi.akanJatuhTempo => const Color(0xFFFFF3E0),
  };

  IconData get icon => switch (urgensi) {
    JatuhTempoUrgensi.terlambat => Icons.error_rounded,
    JatuhTempoUrgensi.hariIni => Icons.error_rounded,
    JatuhTempoUrgensi.akanJatuhTempo => Icons.schedule_rounded,
  };
}

/// Reminder window - a tagihan due within this many days is flagged as
/// "akan jatuh tempo", matching how far ahead the home banner/badges warn.
const kJatuhTempoReminderHari = 3;

/// Null when the tagihan is already lunas/dibatalkan, has no jatuh_tempo,
/// or its due date is further away than [kJatuhTempoReminderHari] - i.e.
/// null means "nothing worth flagging", not "no due date at all".
JatuhTempoInfo? hitungJatuhTempo(Tagihan tagihan) {
  if (tagihan.lunas || tagihan.status == 'dibatalkan') return null;
  if (tagihan.jatuhTempo == null) return null;

  final tanggal = DateTime.tryParse(tagihan.jatuhTempo!);
  if (tanggal == null) return null;

  final now = DateTime.now();
  final hariIni = DateTime(now.year, now.month, now.day);
  final due = DateTime(tanggal.year, tanggal.month, tanggal.day);
  final selisih = due.difference(hariIni).inDays;

  if (selisih < 0) return JatuhTempoInfo(JatuhTempoUrgensi.terlambat, selisih);
  if (selisih == 0) return JatuhTempoInfo(JatuhTempoUrgensi.hariIni, 0);
  if (selisih <= kJatuhTempoReminderHari) {
    return JatuhTempoInfo(JatuhTempoUrgensi.akanJatuhTempo, selisih);
  }

  return null;
}
