import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes anonymous rows to `scan_events` so the gallery can see which
/// artworks get scanned.
///
/// Fire-and-forget: a failed insert is logged and dropped, never surfaced,
/// because analytics must not get in the way of the AR experience. Each
/// artwork is recorded at most once per app launch so a visitor holding the
/// phone steady (and tracking flickering found/lost) counts as one scan.
class ScanLogger {
  ScanLogger(this._client) : sessionId = _randomUuidV4();

  final SupabaseClient _client;

  /// Random per launch; not tied to the device or the person.
  final String sessionId;

  final _logged = <String>{};

  void targetFound(String artworkId) {
    if (!_logged.add(artworkId)) return;
    _insert(artworkId, 'target_found');
  }

  Future<void> _insert(String artworkId, String eventType) async {
    try {
      // No .select(): RLS lets the app insert but not read events back.
      await _client.from('scan_events').insert({
        'artwork_id': artworkId,
        'event_type': eventType,
        'session_id': sessionId,
        'platform': _platform,
      });
    } catch (e) {
      debugPrint('scan_events insert failed: $e');
    }
  }

  static String get _platform => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'other',
        };

  static String _randomUuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
