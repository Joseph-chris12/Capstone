import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../data/artwork.dart';

/// Typed view of the events assets/web/app.js sends across the bridge.
class ArCallbacks {
  const ArCallbacks({
    required this.onReady,
    required this.onSceneReady,
    required this.onArReady,
    required this.onArError,
    required this.onTargetFound,
    required this.onTargetLost,
    required this.onPlaybackBlocked,
    required this.onVideoError,
    required this.onError,
  });

  /// The page parsed and `window.ARApp` exists. Send the manifest now.
  final void Function() onReady;

  /// The A-Frame scene is built; tracking can be started.
  final void Function(int targetCount) onSceneReady;

  /// Camera is open and the tracking engine is running.
  final void Function(int targetCount) onArReady;

  final void Function(String message) onArError;
  final void Function(ArTargetEvent event) onTargetFound;
  final void Function(int targetIndex) onTargetLost;

  /// Autoplay refused — needs a real user gesture to start.
  final void Function(int targetIndex) onPlaybackBlocked;

  final void Function(int targetIndex, String message) onVideoError;
  final void Function(String stage, String message) onError;
}

/// A recognised artwork, as reported by the tracking engine.
class ArTargetEvent {
  const ArTargetEvent({
    required this.targetIndex,
    required this.slug,
    required this.title,
    this.artist,
    this.year,
    this.description,
  });

  final int targetIndex;
  final String slug;
  final String title;
  final String? artist;
  final String? year;
  final String? description;

  factory ArTargetEvent.fromJson(Map<String, dynamic> j) => ArTargetEvent(
    targetIndex: (j['targetIndex'] as num).toInt(),
    slug: j['slug'] as String? ?? '',
    title: j['title'] as String? ?? '',
    artist: j['artist'] as String?,
    year: j['year'] as String?,
    description: j['description'] as String?,
  );
}

/// Routes one event from assets/web/app.js to the matching callback.
///
/// Shared by both transports: the InAppWebView JavaScript handlers on mobile
/// and the iframe postMessage listener on web.
void dispatchArEvent(ArCallbacks cb, String name, Map<String, dynamic> j) {
  switch (name) {
    case 'onReady':
      cb.onReady();
    case 'onSceneReady':
      cb.onSceneReady((j['targetCount'] as num?)?.toInt() ?? 0);
    case 'onArReady':
      cb.onArReady((j['targetCount'] as num?)?.toInt() ?? 0);
    case 'onArError':
      cb.onArError(j['message'] as String? ?? 'AR error');
    case 'onTargetFound':
      cb.onTargetFound(ArTargetEvent.fromJson(j));
    case 'onTargetLost':
      cb.onTargetLost((j['targetIndex'] as num?)?.toInt() ?? -1);
    case 'onPlaybackBlocked':
      cb.onPlaybackBlocked((j['targetIndex'] as num?)?.toInt() ?? -1);
    case 'onVideoError':
      cb.onVideoError(
        (j['targetIndex'] as num?)?.toInt() ?? -1,
        j['message'] as String? ?? 'video error',
      );
    case 'onError':
      cb.onError(
        j['stage'] as String? ?? 'unknown',
        j['message'] as String? ?? 'error',
      );
  }
}

/// Every event name app.js sends.
const arEventNames = [
  'onReady',
  'onSceneReady',
  'onArReady',
  'onArError',
  'onTargetFound',
  'onTargetLost',
  'onPlaybackBlocked',
  'onVideoError',
  'onError',
];

/// Drives the AR page so the rest of the app never touches JavaScript strings.
///
/// [_evaluate] runs a script inside the page: the WebView controller on
/// mobile, the iframe's window on web.
class ArBridge {
  ArBridge(this._evaluate);

  ArBridge.inAppWebView(InAppWebViewController controller)
    : this((source) => controller.evaluateJavascript(source: source));

  final Future<void> Function(String source) _evaluate;

  /// Must be called in onWebViewCreated, before the page loads, or the early
  /// `onReady` event fires into nothing and the app waits forever.
  static void register(InAppWebViewController controller, ArCallbacks cb) {
    for (final name in arEventNames) {
      controller.addJavaScriptHandler(
        handlerName: name,
        callback: (args) => dispatchArEvent(
          cb,
          name,
          args.isEmpty
              ? const {}
              : Map<String, dynamic>.from(args.first as Map),
        ),
      );
    }
  }

  /// The manifest is JSON-encoded, so it is a valid JavaScript literal and
  /// needs no escaping beyond what jsonEncode already does.
  Future<void> init(ArManifest manifest) =>
      _evaluate('window.ARApp.init(${jsonEncode(manifest.toJson())})');

  Future<void> start() => _evaluate('window.ARApp.start()');
  Future<void> stop() => _evaluate('window.ARApp.stop()');
  Future<void> pause() => _evaluate('window.ARApp.pause()');
  Future<void> resume() => _evaluate('window.ARApp.resume()');
  Future<void> resumePlayback() => _evaluate('window.ARApp.resumePlayback()');
  Future<void> setMuted(bool muted) =>
      _evaluate('window.ARApp.setMuted($muted)');
}
