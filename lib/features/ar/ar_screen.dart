import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/artwork.dart';
import '../../data/artwork_repository.dart';
import '../../data/scan_logger.dart';
import '../../ui/chrome.dart';
import '../../ui/components.dart';
import '../catalog/catalog_screen.dart';
import 'ar_bridge.dart';
import 'ar_web_view.dart';
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

/// The Scan tab: the live camera with the tracking HUD (Figma "Home").
class ArScreen extends StatefulWidget {
  const ArScreen({super.key, this.active = true, this.onArtworksLoaded});

  /// False while another tab is showing: the camera pauses until it is back.
  final bool active;

  /// Reports the published gallery once loaded, for the artwork list.
  final ValueChanged<List<Artwork>>? onArtworksLoaded;

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with WidgetsBindingObserver {
  static final InAppLocalhostServer _server = InAppLocalhostServer(
    port: Config.localServerPort,
    documentRoot: 'assets/web',
  );

  ArBridge? _bridge;
  ScanLogger? _scanLogger;

  ArStage _stage = ArStage.starting;
  String _errorMessage = '';
  ArManifest? _manifest;
  ArTargetEvent? _current;
  bool _muted = true;
  bool _playbackBlocked = false;
  bool _pageReady = false;

  /// Artworks recognised this session, most recent last.
  final _scanned = <String>[];

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
  void didUpdateWidget(ArScreen old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    // Switching tabs releases the camera, like backgrounding the app.
    if (widget.active) {
      _bridge?.resume();
    } else {
      _bridge?.pause();
      if (_current != null) setState(() => _current = null);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded; Android will not hand it to
    // another app otherwise, and returning to a frozen viewfinder looks broken.
    if (state == AppLifecycleState.resumed) {
      if (!widget.active) return;
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

    // The web build serves ar.html itself; the localhost server is for the
    // mobile WebView only.
    if (!kIsWeb && !_server.isRunning()) {
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
    // In a browser the AR page's own getUserMedia call raises the prompt, and
    // a denial arrives as onArError.
    if (kIsWeb) return true;

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
      _scanLogger ??= ScanLogger(Supabase.instance.client);
      widget.onArtworksLoaded?.call(manifest.artworks);
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
          // The tutorial may be showing while the camera starts up.
          if (!widget.active) _bridge?.pause();
        },
        onArError: (message) {
          if (!mounted) return;
          setState(() {
            _stage = ArStage.arFailed;
            _errorMessage = message;
          });
        },
        onTargetFound: (event) {
          _logScan(event);
          if (!mounted) return;
          setState(() {
            _current = event;
            _playbackBlocked = false;
            _scanned
              ..remove(event.slug)
              ..add(event.slug);
          });
        },
        onTargetLost: (_) {
          if (!mounted) return;
          // The clip closed with its artwork, so its tap-to-play goes too.
          setState(() {
            _current = null;
            _playbackBlocked = false;
          });
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

  void _logScan(ArTargetEvent event) {
    final artworks = _manifest?.artworks ?? const <Artwork>[];
    for (final a in artworks) {
      if (a.slug == event.slug) {
        _scanLogger?.targetFound(a.id);
        return;
      }
    }
  }

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

  Artwork? _artworkFor(String slug) {
    for (final a in _manifest?.artworks ?? const <Artwork>[]) {
      if (a.slug == slug) return a;
    }
    return null;
  }

  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          artworks: _manifest?.artworks ?? const <Artwork>[],
          scannedSlugs: _scanned.toSet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = Chrome.contentInsets(context);
    final current = _current;
    return ColoredBox(
      // The camera feed paints over this once AR is running.
      color: AppColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildWebView(),
          if (_stage != ArStage.scanning) _buildBlockingLayer(insets),
          if (_stage == ArStage.scanning) ...[
            ScanningOverlay(visible: current == null),
            Positioned(
              top: insets.top + 8,
              left: 20,
              right: 20,
              child: _buildHud(),
            ),
            if (_playbackBlocked)
              Center(
                child: PillButton(
                  label: 'Tap to play',
                  icon: Icons.play_arrow,
                  onPressed: _retryPlayback,
                ),
              ),
            if (current != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: insets.bottom + 16,
                child: Center(
                  child: ArtworkInfoSheet(
                    event: current,
                    thumbnailUrl: _artworkFor(current.slug)?.thumbnailUrl,
                    muted: _muted,
                    onToggleMute: _toggleMute,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Status pill, then the mute button and the scanned-count pill.
  Widget _buildHud() {
    final current = _current;
    final last = _scanned.isEmpty ? null : _artworkFor(_scanned.last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          shadows: AppShadows.soft,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.mocha,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  current == null
                      ? 'Align physical image in frame'
                      : 'Now playing: ${current.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GlassIconButton(
              icon: _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
              tooltip: _muted ? 'Unmute' : 'Mute',
              onPressed: _toggleMute,
            ),
            const Spacer(),
            if (_scanned.isNotEmpty)
              _ScannedPill(
                count: _scanned.length,
                thumbnailUrl: last?.thumbnailUrl,
                onTap: _openCatalog,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebView() {
    // Built only once the manifest exists, so the camera does not open behind
    // an error screen the visitor is still reading.
    if (_manifest == null) return const SizedBox.shrink();

    if (kIsWeb) {
      return buildWebArView(
        callbacks: _callbacks,
        onCreated: (bridge) => _bridge = bridge,
      );
    }

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
        _bridge = ArBridge.inAppWebView(controller);
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

  Widget _buildBlockingLayer(EdgeInsets insets) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, insets.top, 20, insets.bottom),
        child: Center(
          child: switch (_stage) {
            ArStage.starting ||
            ArStage.loadingManifest ||
            ArStage.buildingScene =>
              const _Busy(label: 'Preparing the gallery…'),
            ArStage.needsPermission => _Message(
                icon: Icons.photo_camera_outlined,
                title: 'Camera access needed',
                body: 'ARise looks at the artwork through your camera to '
                    'bring it to life. Nothing is recorded or uploaded.',
                actionLabel: 'Allow camera',
                onAction: _retryAll,
              ),
            ArStage.permissionPermanentlyDenied => _Message(
                icon: Icons.settings_outlined,
                title: 'Camera access is blocked',
                body: 'Camera permission was turned off for ARise. Enable it '
                    'in Settings, then come back.',
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

/// "N Scanned" glass pill with the most recent artwork's thumbnail.
class _ScannedPill extends StatelessWidget {
  const _ScannedPill({
    required this.count,
    required this.thumbnailUrl,
    required this.onTap,
  });

  final int count;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 6,
      shadows: AppShadows.soft,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.recessed,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: thumbnailUrl == null
                      ? null
                      : Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count Scanned',
                  style: AppText.label.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
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
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(label, style: AppText.body),
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
    return SingleChildScrollView(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.peach,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: AppColors.mocha),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 20),
            PillButton(label: actionLabel, onPressed: onAction, expand: true),
          ],
        ),
      ),
    );
  }
}
