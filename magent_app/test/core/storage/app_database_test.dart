import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/core/storage/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('project and provider cache is isolated by agent id', () async {
    final now = DateTime(2026, 5, 1);
    await db.replaceProjects('agent-a', [
      ProjectEntriesCompanion(
        agentId: const Value('agent-a'),
        id: const Value('p1'),
        name: const Value('One'),
        path: const Value('/repo/one'),
        defaultProvider: const Value('codex'),
        dataJson: const Value('{"id":"p1"}'),
        updatedAt: Value(now),
      ),
    ]);
    await db.replaceProjects('agent-b', [
      ProjectEntriesCompanion(
        agentId: const Value('agent-b'),
        id: const Value('p2'),
        name: const Value('Two'),
        path: const Value('/repo/two'),
        defaultProvider: const Value('codex'),
        dataJson: const Value('{"id":"p2"}'),
        updatedAt: Value(now),
      ),
    ]);
    await db.replaceProviders('agent-a', [
      ProviderEntriesCompanion(
        agentId: const Value('agent-a'),
        name: const Value('codex'),
        status: const Value('available'),
        capabilitiesJson: const Value('{}'),
        configJson: const Value('{}'),
        configSchemaJson: const Value('{}'),
        dataJson: const Value('{"name":"codex"}'),
        updatedAt: Value(now),
      ),
    ]);

    final projectsA = await db.getProjects('agent-a');
    final projectsB = await db.getProjects('agent-b');
    final providersB = await db.getProviders('agent-b');

    expect(projectsA.map((p) => p.id), ['p1']);
    expect(projectsB.map((p) => p.id), ['p2']);
    expect(providersB, isEmpty);
  });

  test('display cache stats and clear only affect selected agent', () async {
    final now = DateTime(2026, 5, 1);
    await db.upsertGitSummary(
      GitSummaryEntriesCompanion(
        agentId: const Value('agent-a'),
        projectId: const Value('p1'),
        version: const Value(1),
        dataJson: const Value('{"version":1}'),
        updatedAt: Value(now),
      ),
    );
    await db.upsertGitChanges(
      GitChangesEntriesCompanion(
        agentId: const Value('agent-b'),
        projectId: const Value('p1'),
        version: const Value(1),
        filesJson: const Value('[{"path":"a"}]'),
        updatedAt: Value(now),
      ),
    );
    await db.insertOrUpdateItem(
      SessionItemEntriesCompanion(
        agentId: const Value('agent-a'),
        sessionId: const Value('s1'),
        itemId: const Value('i1'),
        type: const Value('agent_message'),
        content: const Value('{"text":"hello"}'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    expect((await db.getGitCacheStats('agent-a')).entries, 1);
    expect((await db.getGitCacheStats('agent-b')).entries, 1);
    expect((await db.getSessionCacheStats('agent-a')).entries, 1);

    await db.clearAllDisplayCaches('agent-a');

    expect((await db.getGitCacheStats('agent-a')).entries, 0);
    expect((await db.getSessionCacheStats('agent-a')).entries, 0);
    expect((await db.getGitCacheStats('agent-b')).entries, 1);
  });
}
