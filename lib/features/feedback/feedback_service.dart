import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feedback_model.dart';

/// Thrown with a message that can be shown to the visitor as-is.
class FeedbackException implements Exception {
  FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sends a [FeedbackDraft] to Supabase: the optional photo to Storage, then
/// one row in the feedback table. The table, bucket and column names live
/// here only, so pointing at another schema is a change to this file.
class FeedbackService {
  FeedbackService(this._client);

  static const table = 'feedback';
  static const bucket = 'feedback-attachments';

  final SupabaseClient _client;

  Future<void> submit({
    required FeedbackDraft draft,
    required String appVersion,
    Uint8List? attachmentBytes,
    String? attachmentExtension,
  }) async {
    if (!draft.canSubmit) {
      throw FeedbackException('Please choose a category and add a rating or '
          'a few words.');
    }

    String? attachmentPath;
    try {
      if (attachmentBytes != null) {
        final ext = (attachmentExtension ?? 'jpg').toLowerCase();
        attachmentPath =
            '${DateTime.now().toUtc().millisecondsSinceEpoch}-'
            '${attachmentBytes.length}.$ext';
        await _client.storage.from(bucket).uploadBinary(
              attachmentPath,
              attachmentBytes,
              fileOptions: FileOptions(contentType: _mimeFor(ext)),
            );
      }

      // No .select(): the app may insert feedback but not read it back.
      await _client.from(table).insert(toRow(
            draft,
            appVersion: appVersion,
            attachmentPath: attachmentPath,
          ));
    } on PostgrestException catch (e) {
      debugPrint('feedback insert failed: ${e.code} ${e.message}');
      throw FeedbackException(e.code == '42P01' || e.code == 'PGRST205'
          ? 'Feedback is not set up on the server yet.'
          : 'Could not send your feedback. Please try again.');
    } on StorageException catch (e) {
      debugPrint('feedback upload failed: ${e.statusCode} ${e.message}');
      throw FeedbackException('Could not upload the photo. Try sending '
          'without it, or with a smaller image.');
    }
  }

  @visibleForTesting
  static Map<String, dynamic> toRow(
    FeedbackDraft draft, {
    required String appVersion,
    String? attachmentPath,
  }) {
    final email = draft.email.trim();
    final message = draft.message.trim();
    return {
      'category': draft.category!.id,
      'rating': draft.rating,
      'message': message.isEmpty ? null : message,
      'email': email.isEmpty ? null : email,
      'attachment_path': attachmentPath,
      'app_version': appVersion,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
  }

  static String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'heic' => 'image/heic',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
