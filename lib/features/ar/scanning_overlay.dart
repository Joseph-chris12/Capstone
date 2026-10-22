import 'package:flutter/material.dart';

/// White corner brackets marking where to hold the artwork (Figma "Optical
/// Target Reticle"), shown while nothing is recognised.
///
/// Fades rather than disappearing, so the hand-off to a playing artwork does
/// not flicker when tracking is briefly lost and regained.
class ScanningOverlay extends StatelessWidget {
  const ScanningOverlay({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const AspectRatio(
                aspectRatio: 320 / 288,
                child: Stack(
                  children: [
                    Positioned(left: 0, top: 0, child: _Corner(0)),
                    Positioned(right: 0, top: 0, child: _Corner(1)),
                    Positioned(right: 0, bottom: 0, child: _Corner(2)),
                    Positioned(left: 0, bottom: 0, child: _Corner(3)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One L-shaped bracket; [quarterTurns] rotates the top-left shape into place.
class _Corner extends StatelessWidget {
  const _Corner(this.quarterTurns);

  final int quarterTurns;

  static const _bar = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(9999)),
    boxShadow: [
      BoxShadow(color: Color(0x59000000), blurRadius: 2, offset: Offset(0, 2)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: SizedBox.square(
        dimension: 32,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(width: 32, height: 4, decoration: _bar),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Container(width: 4, height: 32, decoration: _bar),
            ),
          ],
        ),
      ),
    );
  }
}
