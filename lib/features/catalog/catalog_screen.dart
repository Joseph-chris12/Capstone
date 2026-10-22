import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/artwork.dart';
import '../../ui/components.dart';
import '../ar/artwork_info_sheet.dart';

/// The artworks in this gallery, as floating cards; the ones recognised this
/// session are marked.
///
/// The gallery experience is the camera, but this makes the content reviewable
/// without standing in front of the wall — useful for demos and marking.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.artworks,
    this.scannedSlugs = const {},
  });

  final List<Artwork> artworks;
  final Set<String> scannedSlugs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text('Artworks in This Gallery', style: AppText.title),
      ),
      body: artworks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No artworks published yet, or the gallery is still loading.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: artworks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _ArtworkTile(
                artwork: artworks[i],
                scanned: scannedSlugs.contains(artworks[i].slug),
              ),
            ),
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({required this.artwork, required this.scanned});

  final Artwork artwork;
  final bool scanned;

  String get _subtitle => <String>[
        if (artwork.artist != null && artwork.artist!.isNotEmpty) artwork.artist!,
        if (artwork.year != null && artwork.year!.isNotEmpty) artwork.year!,
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.panel,
        side: BorderSide(color: AppColors.keyline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => ArtworkDetails(
            title: artwork.title,
            subtitle: subtitle,
            description: artwork.description,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadii.tile,
                child: SizedBox.square(
                  dimension: 56,
                  child: artwork.thumbnailUrl == null
                      ? const ColoredBox(
                          color: AppColors.recessed,
                          child: Icon(Icons.image_outlined, color: AppColors.mocha),
                        )
                      : Image.network(
                          artwork.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.recessed,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.mocha,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelLg.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(color: AppColors.inkMuted),
                      ),
                  ],
                ),
              ),
              if (scanned)
                const AppBadge(label: 'Scanned', icon: Icons.check),
            ],
          ),
        ),
      ),
    );
  }
}
