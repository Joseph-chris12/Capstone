import 'package:flutter/material.dart';

import '../../data/artwork.dart';

/// Secondary screen: the list of AR-enabled artworks.
///
/// The gallery experience is the camera, but this makes the content reviewable
/// without standing in front of the wall — useful for demos and marking.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.artworks});

  final List<Artwork> artworks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('In this gallery')),
      body: artworks.isEmpty
          ? const Center(child: Text('No artworks published yet.'))
          : ListView.separated(
              itemCount: artworks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = artworks[i];
                final subtitle = <String>[
                  if (a.artist != null && a.artist!.isNotEmpty) a.artist!,
                  if (a.year != null && a.year!.isNotEmpty) a.year!,
                ].join(' · ');

                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(a.title),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: a.isCutout
                      ? const Tooltip(
                          message: 'Steps out of the frame',
                          child: Icon(Icons.auto_awesome, size: 20),
                        )
                      : null,
                  onTap: a.description == null || a.description!.isEmpty
                      ? null
                      : () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(a.description!),
                                ],
                              ),
                            ),
                          ),
                );
              },
            ),
    );
  }
}
