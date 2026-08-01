import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anak.dart';
import '../models/notification_item.dart';
import '../models/tagihan.dart';
import '../models/transaksi.dart';
import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../theme/app_theme.dart';
import '../widgets/error_state_view.dart';
import 'tagihan_detail_screen.dart';
import 'transaksi_detail_screen.dart';

class NotificationDestinationScreen extends StatefulWidget {
  final NotificationItem item;

  const NotificationDestinationScreen({super.key, required this.item});

  @override
  State<NotificationDestinationScreen> createState() =>
      _NotificationDestinationScreenState();
}

class _NotificationDestinationScreenState
    extends State<NotificationDestinationScreen> {
  late Future<_Destination> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  int? _id(String key) {
    final value = widget.item.data[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<_Destination> _load() async {
    final api = context.read<WaliApi>();
    final santriId = _id('santri_id');
    final transaksiId = _id('transaksi_id');
    final tagihanId = _id('tagihan_id');

    try {
      if (santriId != null && transaksiId != null) {
        return _Destination.transaksi(
          await api.getTransaksiDetail(santriId, transaksiId),
        );
      }

      if (santriId != null && tagihanId != null) {
        final results = await Future.wait<Object>([
          api.getAnak(),
          api.getTagihanDetail(santriId, tagihanId),
        ]);
        final anak = (results[0] as List<Anak>).firstWhere(
          (item) => item.id == santriId,
        );
        return _Destination.tagihan(anak, results[1] as Tagihan);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const _Destination.info(sourceUnavailable: true);
      }
      rethrow;
    }

    return const _Destination.info();
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Destination>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Notifikasi')),
            body: ErrorStateView(error: snapshot.error!, onRetry: _retry),
          );
        }

        final destination = snapshot.data!;
        if (destination.transaksi != null) {
          return TransaksiDetailScreen(transaksi: destination.transaksi!);
        }
        if (destination.tagihan != null && destination.anak != null) {
          return TagihanDetailScreen(
            anak: destination.anak!,
            tagihan: destination.tagihan!,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Detail Notifikasi')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (destination.sourceUnavailable) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: AppRadius.borderRadius,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Data transaksi atau tagihan asal sudah tidak tersedia, kemungkinan karena perubahan atau pemulihan database. Isi notifikasi tetap ditampilkan sebagai arsip.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.borderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.item.body,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Destination {
  final Anak? anak;
  final Tagihan? tagihan;
  final Transaksi? transaksi;
  final bool sourceUnavailable;

  const _Destination._({
    this.anak,
    this.tagihan,
    this.transaksi,
    this.sourceUnavailable = false,
  });

  const _Destination.info({bool sourceUnavailable = false})
      : this._(sourceUnavailable: sourceUnavailable);

  factory _Destination.tagihan(Anak anak, Tagihan tagihan) =>
      _Destination._(anak: anak, tagihan: tagihan);

  factory _Destination.transaksi(Transaksi transaksi) =>
      _Destination._(transaksi: transaksi);
}
