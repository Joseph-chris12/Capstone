import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../data/artwork.dart';
import '../../data/artwork_repository.dart';
import '../catalog/catalog_screen.dart';
import 'ar_bridge.dart';
import 'artwork_info_sheet.dart';
import 'scanning_overlay.dart';

/// What the visitor is currently blocked on, if anything.
enum ArStage {
  starting,
  needsPermission,
  permissionPermanentlyDenied,
  loadingManifest,
  manifestFailed,
  buildingScene,
  scanning,
  arFailed,
}

/// The app's home screen: opens straight into the camera, like Artivive.
class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with WidgetsBindingObserver {
  static final InAppLocalhostServer _server = InAppLocalhostServer(
    port: Config.localServerPort,
    documentRoot: 'assets/web',
  );

  ArBridge? _bridge;

  ArStage _stage = ArStage.starting;
  String _errorMessage = '';
  ArManifest? _manifest;
  ArTargetEvent? _current;
  bool _muted = true;
  bool _playbackBlocked = false;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bridge?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded; Android will not hand it to
    // another app otherwise, and returning to a frozen viewfinder looks broken.
    if (state == AppLifecycleState.resumed) {
      _bridge?.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bridge?.pause();
    }
  }

  Future<void> _bootstrap() async {
    if (!Config.isConfigured) {
      setState(() {
        _stage = ArStage.manifestFailed;
        _errorMessage = Config.configurationError;
      });
      return;
    }

    if (!_server.isRunning()) {
      await _server.start();
    }

    // Permission and manifest are independent; running them together means a
    // slow network does not delay the permission prompt.
    final results = await Future.wait([
      _ensureCameraPermission(),
      _loadManifest(),
    ]);

    if (!mounted) return;
    final granted = results[0] as bool;
    if (!granted) return; // _ensureCameraPermission set the stage
    if (_manifest == null) return; // _loadManifest set the stage

    setState(() => _stage = ArStage.buildingScene);
    _maybeInitScene();
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return false;

    if (status.isGranted) return true;

    setState(() {
      _stage = status.isPermanentlyDenied
          ? ArStage.permissionPermanentlyDenied
          : ArStage.needsPermission;
    });
    return false;
  }

  Future<void> _loadManifest() async {
    if (mounted && _stage == ArStage.starting) {
      setState(() => _stage = ArStage.loadingManifest);
    }
    try {
      final repo = ArtworkRepository(Supabase.instance.client);
      final manifest = await repo.fetchManifest();
      if (!mounted) return;
      _manifest = manifest;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = ArStage.manifestFailed;
        _errorMessage = e is ArManifestException
            ? e.message
            : 'Could not load the gallery.\n\n$e';
      });
    }
  }

  /// The scene needs both the page and the manifest, which arrive in either
  /// order, so whichever finishes last triggers the build.
  void _maybeInitScene() {
    final bridge = _bridge;
    final manifest = _manifest;
    if (!_pageReady || bridge == null || manifest == null) return;
    bridge.init(manifest);
  }

  ArCallbacks get _callbacks => ArCallbacks(
        onReady: () {
          _pageReady = true;
          _maybeInitScene();
        },
        onSceneReady: (_) => _bridge?.start(),
        onArReady: (_) {
          if (!mounted) return;
          setState(() => _stage = ArStage.scanning);
        },
        onArError: (message) {
          if (!mounted) return;
          setState(() {
            _stage = ArStage.arFailed;
            _errorMessage = message;
          });
        },
        onTargetFound: (event) {
          if (!mounted) return;
          setState(() {
            _current = event;
            _playbackBlocked = false;
          });
        },
        onTargetLost: (_) {
          if (!mounted) return;
          setState(() => _current = null);
        },
        onPlaybackBlocked: (_) {
          if (!mounted) return;
          setState(() => _playbackBlocked = true);
        },
        onVideoError: (index, message) {
          if (!mounted) return;
          _showSnack('This artwork\'s video could not load. $message');
        },
        onError: (stage, message) {
          if (!mounted) return;
          _showSnack('AR error ($stage): $message');
        },
      );

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _bridge?.setMuted(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _retryPlayback() async {
    await _bridge?.resumePlayback();
    if (!mounted) return;
    setState(() => _playbackBlocked = false);
  }

  Future<void> _retryAll() async {
    setState(() {
      _stage = ArStage.starting;
      _errorMessage = '';
      _manifest = null;
    });
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildWebView(),
          if (_stage != ArStage.scanning) _buildBlockingLayer(),
          if (_stage == ArStage.scanning) ...[
            ScanningOverlay(visible: _current == null),
            _buildTopBar(),
            if (_playbackBlocked)
              Center(
                child: FilledButton.icon(
                  onPressed: _retryPlayback,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Tap to play'),
                ),
              ),
            if (_current != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ArtworkInfoSheet(event: _current!),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebView() {
    // Built only once the manifest exists, so the camera does not open behind
    // an error screen the visitor is still reading.
    if (_manifest == null) return const SizedBox.shrink();

    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:${Config.localServerPort}/ar.html'),
      ),
      initialSettings: InAppWebViewSettings(
        // Without this the tracking video will not start on its own.
        mediaPlaybackRequiresUserGesture: false,
        // iOS: keep video in the page instead of the native fullscreen player.
        allowsInlineMediaPlayback: true,
        transparentBackground: true,
        supportZoom: false,
        disableVerticalScroll: true,
        disableHorizontalScroll: true,
        useHybridComposition: true,
      ),
      onWebViewCreated: (controller) {
        _bridge = ArBridge(controller);
        // Registered before the page loads, or the early onReady is missed.
        ArBridge.register(controller, _callbacks);
      },
      onPermissionRequest: (controller, request) async {
        // The OS-level prompt already happened; this is the WebView asking.
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },
      onConsoleMessage: (controller, message) {
        debugPrint('[webview] ${message.message}');
      },
      onReceivedError: (controller, request, error) {
        if (!mounted) return;
        setState(() {
          _stage = ArStage.arFailed;
          _errorMessage = 'Could not load the AR page: ${error.description}';
        });
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: _muted ? 'Unmute' : 'Mute',
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
              color: Colors.white,
              onPressed: _toggleMute,
            ),
            IconButton(
              tooltip: 'Browse the gallery',
              icon: const Icon(Icons.grid_view_rounded),
              color: Colors.white,
              onPressed: () {
                final artworks = _manifest?.artworks ?? const <Artwork>[];
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CatalogScreen(artworks: artworks),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockingLayer() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: switch (_stage) {
            ArStage.starting ||
            ArStage.loadingManifest ||
            ArStage.buildingScene =>
              const _Busy(label: 'Preparing the gallery…'),
            ArStage.needsPermission => _Message(
                icon: Icons.photo_camera_outlined,
                title: 'Camera access needed',
                body: 'This app looks at the artwork through your camera to '
                    'bring it to life. Nothing is recorded or uploaded.',
                actionLabel: 'Allow camera',
                onAction: _retryAll,
              ),
            ArStage.permissionPermanentlyDenied => _Message(
                icon: Icons.settings_outlined,
                title: 'Camera access is blocked',
                body: 'Camera permission was denied permanently. Enable it in '
                    'Settings, then come back.',
                actionLabel: 'Open settings',
                onAction: openAppSettings,
              ),
            ArStage.manifestFailed => _Message(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load the gallery',
                body: _errorMessage,
                actionLabel: 'Try again',
                onAction: _retryAll,
              ),
            ArStage.arFailed => _Message(
                icon: Icons.error_outline,
                title: 'AR could not start',
                body: _errorMessage,
                actionLabel: 'Try again',
                onAction: _retryAll,
              ),
            ArStage.scanning => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white70),
        const SizedBox(height: 20),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Colors.white70),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
