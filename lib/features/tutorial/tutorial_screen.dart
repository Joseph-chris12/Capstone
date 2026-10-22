import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/chrome.dart';
import '../../ui/components.dart';

/// "How ARise Works" (Figma "Tutorial & Onboarding"). The copy describes what
/// the app actually does: image tracking, a video overlay with optional sound,
/// and the artwork's details.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({
    super.key,
    required this.onStartScanning,
    required this.onOpenSamples,
    required this.onOpenFeedback,
  });

  final VoidCallback onStartScanning;
  final VoidCallback onOpenSamples;
  final VoidCallback onOpenFeedback;

  @override
  Widget build(BuildContext context) {
    final insets = Chrome.contentInsets(context);
    return ColoredBox(
      color: AppColors.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          insets.top + 16,
          20,
          insets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideBanner(onOpenFeedback: onOpenFeedback),
            const SizedBox(height: 24),
            const AppBadge(
              label: 'Augmented Reality 101',
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn Static Prints into Living Artworks',
              style: AppText.displayMobile,
            ),
            const SizedBox(height: 4),
            Text(
              'Point your camera at a printed artwork in the gallery. ARise '
              'recognises it and plays its animation right on the paper.',
              style: AppText.body.copyWith(height: 22.75 / 14),
            ),
            const SizedBox(height: 24),
            const _LivePreviewCard(),
            const SizedBox(height: 32),
            const SectionHeading(
              eyebrow: 'Step-by-step experience',
              title: 'Mastering the Magic',
            ),
            const SizedBox(height: 16),
            const _StepCard(
              number: 1,
              title: 'Point & Frame',
              subtitle: 'Alignment & Viewfinder',
              icon: Icons.crop_free,
              body:
                  'Aim your camera squarely at a poster or print. Keep it '
                  'steady inside the white corner guides.',
              footer: _StepImage(
                asset: 'assets/images/tutorial/step1_point_frame.jpg',
                caption: 'Best distance: 30cm – 1m',
                captionIcon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(height: 16),
            const _StepCard(
              number: 2,
              title: 'Instant Recognition',
              subtitle: 'Image Tracking',
              icon: Icons.center_focus_strong_outlined,
              body:
                  'ARise recognises the artwork from its printed details in a '
                  'few seconds and pins the animation to it, so it stays on '
                  'the print as you move.',
              footer: _InfoRow(
                icon: Icons.my_location,
                label: 'Spatial Anchor',
                chip: 'Runs on your phone',
              ),
            ),
            const SizedBox(height: 16),
            const _StepCard(
              number: 3,
              title: 'Watch It Come Alive!',
              subtitle: 'Video & Sound',
              icon: Icons.graphic_eq,
              body:
                  'The artwork starts to move on the paper and loops while you '
                  'look. Tap the speaker for sound; move away and the clip '
                  'closes.',
              footer: _StepImage(
                asset: 'assets/images/tutorial/step3_come_alive.jpg',
                caption: 'Sound starts muted, tap to unmute',
                captionIcon: Icons.volume_up_outlined,
              ),
            ),
            const SizedBox(height: 16),
            const _StepCard(
              number: 4,
              title: 'Discover the Story',
              subtitle: 'Details & Artists',
              icon: Icons.info_outline,
              body:
                  'The title, artist and story slide up while you look. Every '
                  'artwork you find is listed under Scanned.',
              footer: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MiniTile(
                      icon: Icons.article_outlined,
                      title: 'Artwork Details',
                      body: 'Title, artist & story',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _MiniTile(
                      icon: Icons.history,
                      title: 'Scan History',
                      body: 'Everything you found',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const SectionHeading(
              eyebrow: 'Pro scanning tips',
              title: 'Get Flawless Results',
            ),
            const SizedBox(height: 16),
            const _TipCard(
              icon: Icons.wb_sunny_outlined,
              title: 'Even, Soft Lighting',
              body:
                  'Daylight or bright room light gives the steadiest tracking. '
                  'Avoid glare and harsh flash that wash out the print.',
            ),
            const SizedBox(height: 8),
            const _TipCard(
              icon: Icons.straighten,
              title: 'Ideal Distance: 30cm – 1m',
              body:
                  'Let the print fill most of the corner guides. Too close or '
                  'too far and tracking may drop.',
            ),
            const SizedBox(height: 8),
            const _TipCard(
              icon: Icons.menu_book_outlined,
              title: 'Matte & High-Contrast Prints',
              body:
                  'Detailed, contrasty artwork tracks best. Glossy or glass-'
                  'covered prints may need a slight angle to avoid reflections.',
            ),
            const SizedBox(height: 32),
            _CtaCard(
              onStartScanning: onStartScanning,
              onOpenSamples: onOpenSamples,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideBanner extends StatelessWidget {
  const _GuideBanner({required this.onOpenFeedback});

  final VoidCallback onOpenFeedback;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.recessedDeep,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.keyline),
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: Image.asset(
                'assets/images/arise_logo.png',
                width: 24,
                height: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TUTORIAL GUIDE', style: AppText.eyebrow),
                Text(
                  'How ARise Works',
                  style: AppText.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFFBF8F2),
            shape: const StadiumBorder(
              side: BorderSide(color: Color(0x26210F04)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpenFeedback,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 14,
                      color: AppColors.espresso,
                    ),
                    SizedBox(width: 4),
                    Text('Feedback', style: AppText.label),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Before/after card: drag the handle to wipe between the flat print and the
/// living version.
class _LivePreviewCard extends StatefulWidget {
  const _LivePreviewCard();

  @override
  State<_LivePreviewCard> createState() => _LivePreviewCardState();
}

class _LivePreviewCardState extends State<_LivePreviewCard> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.layers_outlined, size: 16, color: AppColors.espresso),
              SizedBox(width: 4),
              Expanded(child: Text('Live AR Preview', style: AppText.title)),
              _GreyPill(label: 'SLIDE TO REVEAL'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadii.panel,
            child: SizedBox(
              height: 256,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final x = (_split * w).clamp(0.0, w);
                  void drag(double dx) =>
                      setState(() => _split = (dx / w).clamp(0.05, 0.95));
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) => drag(d.localPosition.dx),
                    onTapDown: (d) => drag(d.localPosition.dx),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/tutorial/after_ar.jpg',
                          fit: BoxFit.cover,
                          semanticLabel: 'The print brought to life in AR',
                        ),
                        ClipRect(
                          clipper: _LeftClipper(x),
                          child: Image.asset(
                            'assets/images/tutorial/before_flat_print.jpg',
                            fit: BoxFit.cover,
                            semanticLabel: 'The flat printed artwork',
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: _ImageTag(label: 'Flat Print', dark: false),
                        ),
                        const Positioned(
                          right: 12,
                          top: 12,
                          child: _ImageTag(label: 'AR View', dark: true),
                        ),
                        Positioned(
                          left: x - 2,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 4, color: AppColors.espresso),
                        ),
                        Positioned(
                          left: x - 9,
                          top: 256 / 2 - 16,
                          child: Container(
                            width: 18,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.espresso,
                              borderRadius: AppRadii.pill,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.drag_indicator,
                              size: 12,
                              color: AppColors.canvas,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 13,
                color: AppColors.inkBody,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Physical 2D Paper',
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Moving Artwork',
                  textAlign: TextAlign.end,
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.view_in_ar_outlined,
                size: 14,
                color: AppColors.inkBody,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.width);
  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.width != width;
}

class _ImageTag extends StatelessWidget {
  const _ImageTag({required this.label, required this.dark});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.espresso.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dark) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDCC4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.labelSm.copyWith(
              color: dark ? AppColors.canvas : AppColors.espresso,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreyPill extends StatelessWidget {
  const _GreyPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.recessedDeep,
        borderRadius: AppRadii.pill,
        border: Border.all(color: const Color(0x0F210F04)),
      ),
      child: Text(
        label,
        style: AppText.labelSm.copyWith(color: AppColors.badgeInk),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    required this.footer,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final String body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.espresso,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: AppText.title.copyWith(color: AppColors.canvas),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.labelSm),
                  ],
                ),
              ),
              Icon(icon, size: 20, color: AppColors.espresso),
            ],
          ),
          const SizedBox(height: 16),
          Text(body, style: AppText.body),
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }
}

class _StepImage extends StatelessWidget {
  const _StepImage({
    required this.asset,
    required this.caption,
    required this.captionIcon,
  });

  final String asset;
  final String caption;
  final IconData captionIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.panel,
      child: SizedBox(
        height: 176,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xBF210F04), Color(0x00210F04)],
                  stops: [0, 0.5],
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  Icon(captionIcon, size: 13, color: AppColors.canvas),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      caption,
                      style: AppText.labelSm.copyWith(color: AppColors.canvas),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.chip});

  final IconData icon;
  final String label;
  final String chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.recessed,
        borderRadius: AppRadii.panel,
        border: Border.all(color: const Color(0x0F210F04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.espresso),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: AppText.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          AppBadge(label: chip),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.recessed,
        borderRadius: AppRadii.panel,
        border: Border.all(color: const Color(0x0F210F04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.espresso),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppText.label.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(body, style: AppText.bodySm.copyWith(height: 18 / 13)),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.recessedDeep,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.keyline),
            ),
            child: Icon(icon, size: 20, color: AppColors.espresso),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 1),
                Text(body, style: AppText.bodySm.copyWith(height: 21.13 / 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.onStartScanning, required this.onOpenSamples});

  final VoidCallback onStartScanning;
  final VoidCallback onOpenSamples;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_outlined, size: 17, color: AppColors.espresso),
              SizedBox(width: 4),
              Expanded(
                child: Text('Ready to Experiment?', style: AppText.title),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning your first artwork now, or browse the artworks in '
            'this gallery.',
            style: AppText.bodySm.copyWith(height: 18 / 13),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'Try First Scan Now',
            trailingIcon: Icons.arrow_forward,
            onPressed: onStartScanning,
            expand: true,
            textStyle: AppText.title,
          ),
          const SizedBox(height: 4),
          PillButton(
            label: 'Artworks in This Gallery',
            icon: Icons.collections_outlined,
            variant: PillVariant.secondary,
            onPressed: onOpenSamples,
            expand: true,
            height: 44,
            textStyle: AppText.labelLg,
          ),
        ],
      ),
    );
  }
}
