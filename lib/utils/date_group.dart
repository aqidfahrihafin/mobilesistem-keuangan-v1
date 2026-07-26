import 'formatters.dart';

/// Buckets [items] into "Hari Ini" / "Kemarin" / a formatted date, in
/// whichever order they're already in (every caller today passes
/// newest-first) - this only groups items that fall on the same calendar
/// day, it doesn't itself sort them.
List<(String label, List<T> items)> groupByRelativeDate<T>(
  List<T> items,
  DateTime Function(T) dateOf,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final groups = <String, List<T>>{};
  final order = <String>[];

  for (final item in items) {
    final d = dateOf(item);
    final day = DateTime(d.year, d.month, d.day);
    final label = day == today
        ? 'Hari Ini'
        : day == yesterday
        ? 'Kemarin'
        : formatTanggal(day.toIso8601String());

    if (!groups.containsKey(label)) {
      groups[label] = <T>[];
      order.add(label);
    }
    groups[label]!.add(item);
  }

  return [for (final label in order) (label, groups[label]!)];
}
