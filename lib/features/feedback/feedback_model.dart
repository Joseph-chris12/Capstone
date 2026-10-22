import 'package:flutter/material.dart';

/// Feedback categories from the Figma "Feedback" screen. [id] is the value
/// stored in the database.
enum FeedbackCategory {
  arTracking('ar_tracking', 'AR Tracking & Scan', Icons.center_focus_strong_outlined),
  featureRequest('feature_request', 'Feature Request', Icons.lightbulb_outline),
  visualsAudio('visuals_audio', 'Visuals & Audio', Icons.graphic_eq),
  bugReport('bug_report', 'Bug Report', Icons.bug_report_outlined),
  praise('praise', 'General Praise', Icons.favorite_border);

  const FeedbackCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

/// 1 (very unhappy) to 5 (love it), shown as faces.
const ratingIcons = <IconData>[
  Icons.sentiment_very_dissatisfied_outlined,
  Icons.sentiment_dissatisfied_outlined,
  Icons.sentiment_neutral_outlined,
  Icons.sentiment_satisfied_outlined,
  Icons.auto_awesome,
];

const ratingLabels = <String>[
  'Very poor',
  'Poor',
  'Okay',
  'Good',
  'Love it',
];

/// Everything typed into the form, plus the rules for when it can be sent.
@immutable
class FeedbackDraft {
  const FeedbackDraft({
    this.category,
    this.rating,
    this.message = '',
    this.email = '',
    this.attachmentName,
  });

  static const maxMessageLength = 500;
  static const maxAttachmentBytes = 15 * 1024 * 1024;
  static const presetPrompt =
      'What I scanned: \nWhat happened: \nLighting and distance: ';

  final FeedbackCategory? category;

  /// 1..5, or null when not chosen.
  final int? rating;
  final String message;
  final String email;
  final String? attachmentName;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get emailValid =>
      email.trim().isEmpty || _emailPattern.hasMatch(email.trim());

  /// A category, and something to act on (a rating or some text), and a
  /// well-formed email if one was given.
  bool get canSubmit =>
      category != null &&
      (rating != null || message.trim().isNotEmpty) &&
      message.length <= maxMessageLength &&
      emailValid;

  FeedbackDraft copyWith({
    FeedbackCategory? category,
    int? rating,
    String? message,
    String? email,
    String? attachmentName,
    bool clearAttachment = false,
  }) {
    return FeedbackDraft(
      category: category ?? this.category,
      rating: rating ?? this.rating,
      message: message ?? this.message,
      email: email ?? this.email,
      attachmentName:
          clearAttachment ? null : attachmentName ?? this.attachmentName,
    );
  }
}
