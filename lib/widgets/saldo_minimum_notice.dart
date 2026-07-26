import 'package:flutter/material.dart';

import '../utils/formatters.dart';

const _amberBg = Color(0xFFFFF7E6);
const _amberBorder = Color(0xFFFBE8C6);
const _amberIconBg = Color(0xFFFDECC8);
const _amberFg = Color(0xFF9A6700);

/// A single, self-contained "can't proceed - saldo is at the floor" status
/// card - shared by TransferSaldoScreen and ScanBayarScreen so a blocked
/// state reads as one clear, deliberate message instead of two generic
/// amber banners stacked back to back (which is what both screens did
/// before this - the same warning box used for "here are the rules" *and*
/// "here's why this is blocked right now", one right after the other).
class SaldoMinimumNotice extends StatelessWidget {
  final String namaSantri;
  final int minimal;

  /// The verb describing what's blocked, e.g. "transfer" or "membayar kantin"
  /// - keeps the message accurate per screen without duplicating the widget.
  final String aksi;

  const SaldoMinimumNotice({
    super.key,
    required this.namaSantri,
    required this.minimal,
    required this.aksi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amberBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _amberIconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.savings_rounded, color: _amberFg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo di Batas Minimum',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _amberFg),
                ),
                const SizedBox(height: 3),
                Text(
                  'Saldo $namaSantri sudah di batas minimum ${formatRupiah(minimal)} - '
                  'belum bisa $aksi sampai saldo di atas batas ini.',
                  style: const TextStyle(color: _amberFg, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
