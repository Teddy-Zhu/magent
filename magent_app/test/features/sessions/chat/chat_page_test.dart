import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/features/sessions/chat/chat_page.dart';

void main() {
  test('completed item snapshot does not end an active running turn', () {
    expect(
      chatTurnActiveFromItemSnapshot(
        currentTurnActive: true,
        snapshotHasActiveItem: false,
        queuedInputCount: 1,
        sessionStatus: 'running',
      ),
      isTrue,
    );
  });

  test(
    'completed item snapshot clears active running turn when nothing queued',
    () {
      expect(
        chatTurnActiveFromItemSnapshot(
          currentTurnActive: true,
          snapshotHasActiveItem: false,
          queuedInputCount: 0,
          sessionStatus: 'running',
        ),
        isFalse,
      );
    },
  );

  test('active item snapshot can mark turn active', () {
    expect(
      chatTurnActiveFromItemSnapshot(
        currentTurnActive: false,
        snapshotHasActiveItem: true,
        queuedInputCount: 0,
        sessionStatus: 'running',
      ),
      isTrue,
    );
  });

  test('terminal session status clears active turn from item snapshot', () {
    expect(
      chatTurnActiveFromItemSnapshot(
        currentTurnActive: true,
        snapshotHasActiveItem: false,
        queuedInputCount: 0,
        sessionStatus: 'completed',
      ),
      isFalse,
    );
  });

  test('token usage event data is parsed for compact header', () {
    final usage = chatTokenUsageFromEventData({
      'tokenUsage': {
        'total': {
          'totalTokens': 13266897,
          'inputTokens': 13149613,
          'cachedInputTokens': 11274496,
          'outputTokens': 117284,
        },
        'last': {
          'totalTokens': 127573,
          'inputTokens': 127509,
          'cachedInputTokens': 126848,
          'outputTokens': 64,
        },
        'modelContextWindow': 258400,
      },
    });

    expect(usage, isNotNull);
    expect(usage!.totalTokens, 13266897);
    expect(usage.inputTokens, 13149613);
    expect(usage.outputTokens, 117284);
    expect(usage.cachedInputTokens, 11274496);
    expect(usage.lastTotalTokens, 127573);
    expect(usage.lastInputTokens, 127509);
    expect(usage.lastOutputTokens, 64);
    expect(usage.lastCachedInputTokens, 126848);
    expect(usage.contextTokens, 127509);
    expect(usage.contextWindow, 258400);
    expect(usage.contextRatio, closeTo(0.4934, 0.0001));
  });

  test('token usage event data supports legacy top-level context window', () {
    final usage = chatTokenUsageFromEventData({
      'tokenUsage': {
        'total': {'totalTokens': 1000},
        'last': {'totalTokens': 100, 'inputTokens': 80},
      },
      'modelContextWindow': 200,
    });

    expect(usage, isNotNull);
    expect(usage!.contextTokens, 80);
    expect(usage.contextWindow, 200);
    expect(usage.contextRatio, 0.4);
  });

  test('token numbers are compacted', () {
    expect(chatCompactTokenNumber(999), '999');
    expect(chatCompactTokenNumber(127573), '127.6K');
    expect(chatCompactTokenNumber(13266897), '13.3M');
  });

  test('unified diff is summarized by file', () {
    final files = chatDiffFileSummaries('''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1 +1,2 @@
-old
+new
+extra
diff --git a/lib/b.dart b/lib/b.dart
--- a/lib/b.dart
+++ b/lib/b.dart
@@ -1 +1 @@
-gone
+back
''');

    expect(files, hasLength(2));
    expect(files.first.path, 'lib/a.dart');
    expect(files.first.additions, 2);
    expect(files.first.deletions, 1);
    expect(files.last.path, 'lib/b.dart');
    expect(files.last.additions, 1);
    expect(files.last.deletions, 1);
  });

  test('yaml file unified diff uses diff detail language', () {
    final language = chatDetailLanguage('config/app.yaml', '''
--- a/config/app.yaml
+++ b/config/app.yaml
@@ -1,2 +1,2 @@
-enabled: false
+enabled: true
''');

    expect(language, 'diff');
  });

  test('plain yaml content still uses yaml detail language', () {
    final language = chatDetailLanguage('config/app.yaml', '''
enabled: true
name: demo
''');

    expect(language, 'yaml');
  });

  test('web search item is summarized as readable text', () {
    final data = {
      'type': 'web_search',
      'query': 'Flutter ListView jump to bottom',
      'results': [
        {
          'title': 'ScrollController class',
          'url':
              'https://api.flutter.dev/flutter/widgets/ScrollController-class.html',
          'snippet': 'Controls a scrollable widget.',
        },
      ],
    };

    expect(
      chatWebSearchTitle(data),
      'Web search: Flutter ListView jump to bottom',
    );
    expect(chatWebSearchListSummary(data), isEmpty);
    expect(chatWebSearchSummary(data), '1 result');
    final detail = chatWebSearchDetail(data);
    expect(detail, contains('Query: Flutter ListView jump to bottom'));
    expect(detail, contains('ScrollController class'));
    expect(detail, contains('https://api.flutter.dev'));
  });
}
