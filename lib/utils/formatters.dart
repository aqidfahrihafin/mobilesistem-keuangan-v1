const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatRupiah(int nominal) {
  final digits = nominal.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }

  return '${nominal < 0 ? '-' : ''}Rp $buffer';
}

String formatTanggal(String isoDate) {
  try {
    // The server sends timestamps with an explicit +07:00 offset (see
    // TransaksiResource etc.) - DateTime.parse recognizes that offset and
    // normalizes the result to UTC internally (isUtc: true), so reading
    // .day/.month/.year directly would show the WRONG calendar date for
    // anything before ~07:00 Jakarta time (still "yesterday" in UTC).
    // .toLocal() converts back to the device's real-world local time
    // before any component is read - a no-op for already-local/date-only
    // strings (no offset in the source), so it's safe unconditionally.
    final d = DateTime.parse(isoDate).toLocal();
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
  } catch (_) {
    return isoDate;
  }
}

String formatTanggalWaktu(DateTime dateTime) {
  // See formatTanggal's comment - same fix, same reasoning.
  final d = dateTime.toLocal();
  final jam = d.hour.toString().padLeft(2, '0');
  final menit = d.minute.toString().padLeft(2, '0');

  return '${d.day} ${_bulan[d.month - 1]} ${d.year}, $jam:$menit';
}
