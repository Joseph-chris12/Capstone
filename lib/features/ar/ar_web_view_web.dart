import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'ar_bridge.dart';

/// Web counterpart of the InAppWebView: the same bundled ar.html, in an
/// iframe served from the app's own origin.
///
/// Same origin matters twice: Dart can call into the page through the
/// iframe's window, and the camera prompt belongs to the app's origin, which
/// is a secure context on https:// and on localhost.
Widget buildWebArView({
  required ArCallbacks callbacks,
  required void Function(ArBridge bridge) onCreated,
}) => _WebArView(callbacks: callbacks, onCreated: onCreated);

class _WebArView extends StatefulWidget {
  const _WebArView({required this.callbacks, required this.onCreated});

  final ArCallbacks callbacks;
  final void Function(ArBridge bridge) onCreated;

  @override
  State<_WebArView> createState() => _WebArViewState();
}

class _WebArViewState extends State<_WebArView> {
  static var _nextId = 0;

  late final String _viewType = 'ar-gallery-iframe-${_nextId++}';
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _onMessage;

  @override
  void initState() {
    super.initState();

    _iframe = web.HTMLIFrameElement()
      ..src = ui_web.assetManager.getAssetUrl('assets/web/ar.html')
      ..allow = 'camera; autoplay; fullscreen'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframe,
    );

    // app.js posts {arGallery: true, handler, payload} to its parent when it
    // is not inside the native WebView. Registered before the iframe loads so
    // the early onReady is not missed.
    _onMessage = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin) return;
      final data = event.data.dartify();
      if (data is! Map || data['arGallery'] != true) return;
      final payload = data['payload'];
      dispatchArEvent(
        widget.callbacks,
        data['handler'] as String? ?? '',
        payload is Map ? Map<String, dynamic>.from(payload) : const {},
      );
    }).toJS;
    web.window.addEventListener('message', _onMessage);

    widget.onCreated(
      ArBridge((source) async {
        final frame = _iframe.contentWindow;
        if (frame == null) return;
        (frame as JSObject).callMethod('eval'.toJS, source.toJS);
      }),
    );
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
