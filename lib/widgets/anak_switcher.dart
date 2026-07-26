import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/anak_provider.dart';
import 'glass_modal_surface.dart';

const _teal = Color(0xFF0F766E);

/// Opens the "pilih santri" bottom sheet - previously triggered from a
/// standalone pill above the balance card, now triggered by tapping the
/// santri profile row inside the balance card itself. Kept as a free
/// function (rather than a widget) so any tappable trigger can reuse the
/// exact same picker UI without needing to render a pill anywhere.
void openAnakPicker(BuildContext context, AnakProvider provider) {
  if (provider.anakList.length <= 1) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x520F172A),
    builder: (sheetContext) {
      return GlassModalSurface(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih Santri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              ...provider.anakList.map((anak) {
                final isSelected = anak.id == provider.selected?.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _teal,
                    child: Text(
                      anak.nama.isNotEmpty ? anak.nama[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    anak.nama,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${anak.nis} • ${anak.lembaga ?? 'Pondok Pusat'}',
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: _teal)
                      : null,
                  onTap: () {
                    context.read<AnakProvider>().select(anak);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
