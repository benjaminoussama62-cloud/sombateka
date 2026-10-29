import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Emoji couleur — asset local (web, instantané) ou natif (mobile).
class IntroEmoji extends StatelessWidget {
  const IntroEmoji({
    super.key,
    required this.emoji,
    required this.size,
  });

  final String emoji;
  final double size;

  static const _assetUrls = {
    '🛍️': 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f6cd.png',
    '🔒': 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f512.png',
    '💬': 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4ac.png',
    '💳': 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4b3.png',
    '✅': 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/2705.png',
  };

  static void precacheAll(BuildContext context) {
    if (!kIsWeb) return;
    for (final url in _assetUrls.values) {
      precacheImage(NetworkImage(url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final url = _assetUrls[emoji];
      if (url != null) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Text(emoji, style: TextStyle(fontSize: size * 0.9, height: 1.1)),
        );
      }
    }
    return Text(
      emoji,
      style: TextStyle(fontSize: size, height: 1.1),
    );
  }
}
