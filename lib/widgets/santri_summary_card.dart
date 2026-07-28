import 'package:flutter/material.dart';

import '../models/anak.dart';
import '../utils/formatters.dart';
import 'flat_card.dart';

const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

/// "Who is this transaction for" header - avatar + identity on top, saldo
/// as its own visually distinct row below a divider (rather than crammed
/// into one line), matching the balance-forward hierarchy banking apps use.
/// Shared by every money-flow screen (Top Up, kantin scan-to-pay, transfer)
/// instead of each hand-rolling its own version, so this look/spacing stays
/// consistent everywhere a wali sees "which santri, how much saldo".
class SantriSummaryCard extends StatelessWidget {
  final Anak anak;
  final String saldoLabel;

  /// When set, the whole card becomes tappable (e.g. opening a santri
  /// switcher) and shows a trailing affordance icon for it.
  final VoidCallback? onTap;

  const SantriSummaryCard({
    super.key,
    required this.anak,
    this.saldoLabel = 'Saldo saat ini',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  anak.nama.isNotEmpty ? anak.nama[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anak.nama,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS ${anak.nis} • ${anak.lembaga ?? 'Pondok Pusat'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.unfold_more_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 15,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                saldoLabel,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              const Spacer(),
              Text(
                formatRupiah(anak.saldo),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
