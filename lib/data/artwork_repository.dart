import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import 'artwork.dart';

class ArManifestException implements Exception {
  ArManifestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads published content from Supabase and assembles the AR manifest.
class ArtworkRepository {
  ArtworkRepository(this._client);

  final SupabaseClient _client;

  String _publicUrl(String bucket, String path) =>
      _client.storage.from(bucket).getPublicUrl(path);

  /// Throws if [artworks] does not occupy target indexes 0..n-1 exactly once,
  /// in order.
  ///
  /// The .mind bundle addresses its targets purely by position, so a gap or a
  /// duplicate means every artwork past that point renders its neighbour's
  /// video. There is no visible error when that happens — the app looks like
  /// it is working — so this fails loudly instead.
  static void validateOrdering(List<Artwork> artworks) {
    for (var i = 0; i < artworks.length; i++) {
      if (artworks[i].targetIndex != i) {
        throw ArManifestException(
          'Artwork "${artworks[i].slug}" has target_index '
          '${artworks[i].targetIndex} but sits at position $i. The database is '
          'out of sync with the .mind bundle — re-run tools/compile-targets.',
        );
      }
    }
  }

  /// Fetches the current tracking bundle and its artworks.
  ///
  /// Both queries are filtered by RLS as well, so a row that should not be
  /// public cannot arrive here even if the filter below were dropped.
  Future<ArManifest> fetchManifest() async {
    final bundle = await _client
        .from('target_bundles')
        .select('mind_path, version')
        .eq('is_current', true)
        .maybeSingle();

    if (bundle == null) {
      throw ArManifestException(
        'No published target bundle. Run tools/compile-targets to build and '
        'upload one.',
      );
    }

    final rows = await _client
        .from('artworks')
        .select()
        .eq('is_active', true)
        .order('target_index');

    final artworks = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => Artwork.fromRow(
              r,
              (path) => _publicUrl(Config.videosBucket, path),
            ))
        .toList();

    if (artworks.isEmpty) {
      throw ArManifestException(
        'The target bundle has no active artworks attached to it.',
      );
    }

    validateOrdering(artworks);

    return ArManifest(
      mindUrl: _publicUrl(Config.targetsBucket, bundle['mind_path'] as String),
      artworks: artworks,
    );
  }
}
