import 'package:flutter/material.dart';

import 'ar_bridge.dart';

/// Title, artist and description for the artwork currently being tracked.
///
/// Rendered natively rather than as DOM inside the WebView so it scrolls and
/// themes like the rest of the app, and stays readable while the video plays
/// behind it.
class ArtworkInfoSheet extends StatelessWidget {
  const ArtworkInfoSheet({super.key, required this.event});

  final ArTargetEvent event;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (event.artist != null && event.artist!.isNotEmpty) event.artist!,
      if (event.year != null && event.year!.isNotEmpty) event.year!,
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
