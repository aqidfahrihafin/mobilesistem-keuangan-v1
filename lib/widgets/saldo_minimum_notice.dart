import 'package:flutter/material.dart';

import '../utils/formatters.dart';

const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFDCE9E7);
const _iconBg = Color(0xFFEAF5F3);
const _teal = Color(0xFF0F766E);
const _ink = Color(0xFF334155);

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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _teal,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Batas saldo tercapai',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF17212B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$namaSantri belum dapat $aksi. Saldo minimum yang harus disisakan ${formatRupiah(minimal)}.',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
