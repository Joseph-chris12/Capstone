import 'package:flutter/material.dart';

import 'core/onboarding.dart';
import 'data/artwork.dart';
import 'features/ar/ar_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/feedback/feedback_screen.dart';
import 'features/tutorial/tutorial_screen.dart';
import 'ui/chrome.dart';

/// Builds the Scan tab. [active] is false while another tab is showing, so the
/// camera can pause; [onArtworks] reports the published gallery once loaded.
typedef ScanTabBuilder = Widget Function(
  bool active,
  ValueChanged<List<Artwork>> onArtworks,
);

/// Header + Scan/Tutorial tabs + floating tab bar (Figma "Home" and
/// "Tutorial & Onboarding"). Feedback opens as its own page.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onboarding,
    this.scanBuilder,
  });

  final OnboardingStore onboarding;

  /// Overridable in tests, which cannot host the camera WebView.
  final ScanTabBuilder? scanBuilder;

  static const scanTab = 0;
  static const tutorialTab = 1;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index =
      widget.onboarding.tutorialSeen ? AppShell.scanTab : AppShell.tutorialTab;
  List<Artwork> _artworks = const [];

  static const _destinations = [
    NavDestination('Scan', Icons.view_in_ar_outlined),
    NavDestination('Tutorial', Icons.lightbulb_outline),
  ];

  void _select(int index) {
    if (index == _index) return;
    // Leaving the tutorial by any route counts as having seen it.
    if (_index == AppShell.tutorialTab) widget.onboarding.markTutorialSeen();
    setState(() => _index = index);
  }

  void _openFeedback() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
    );
  }

  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(artworks: _artworks),
      ),
    );
  }

  void _onArtworks(List<Artwork> artworks) {
    if (!mounted) return;
    setState(() => _artworks = artworks);
  }

  @override
  Widget build(BuildContext context) {
    final scanActive = _index == AppShell.scanTab;
    final scan = widget.scanBuilder?.call(scanActive, _onArtworks) ??
        ArScreen(active: scanActive, onArtworksLoaded: _onArtworks);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: [
                scan,
                TutorialScreen(
                  onStartScanning: () => _select(AppShell.scanTab),
                  onOpenSamples: _openCatalog,
                  onOpenFeedback: _openFeedback,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppHeader(onFeedback: _openFeedback),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: AppBottomNav(
                destinations: _destinations,
                selectedIndex: _index,
                onSelected: _select,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
