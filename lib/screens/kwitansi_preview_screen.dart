import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class KwitansiPreviewScreen extends StatelessWidget {
  final String nomor;
  final Uint8List bytes;

  const KwitansiPreviewScreen({
    super.key,
    required this.nomor,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final safeName = nomor.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');

    return Scaffold(
      appBar: AppBar(title: const Text('Kwitansi Resmi')),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: '$safeName.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        useActions: true,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
