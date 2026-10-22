import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../ui/components.dart';
import 'feedback_model.dart';
import 'feedback_service.dart';

/// Sends a finished draft. Injected so tests can run without Supabase.
typedef FeedbackSubmitter = Future<void> Function(
  FeedbackDraft draft,
  Uint8List? attachment,
  String? attachmentExtension,
);

/// Figma "Feedback": category, rating, details, optional photo and email.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.submitter, this.appVersion});

  final FeedbackSubmitter? submitter;

  /// Shown in the version pill; read from the app package when null.
  final String? appVersion;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  final _email = TextEditingController();

  FeedbackDraft _draft = const FeedbackDraft();
  Uint8List? _attachment;
  String? _attachmentExt;
  bool _sending = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _version = widget.appVersion ?? '';
    if (widget.appVersion == null) {
      PackageInfo.fromPlatform()
          .then((info) {
            if (mounted) setState(() => _version = info.version);
          })
          .catchError((_) {});
    }
    _message.addListener(() {
      setState(() => _draft = _draft.copyWith(message: _message.text));
    });
    _email.addListener(() {
      setState(() => _draft = _draft.copyWith(email: _email.text));
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  void _clear() {
    _message.clear();
    _email.clear();
    setState(() {
      _draft = const FeedbackDraft();
      _attachment = null;
      _attachmentExt = null;
    });
  }

  void _insertPreset() {
    if (_message.text.contains('What I scanned:')) return;
    final text = _message.text.isEmpty
        ? FeedbackDraft.presetPrompt
        : '${_message.text}\n${FeedbackDraft.presetPrompt}';
    _message.value = TextEditingValue(
      text: text.substring(
        0,
        text.length.clamp(0, FeedbackDraft.maxMessageLength),
      ),
      selection: TextSelection.collapsed(
        offset: text.length.clamp(0, FeedbackDraft.maxMessageLength),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > FeedbackDraft.maxAttachmentBytes) {
        _snack('That image is over 15MB. Please pick a smaller one.');
        return;
      }
      final name = file.name;
      final dot = name.lastIndexOf('.');
      setState(() {
        _attachment = bytes;
        _attachmentExt = dot == -1 ? 'jpg' : name.substring(dot + 1);
        _draft = _draft.copyWith(attachmentName: name);
      });
    } catch (_) {
      _snack('Could not open your photos.');
    }
  }

  void _removePhoto() {
    setState(() {
      _attachment = null;
      _attachmentExt = null;
      _draft = _draft.copyWith(clearAttachment: true);
    });
  }

  Future<void> _submit() async {
    if (!_draft.canSubmit || _sending) return;
    setState(() => _sending = true);
    try {
      final submit =
          widget.submitter ??
          (draft, bytes, ext) =>
              FeedbackService(Supabase.instance.client).submit(
                draft: draft,
                appVersion: _version,
                attachmentBytes: bytes,
                attachmentExtension: ext,
              );
      await submit(_draft, _attachment, _attachmentExt);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! Your feedback was sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(
        e is FeedbackException
            ? e.message
            : 'Could not send your feedback. Please try again.',
      );
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              version: _version,
              onBack: () => Navigator.of(context).maybePop(),
              onClear: _clear,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 24),
                  _label(
                    'Feedback Category',
                    required: true,
                    trailing: 'Select one',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in FeedbackCategory.values)
                        PillChip(
                          label: c.label,
                          icon: c.icon,
                          selected: _draft.category == c,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(category: c),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _RatingCard(
                    rating: _draft.rating,
                    onChanged: (r) =>
                        setState(() => _draft = _draft.copyWith(rating: r)),
                  ),
                  const SizedBox(height: 24),
                  _label(
                    'Your Experience Details',
                    trailing:
                        '${_message.text.length} / ${FeedbackDraft.maxMessageLength}',
                  ),
                  const SizedBox(height: 8),
                  _DetailsBox(
                    controller: _message,
                    onInsertPreset: _insertPreset,
                  ),
                  const SizedBox(height: 24),
                  _label('Attachments'),
                  const SizedBox(height: 8),
                  _AttachmentCard(
                    name: _draft.attachmentName,
                    preview: _attachment,
                    onPick: _pickPhoto,
                    onRemove: _removePhoto,
                  ),
                  const SizedBox(height: 24),
                  _EmailField(controller: _email, valid: _draft.emailValid),
                  const SizedBox(height: 16),
                  PillButton(
                    key: const Key('submit-feedback'),
                    label: _sending ? 'Sending…' : 'Submit Feedback',
                    trailingIcon: _sending ? null : Icons.send_outlined,
                    onPressed: _draft.canSubmit && !_sending ? _submit : null,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                  PillButton(
                    label: 'Cancel',
                    variant: PillVariant.secondary,
                    onPressed: () => Navigator.of(context).maybePop(),
                    expand: true,
                    height: 44,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false, String? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              children: [
                if (required)
                  TextSpan(
                    text: '  *',
                    style: AppText.bodyLg.copyWith(color: AppColors.error),
                  ),
              ],
            ),
            style: AppText.bodyLg,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing,
            style: AppText.bodyLg.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.version,
    required this.onBack,
    required this.onClear,
  });

  final String version;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.bodyLg.copyWith(color: AppColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 14,
              color: AppColors.inkMuted,
            ),
            label: Text('Back', style: muted),
            style: TextButton.styleFrom(shape: const StadiumBorder()),
          ),
          const Spacer(),
          if (version.isNotEmpty)
            Flexible(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.5),
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.mocha,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'v$version',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyLg.copyWith(
                          color: const Color(0xFF7A5338),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(shape: const StadiumBorder()),
            child: Text(
              'Clear',
              style: AppText.bodyLg.copyWith(color: AppColors.mocha),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.peach,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 24,
              color: AppColors.mocha,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help Shape the Future of ARise',
                  style: AppText.bodyLg,
                ),
                const SizedBox(height: 4),
                Text(
                  'Found a bug while scanning, have an idea, or loved an '
                  'artwork? Your notes shape the next version.',
                  style: AppText.bodyLg.copyWith(
                    color: AppColors.inkMuted,
                    height: 26 / 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating, required this.onChanged});

  final int? rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'How is your scanning experience so far?',
            textAlign: TextAlign.center,
            style: AppText.bodyLg,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < ratingIcons.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                    child: Semantics(
                      label: ratingLabels[i],
                      selected: rating == i + 1,
                      button: true,
                      child: Material(
                        color: rating == i + 1
                            ? AppColors.peach
                            : AppColors.recessed,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onChanged(i + 1),
                          child: SizedBox(
                            height: 42,
                            child: Icon(
                              ratingIcons[i],
                              size: rating == i + 1 ? 24 : 22,
                              color: rating == i + 1
                                  ? AppColors.mocha
                                  : AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsBox extends StatelessWidget {
  const _DetailsBox({required this.controller, required this.onInsertPreset});

  final TextEditingController controller;
  final VoidCallback onInsertPreset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            maxLength: FeedbackDraft.maxMessageLength,
            style: AppText.bodyLg,
            decoration: InputDecoration.collapsed(
              hintText:
                  'Tell us what you scanned, what worked well, or '
                  'where the tracking drifted (e.g. lighting, glossy print, '
                  'distance)…',
              hintStyle: AppText.bodyLg.copyWith(
                color: AppColors.inkMuted.withValues(alpha: 0.5),
              ),
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: AppColors.inkMuted.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Detail helps us improve tracking',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.inkMuted.withValues(alpha: 0.75),
                  ),
                ),
              ),
              TextButton(
                onPressed: onInsertPreset,
                style: TextButton.styleFrom(shape: const StadiumBorder()),
                child: Text(
                  '+ Insert prompt',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.mocha,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.name,
    required this.preview,
    required this.onPick,
    required this.onRemove,
  });

  final String? name;
  final Uint8List? preview;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = preview != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.card,
        onTap: onPick,
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1EDE6),
                  shape: BoxShape.circle,
                ),
                child: picked
                    ? Image.memory(preview!, fit: BoxFit.cover)
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        size: 20,
                        color: AppColors.inkMuted,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      picked
                          ? name ?? 'Photo attached'
                          : 'Attach photo of print or screenshot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      picked ? 'Tap to change' : 'JPG, PNG, or HEIC up to 15MB',
                      style: AppText.bodyLg.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              if (picked)
                IconButton(
                  tooltip: 'Remove photo',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: AppColors.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.valid});

  final TextEditingController controller;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Email Address ',
            style: AppText.bodyLg,
            children: [
              TextSpan(
                text: '(Optional)',
                style: AppText.bodyLg.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.pill,
            border: Border.all(
              color: valid ? AppColors.keyline : AppColors.error,
              width: valid ? 1 : 1.5,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.alternate_email,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: AppText.bodyLg,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'you@domain.com for follow-up questions',
                    hintStyle: AppText.bodyLg.copyWith(
                      color: AppColors.inkMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                valid ? Icons.shield_outlined : Icons.error_outline,
                size: 13,
                color: valid ? AppColors.inkMuted : AppColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  valid
                      ? 'Only used to follow up on this feedback. No marketing '
                            'emails, ever.'
                      : 'That email address does not look right.',
                  style: AppText.bodySm.copyWith(
                    color: valid ? AppColors.inkMuted : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
