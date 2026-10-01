// The browser build hosts the AR page in an <iframe>; everywhere else this
// stub is compiled in and never called (ArScreen checks kIsWeb first).
export 'ar_web_view_stub.dart'
    if (dart.library.js_interop) 'ar_web_view_web.dart';
