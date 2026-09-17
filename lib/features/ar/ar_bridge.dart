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

/// Wraps the WebView so the rest of the app never touches JavaScript strings.
class ArBridge {
  ArBridge(this._controller);

  final InAppWebViewController _controller;

  static Map<String, dynamic> _arg(List<dynamic> args) =>
      args.isEmpty ? const {} : Map<String, dynamic>.from(args.first as Map);

  /// Must be called in onWebViewCreated, before the page loads, or the early
  /// `onReady` event fires into nothing and the app waits forever.
  static void register(
    InAppWebViewController controller,
    ArCallbacks cb,
  ) {
    void on(String name, void Function(Map<String, dynamic>) handle) {
      controller.addJavaScriptHandler(
        handlerName: name,
        callback: (args) => handle(_arg(args)),
      );
    }

    on('onReady', (_) => cb.onReady());
    on('onSceneReady', (j) => cb.onSceneReady((j['targetCount'] as num?)?.toInt() ?? 0));
    on('onArReady', (j) => cb.onArReady((j['targetCount'] as num?)?.toInt() ?? 0));
    on('onArError', (j) => cb.onArError(j['message'] as String? ?? 'AR error'));
    on('onTargetFound', (j) => cb.onTargetFound(ArTargetEvent.fromJson(j)));
    on('onTargetLost', (j) => cb.onTargetLost((j['targetIndex'] as num?)?.toInt() ?? -1));
    on('onPlaybackBlocked',
        (j) => cb.onPlaybackBlocked((j['targetIndex'] as num?)?.toInt() ?? -1));
    on(
      'onVideoError',
      (j) => cb.onVideoError(
        (j['targetIndex'] as num?)?.toInt() ?? -1,
        j['message'] as String? ?? 'video error',
      ),
    );
    on(
      'onError',
      (j) => cb.onError(
        j['stage'] as String? ?? 'unknown',
        j['message'] as String? ?? 'error',
      ),
    );
  }

  /// The manifest is JSON-encoded, so it is a valid JavaScript literal and
  /// needs no escaping beyond what jsonEncode already does.
  Future<void> init(ArManifest manifest) =>
      _call('window.ARApp.init(${jsonEncode(manifest.toJson())})');

  Future<void> start() => _call('window.ARApp.start()');
  Future<void> stop() => _call('window.ARApp.stop()');
  Future<void> pause() => _call('window.ARApp.pause()');
  Future<void> resume() => _call('window.ARApp.resume()');
  Future<void> resumePlayback() => _call('window.ARApp.resumePlayback()');
  Future<void> setMuted(bool muted) => _call('window.ARApp.setMuted($muted)');

  Future<void> _call(String source) =>
      _controller.evaluateJavascript(source: source);
}
