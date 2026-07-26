/// Quick date-range presets shared by the Transaksi/Pengeluaran/Laporan
/// filter sheets - resolves to a concrete [start, end) window (end
/// exclusive) so callers can do a simple `isBefore`/`!isBefore` check
/// against a DateTime, or (null, null) for "semua waktu" (no filtering).
enum DateRangePreset {
  semua,
  hariIni,
  kemarin,
  mingguIni,
  mingguLalu,
  bulanIni,
  bulanLalu,
  tahunIni,
  kustom,
}

extension DateRangePresetX on DateRangePreset {
  String get label => switch (this) {
    DateRangePreset.semua => 'Semua Waktu',
    DateRangePreset.hariIni => 'Hari Ini',
    DateRangePreset.kemarin => 'Kemarin',
    DateRangePreset.mingguIni => 'Minggu Ini',
    DateRangePreset.mingguLalu => 'Minggu Lalu',
    DateRangePreset.bulanIni => 'Bulan Ini',
    DateRangePreset.bulanLalu => 'Bulan Lalu',
    DateRangePreset.tahunIni => 'Tahun Ini',
    DateRangePreset.kustom => 'Rentang Kustom',
  };

  (DateTime?, DateTime?) range() {
    final now = DateTime.now();
    final hariIni = DateTime(now.year, now.month, now.day);

    switch (this) {
      case DateRangePreset.semua:
        return (null, null);
      case DateRangePreset.hariIni:
        return (hariIni, hariIni.add(const Duration(days: 1)));
      case DateRangePreset.kemarin:
        final kemarin = hariIni.subtract(const Duration(days: 1));
        return (kemarin, hariIni);
      case DateRangePreset.mingguIni:
        final awal = hariIni.subtract(Duration(days: hariIni.weekday - 1));
        return (awal, hariIni.add(const Duration(days: 1)));
      case DateRangePreset.mingguLalu:
        final awalMingguIni = hariIni.subtract(
          Duration(days: hariIni.weekday - 1),
        );
        return (awalMingguIni.subtract(const Duration(days: 7)), awalMingguIni);
      case DateRangePreset.bulanIni:
        return (
          DateTime(now.year, now.month, 1),
          hariIni.add(const Duration(days: 1)),
        );
      case DateRangePreset.bulanLalu:
        final awalBulanIni = DateTime(now.year, now.month, 1);
        return (DateTime(now.year, now.month - 1, 1), awalBulanIni);
      case DateRangePreset.tahunIni:
        return (
          DateTime(now.year, 1, 1),
          hariIni.add(const Duration(days: 1)),
        );
      case DateRangePreset.kustom:
        // No fixed window - the actual start/end live in a separately
        // stored DateTimeRange (picked via showDateRangePicker) that only
        // the UI layer holds. Callers must special-case `kustom` before
        // relying on `.range()`/`.includes()`; this falls back to "semua
        // waktu" so a caller that forgets to special-case it fails open
        // (shows everything) rather than filtering everything out.
        return (null, null);
    }
  }

  bool includes(DateTime dt) {
    final (start, end) = range();
    if (start == null || end == null) return true;
    return !dt.isBefore(start) && dt.isBefore(end);
  }
}
