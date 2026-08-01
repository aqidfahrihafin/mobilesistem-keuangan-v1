import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_item.dart';
import '../services/wali_api.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/loading_state_view.dart';
import 'notification_destination_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<NotificationInbox> _future;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<WaliApi>().getNotifications();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<WaliApi>().getNotifications();
    });
    await _future;
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await context.read<WaliApi>().readAllNotifications();
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openItem(NotificationItem item) async {
    if (!item.isRead) {
      // Reading is bookkeeping only; a temporary failure must not make the
      // notification appear untappable.
      try {
        await context.read<WaliApi>().readNotification(item.id);
      } catch (_) {}
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDestinationScreen(item: item),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: Text(_markingAll ? 'Memproses...' : 'Tandai Dibaca'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<NotificationInbox>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateView(
              title: 'Memuat notifikasi',
              message: 'Kami sedang menyiapkan kabar terbaru untuk Anda.',
              icon: Icons.notifications_active_outlined,
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(error: snapshot.error!, onRetry: _reload);
          }

          final items = snapshot.data?.items ?? const <NotificationItem>[];
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              message: 'Belum ada notifikasi.',
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => _openItem(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.type) {
      'tagihan_baru' || 'tagihan_jatuh_tempo' => (
        Icons.receipt_long_rounded,
        const Color(0xFFF59E0B),
      ),
      'topup_berhasil' => (
        Icons.account_balance_wallet_rounded,
        AppColors.primary,
      ),
      'penarikan_disetujui' => (
        Icons.payments_outlined,
        const Color(0xFF2563EB),
      ),
      _ => (Icons.notifications_rounded, const Color(0xFF8B4BE8)),
    };

    return Material(
      color: item.isRead ? AppColors.surface : const Color(0xFFF0FDFA),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadius,
        side: BorderSide(
          color: item.isRead ? AppColors.border : const Color(0xFF99F6E4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadius,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                    if (item.data['santri_nama']?.toString().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 7),
                      Text(
                        'Santri: ${item.data['santri_nama']}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      _relativeTime(item.createdAt),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.inMinutes < 1) return 'Baru saja';
  if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
  if (difference.inDays < 1) return '${difference.inHours} jam lalu';
  if (difference.inDays < 7) return '${difference.inDays} hari lalu';
  return '${time.day.toString().padLeft(2, '0')}/'
      '${time.month.toString().padLeft(2, '0')}/${time.year}';
}
