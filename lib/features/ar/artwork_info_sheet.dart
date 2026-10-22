import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/components.dart';
import 'ar_bridge.dart';

/// Glass card for the artwork currently being tracked (Figma "Contextual
/// Detection Drawer"): thumbnail, title, artist · year, and the sound toggle.
/// Tapping it opens the full description.
class ArtworkInfoSheet extends StatelessWidget {
  const ArtworkInfoSheet({
    super.key,
    required this.event,
    required this.thumbnailUrl,
    required this.muted,
    required this.onToggleMute,
  });

  final ArTargetEvent event;
  final String? thumbnailUrl;
  final bool muted;
  final VoidCallback onToggleMute;

  String get _subtitle => <String>[
        if (event.artist != null && event.artist!.isNotEmpty) event.artist!,
        if (event.year != null && event.year!.isNotEmpty) event.year!,
      ].join(' · ');

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ArtworkDetails(
        title: event.title,
        subtitle: _subtitle,
        description: event.description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: GlassPanel(
        borderRadius: AppRadii.tile,
        opacity: 0.9,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _showDetails(context),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: thumbnailUrl == null
                        ? const Icon(
                            Icons.image_outlined,
                            color: AppColors.mocha,
                          )
                        : Image.network(
                            thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_outlined,
                              color: AppColors.mocha,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelLg.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          subtitle.isEmpty ? 'Tap for the story' : subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: muted ? 'Unmute' : 'Mute',
                    child: Material(
                      color: AppColors.espresso,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onToggleMute,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            muted ? Icons.volume_off : Icons.volume_up,
                            size: 18,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title, artist and description, shown in a bottom sheet.
class ArtworkDetails extends StatelessWidget {
  const ArtworkDetails({
    super.key,
    required this.title,
    required this.subtitle,
    this.description,
  });

  final String title;
  final String subtitle;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.headline),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppText.labelLg.copyWith(color: AppColors.mocha)),
            ],
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description!, style: AppText.body),
            ],
          ],
        ),
      ),
    );
  }
}
