import 'package:ar_gallery/data/artwork.dart';
import 'package:ar_gallery/data/artwork_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({
  required String slug,
  required int targetIndex,
  String videoMode = 'fullframe',
  String? chromaColor,
  Object? aspectRatio = 0.75,
  Object? planeWidth,
  Object? planeHeight,
  Object? offsetX,
  Object? offsetY,
}) =>
    {
      'id': 'id-$slug',
      'slug': slug,
      'title': 'Title $slug',
      'artist': 'Artist',
      'year': '2026',
      'description': 'A description.',
      'target_index': targetIndex,
      'aspect_ratio': aspectRatio,
      'video_path': '$slug.mp4',
      'video_mode': videoMode,
      'chroma_color': chromaColor,
      'plane_width': planeWidth,
      'plane_height': planeHeight,
      'offset_x': offsetX,
      'offset_y': offsetY,
    };

String fakeUrl(String path) => 'https://example.test/videos/$path';

void main() {
  group('Artwork.fromRow', () {
    test('maps a fullframe row and resolves the video URL', () {
      final a = Artwork.fromRow(row(slug: 'moon', targetIndex: 0), fakeUrl);

      expect(a.slug, 'moon');
      expect(a.targetIndex, 0);
      expect(a.aspectRatio, 0.75);
      expect(a.videoUrl, 'https://example.test/videos/moon.mp4');
      expect(a.isCutout, isFalse);
      expect(a.planeWidth, isNull);
      expect(a.offsetX, 0);
    });

    test('maps a cutout row with its own plane geometry', () {
      final a = Artwork.fromRow(
        row(
          slug: 'diver',
          targetIndex: 3,
          videoMode: 'cutout',
          chromaColor: '0.1 0.9 0.2',
          planeWidth: 1.6,
          planeHeight: 2.0,
          offsetX: 0.1,
          offsetY: 0.35,
        ),
        fakeUrl,
      );

      expect(a.isCutout, isTrue);
      expect(a.chromaColor, '0.1 0.9 0.2');
      expect(a.planeWidth, 1.6);
      expect(a.planeHeight, 2.0);
      expect(a.offsetX, 0.1);
      expect(a.offsetY, 0.35);
    });

    // Postgres numeric arrives over the wire as a string, not a double.
    test('parses numeric columns delivered as strings', () {
      final a = Artwork.fromRow(
        row(slug: 's', targetIndex: 0, aspectRatio: '1.3333', offsetY: '0.5'),
        fakeUrl,
      );

      expect(a.aspectRatio, closeTo(1.3333, 1e-9));
      expect(a.offsetY, 0.5);
    });
  });

  group('manifest', () {
    test('entry carries everything app.js reads', () {
      final entry =
          Artwork.fromRow(row(slug: 'moon', targetIndex: 0), fakeUrl)
              .toManifestEntry();

      expect(
        entry.keys,
        containsAll(<String>[
          'targetIndex',
          'slug',
          'title',
          'videoUrl',
          'videoMode',
          'aspectRatio',
          'chromaColor',
          'planeWidth',
          'planeHeight',
          'offsetX',
          'offsetY',
        ]),
      );
    });
  });

  group('ArtworkRepository.validateOrdering', () {
    List<Artwork> artworks(List<int> indexes) => [
          for (var i = 0; i < indexes.length; i++)
            Artwork.fromRow(row(slug: 'a$i', targetIndex: indexes[i]), fakeUrl),
        ];

    test('accepts a contiguous run from zero', () {
      expect(() => ArtworkRepository.validateOrdering(artworks([0, 1, 2])),
          returnsNormally);
    });

    test('accepts an empty list', () {
      expect(() => ArtworkRepository.validateOrdering([]), returnsNormally);
    });

    test('rejects a gap, which would shift every later artwork', () {
      expect(
        () => ArtworkRepository.validateOrdering(artworks([0, 2, 3])),
        throwsA(isA<ArManifestException>()),
      );
    });

    test('rejects indexes that do not start at zero', () {
      expect(
        () => ArtworkRepository.validateOrdering(artworks([1, 2])),
        throwsA(isA<ArManifestException>()),
      );
    });

    test('rejects duplicates', () {
      expect(
        () => ArtworkRepository.validateOrdering(artworks([0, 0])),
        throwsA(isA<ArManifestException>()),
      );
    });

    test('names the offending artwork so the fix is obvious', () {
      expect(
        () => ArtworkRepository.validateOrdering(artworks([0, 5])),
        throwsA(
          isA<ArManifestException>().having(
            (e) => e.message,
            'message',
            allOf(contains('a1'), contains('compile-targets')),
          ),
        ),
      );
    });
  });
}
