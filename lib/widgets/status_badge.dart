import 'package:flutter/material.dart';

import '../models/tagihan.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  static (Color bg, Color fg) colorsFor(String status) => switch (status) {
    'lunas' => (const Color(0xFFE7F6EF), const Color(0xFF15803D)),
    'sebagian' => (const Color(0xFFFEF6E7), const Color(0xFFB45309)),
    'dibatalkan' => (const Color(0xFFF1F2F4), const Color(0xFF52525B)),
    _ => (const Color(0xFFFDEBEB), const Color(0xFFB91C1C)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        statusTagihanLabel[status] ?? status,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
