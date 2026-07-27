import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_info_provider.dart';

/// The app's logo, wherever it's shown (splash/login/about) - the real
/// uploaded logo once AppInfoProvider has it, falling back to the bundled
/// local asset otherwise (unset, still loading, or the network image failed
/// to load) so this never renders a broken-image icon.
class AppLogoImage extends StatelessWidget {
  final BoxFit fit;

  const AppLogoImage({super.key, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final logoUrl = context.watch<AppInfoProvider>().logoUrl;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: logoUrl == null
          ? Image.asset(
              'assets/images/logo.png',
              key: const ValueKey('local'),
              fit: fit,
            )
          : Image.network(
              logoUrl,
              key: ValueKey(logoUrl),
              fit: fit,
              cacheWidth: 256,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset('assets/images/logo.png', fit: fit),
            ),
    );
  }
}
