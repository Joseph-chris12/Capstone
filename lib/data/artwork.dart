/// One AR-enabled artwork.
///
/// [targetIndex] is this artwork's position inside the compiled `.mind`
/// bundle. It is assigned by tools/compile-targets, which compiles the bundle
/// and writes these rows in the same run — the app trusts it completely, so a
/// hand-edited value silently plays the wrong video over the wrong painting.
class Artwork {
  const Artwork({
    required this.id,
    required this.slug,
    required this.title,
    required this.targetIndex,
    required this.aspectRatio,
    required this.videoUrl,
    required this.videoMode,
    this.artist,
    this.year,
    this.description,
    this.chromaColor,
    this.planeWidth,
    this.planeHeight,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String? artist;
  final String? year;
  final String? description;

  final int targetIndex;

  /// Target height divided by width. MindAR normalises every target to 1 unit
  /// wide, so this is the height a plane needs to exactly cover the artwork.
  final double aspectRatio;

  final String videoUrl;

  /// 'fullframe' — the clip replaces the canvas.
  /// 'cutout'    — green-screen clip, keyed at runtime, may overflow the canvas.
  final String videoMode;
  final String? chromaColor;

  final double? planeWidth;
  final double? planeHeight;
  final double offsetX;
  final double offsetY;

  bool get isCutout => videoMode == 'cutout';

  static double _toDouble(Object? v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static double? _toNullableDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// [resolveVideoUrl] turns the stored storage path into a public URL, so the
  /// model stays free of any Supabase types.
  factory Artwork.fromRow(
    Map<String, dynamic> row,
    String Function(String path) resolveVideoUrl,
  ) {
    return Artwork(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      artist: row['artist'] as String?,
      year: row['year'] as String?,
      description: row['description'] as String?,
      targetIndex: (row['target_index'] as num).toInt(),
      aspectRatio: _toDouble(row['aspect_ratio'], fallback: 1),
      videoUrl: resolveVideoUrl(row['video_path'] as String),
      videoMode: (row['video_mode'] as String?) ?? 'fullframe',
      chromaColor: row['chroma_color'] as String?,
      planeWidth: _toNullableDouble(row['plane_width']),
      planeHeight: _toNullableDouble(row['plane_height']),
      offsetX: _toDouble(row['offset_x']),
      offsetY: _toDouble(row['offset_y']),
    );
  }

  /// Shape consumed by `ARApp.init` in assets/web/app.js.
  Map<String, dynamic> toManifestEntry() => {
        'targetIndex': targetIndex,
        'slug': slug,
        'title': title,
        'artist': artist,
        'year': year,
        'description': description,
        'videoUrl': videoUrl,
        'videoMode': videoMode,
        'aspectRatio': aspectRatio,
        'chromaColor': chromaColor,
        'planeWidth': planeWidth,
        'planeHeight': planeHeight,
        'offsetX': offsetX,
        'offsetY': offsetY,
      };
}

/// Everything the AR page needs: the tracking bundle plus its artworks.
class ArManifest {
  const ArManifest({required this.mindUrl, required this.artworks});

  final String mindUrl;
  final List<Artwork> artworks;

  Map<String, dynamic> toJson() => {
        'mindUrl': mindUrl,
        'artworks': artworks.map((a) => a.toManifestEntry()).toList(),
      };
}
