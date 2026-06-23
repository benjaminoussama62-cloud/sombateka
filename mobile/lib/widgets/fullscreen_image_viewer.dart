import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';

/// Galerie plein écran avec option « Voir similaires ».
void openFullscreenGallery(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? thumbUrl,
  VoidCallback? onFindSimilar,
}) {
  if (imageUrls.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullscreenGallery(
        urls: imageUrls,
        initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
        thumbUrl: thumbUrl ?? imageUrls[initialIndex.clamp(0, imageUrls.length - 1)],
        onFindSimilar: onFindSimilar,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({
    required this.urls,
    required this.initialIndex,
    required this.thumbUrl,
    this.onFindSimilar,
  });

  final List<String> urls;
  final int initialIndex;
  final String thumbUrl;
  final VoidCallback? onFindSimilar;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                ),
                const Spacer(),
                if (widget.urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (widget.onFindSimilar != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 8,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onFindSimilar!();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.urls[_index],
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.black26,
                                  child: const Icon(Icons.image_search_rounded, color: Colors.white, size: 22),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voir des similaires',
                                  style: PremiumTheme.h1.copyWith(fontSize: 15, color: PremiumTheme.textDark),
                                ),
                                Text(
                                  'Même style, couleur et catégorie',
                                  style: PremiumTheme.body.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: PremiumTheme.blue),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
