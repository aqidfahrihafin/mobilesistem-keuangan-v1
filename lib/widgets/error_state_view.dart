import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// One consistent "failed to load" view for every screen/section that
/// fetches from the API - previously each screen (Home, Transfer, Tagihan,
/// Laporan, ...) had its own slightly different icon/wording/layout for
/// this exact situation, which read as inconsistent/unpolished. Distinguishes
/// a genuine connectivity failure (ApiException with no statusCode - thrown
/// by ApiClient for a SocketException/TimeoutException, meaning no response
/// ever came back) from a real server-side error (4xx/5xx, which does carry
/// a statusCode and the server's own message), since those deserve different
/// wording.
///
/// Not scrollable itself - wrap in a scrollable (e.g. inside a
/// RefreshIndicator's child) where pull-to-refresh should also work while
/// this is showing, same as any other body content.
class ErrorStateView extends StatefulWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.error, this.onRetry});

  @override
  State<ErrorStateView> createState() => _ErrorStateViewState();
}

class _ErrorStateViewState extends State<ErrorStateView> {
  // Some callers' onRetry is fire-and-forget void (setState(...)), others
  // return a Future they don't await here either - there's no single signal
  // this widget can listen to for "the retry finished". A flat cooldown
  // after each tap is a simpler, callback-shape-agnostic way to stop a
  // frustrated user's rapid re-taps from queuing up a burst of duplicate
  // requests (seen for real: 30+ requests in 15s on a slow local dev
  // server from exactly this) - the button just re-enables shortly after
  // regardless of whether the retry actually resolved yet.
  static const _cooldown = Duration(milliseconds: 1500);

  bool _onCooldown = false;

  void _handleRetry() {
    if (_onCooldown) return;

    setState(() => _onCooldown = true);
    widget.onRetry?.call();

    Timer(_cooldown, () {
      if (mounted) setState(() => _onCooldown = false);
    });
  }

  bool get _isConnectivity =>
      widget.error is ApiException && (widget.error as ApiException).statusCode == null;

  String get _message {
    final e = widget.error;
    return e is ApiException ? e.message : 'Terjadi kesalahan tak terduga, silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                _isConnectivity ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 30,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isConnectivity ? 'Tidak Ada Koneksi' : 'Gagal Memuat Data',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _isConnectivity
                  ? 'Periksa koneksi internet Anda, lalu coba lagi.'
                  : _message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12.5, height: 1.4),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _onCooldown ? null : _handleRetry,
                icon: _onCooldown
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_onCooldown ? 'Memuat...' : 'Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
