import 'dart:typed_data';

import 'package:ar_gallery/core/theme.dart';
import 'package:ar_gallery/features/feedback/feedback_model.dart';
import 'package:ar_gallery/features/feedback/feedback_screen.dart';
import 'package:ar_gallery/features/feedback/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackDraft.canSubmit', () {
    test('needs a category', () {
      expect(const FeedbackDraft(rating: 4).canSubmit, isFalse);
    });

    test('needs a rating or some text besides the category', () {
      const d = FeedbackDraft(category: FeedbackCategory.bugReport);
      expect(d.canSubmit, isFalse);
      expect(d.copyWith(rating: 2).canSubmit, isTrue);
      expect(d.copyWith(message: 'Video drifted').canSubmit, isTrue);
      expect(d.copyWith(message: '   ').canSubmit, isFalse);
    });

    test('rejects a malformed email but allows none', () {
      const d = FeedbackDraft(category: FeedbackCategory.praise, rating: 5);
      expect(d.copyWith(email: '').canSubmit, isTrue);
      expect(d.copyWith(email: 'me@example.com').canSubmit, isTrue);
      expect(d.copyWith(email: 'not-an-email').canSubmit, isFalse);
    });

    test('rejects text over the limit', () {
      final d = FeedbackDraft(
        category: FeedbackCategory.bugReport,
        message: 'x' * (FeedbackDraft.maxMessageLength + 1),
      );
      expect(d.canSubmit, isFalse);
    });
  });

  test('toRow trims text and stores the category id', () {
    final row = FeedbackService.toRow(
      const FeedbackDraft(
        category: FeedbackCategory.arTracking,
        rating: 3,
        message: '  drifts on glossy paper ',
        email: ' ',
      ),
      appVersion: '1.0.0',
    );
    expect(row['category'], 'ar_tracking');
    expect(row['rating'], 3);
    expect(row['message'], 'drifts on glossy paper');
    expect(row['email'], isNull);
    expect(row['app_version'], '1.0.0');
  });

  group('FeedbackScreen', () {
    Future<List<FeedbackDraft>> pump(WidgetTester tester) async {
      final sent = <FeedbackDraft>[];
      Future<void> submitter(FeedbackDraft d, Uint8List? b, String? e) async =>
          sent.add(d);
      tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FeedbackScreen(
                      appVersion: '1.0.0',
                      submitter: submitter,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return sent;
    }

    PillButtonFinder submit() => PillButtonFinder();

    testWidgets('submit is disabled until a category and rating are chosen',
        (tester) async {
      final sent = await pump(tester);
      expect(submit().enabled(tester), isFalse);

      await tester.tap(find.text('Bug Report'));
      await tester.pump();
      expect(submit().enabled(tester), isFalse);

      await tester.tap(find.bySemanticsLabel('Good'));
      await tester.pump();
      expect(submit().enabled(tester), isTrue);

      await tester.ensureVisible(find.byKey(const Key('submit-feedback')));
      await tester.tap(find.byKey(const Key('submit-feedback')));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.category, FeedbackCategory.bugReport);
      expect(sent.single.rating, 4);
      expect(find.text('Thank you! Your feedback was sent.'), findsOneWidget);
    });

    testWidgets('a malformed email blocks sending and says why',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('General Praise'));
      await tester.tap(find.bySemanticsLabel('Love it'));
      await tester.enterText(find.byType(TextField).last, 'nope');
      await tester.pump();
      expect(submit().enabled(tester), isFalse);
      expect(find.text('That email address does not look right.'),
          findsOneWidget);
    });

    testWidgets('counter tracks typed text and Clear resets the form',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'Hello');
      await tester.pump();
      expect(find.text('5 / 500'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.text('0 / 500'), findsOneWidget);
    });
  });
}

/// Reads whether the Submit pill currently has an onPressed handler.
class PillButtonFinder {
  bool enabled(WidgetTester tester) {
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('submit-feedback')),
        matching: find.byType(InkWell),
      ),
    );
    return inkWell.onTap != null;
  }
}
