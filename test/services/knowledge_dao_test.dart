import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/knowledge_dao.dart';

void main() {
  late HelixDatabase db;
  late KnowledgeDao dao;

  setUp(() {
    db = HelixDatabase.testWith(NativeDatabase.memory());
    dao = db.knowledgeDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('KnowledgeDao - Entities', () {
    KnowledgeEntitiesCompanion makeEntity({
      String id = 'e1',
      String name = 'Alice',
      String type = 'person',
      String source = 'passive',
      double confidence = 0.8,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return KnowledgeEntitiesCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        source: Value(source),
        firstSeen: Value(now),
        lastSeen: Value(now),
        confidence: Value(confidence),
      );
    }

    test('upsertEntity inserts a new entity', () async {
      await dao.upsertEntity(makeEntity());

      final result = await dao.findEntityByName('Alice');
      expect(result, isNotNull);
      expect(result!.name, 'Alice');
      expect(result.type, 'person');
      expect(result.mentionCount, 1);
    });

    test('upsertEntity increments mentionCount on existing', () async {
      await dao.upsertEntity(makeEntity());
      await dao.upsertEntity(makeEntity(confidence: 0.9));

      final result = await dao.findEntityByName('Alice');
      expect(result, isNotNull);
      expect(result!.mentionCount, 2);
      expect(result.confidence, 0.9);
    });

    test('upsertEntity increments mentionCount multiple times', () async {
      await dao.upsertEntity(makeEntity());
      await dao.upsertEntity(makeEntity());
      await dao.upsertEntity(makeEntity());

      final result = await dao.findEntityByName('Alice');
      expect(result!.mentionCount, 3);
    });

    test('findEntityByName is case-insensitive', () async {
      await dao.upsertEntity(makeEntity());

      expect(await dao.findEntityByName('alice'), isNotNull);
      expect(await dao.findEntityByName('ALICE'), isNotNull);
      expect(await dao.findEntityByName('Alice'), isNotNull);
    });

    test('findEntityByName returns null for missing entity', () async {
      final result = await dao.findEntityByName('Nobody');
      expect(result, isNull);
    });

    test('searchEntities matches partial names', () async {
      await dao.upsertEntity(makeEntity(id: 'e1', name: 'Alice Smith'));
      await dao.upsertEntity(makeEntity(id: 'e2', name: 'Bob'));
      await dao.upsertEntity(makeEntity(id: 'e3', name: 'Alicia Keys'));

      final results = await dao.searchEntities('Ali');
      expect(results.length, 2);
      expect(results.map((e) => e.name), containsAll(['Alice Smith', 'Alicia Keys']));
    });

    test('searchEntities orders by mentionCount desc', () async {
      await dao.upsertEntity(makeEntity(id: 'e1', name: 'Alice'));
      await dao.upsertEntity(makeEntity(id: 'e2', name: 'Alicia'));
      // Bump Alice's count
      await dao.upsertEntity(makeEntity(id: 'e1', name: 'Alice'));
      await dao.upsertEntity(makeEntity(id: 'e1', name: 'Alice'));

      final results = await dao.searchEntities('Ali');
      expect(results.first.name, 'Alice');
      expect(results.first.mentionCount, 3);
    });

    test('getTopEntities respects limit and ordering', () async {
      for (var i = 0; i < 5; i++) {
        await dao.upsertEntity(makeEntity(id: 'e$i', name: 'Entity$i'));
      }
      // Bump entity2 multiple times
      await dao.upsertEntity(makeEntity(id: 'e2', name: 'Entity2'));
      await dao.upsertEntity(makeEntity(id: 'e2', name: 'Entity2'));

      final top = await dao.getTopEntities(limit: 3);
      expect(top.length, 3);
      expect(top.first.id, 'e2');
      expect(top.first.mentionCount, 3);
    });
  });

  group('KnowledgeDao - Relationships', () {
    test('insertRelationship stores a relationship', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.insertRelationship(KnowledgeRelationshipsCompanion(
        id: const Value('r1'),
        entityAId: const Value('e1'),
        entityBId: const Value('e2'),
        relationType: const Value('works_with'),
        firstSeen: Value(now),
        lastSeen: Value(now),
      ));

      final results = await dao.getRelationshipsFor('e1');
      expect(results.length, 1);
      expect(results.first.relationType, 'works_with');
    });

    test('getRelationshipsFor finds both directions', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.insertRelationship(KnowledgeRelationshipsCompanion(
        id: const Value('r1'),
        entityAId: const Value('e1'),
        entityBId: const Value('e2'),
        relationType: const Value('works_with'),
        firstSeen: Value(now),
        lastSeen: Value(now),
      ));
      await dao.insertRelationship(KnowledgeRelationshipsCompanion(
        id: const Value('r2'),
        entityAId: const Value('e3'),
        entityBId: const Value('e1'),
        relationType: const Value('manages'),
        firstSeen: Value(now),
        lastSeen: Value(now),
      ));

      final results = await dao.getRelationshipsFor('e1');
      expect(results.length, 2);
    });

    test('insertRelationship updates on conflict', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = KnowledgeRelationshipsCompanion(
        id: const Value('r1'),
        entityAId: const Value('e1'),
        entityBId: const Value('e2'),
        relationType: const Value('works_with'),
        firstSeen: Value(now),
        lastSeen: Value(now),
        confidence: const Value(0.5),
      );
      await dao.insertRelationship(entry);

      // Update with higher confidence
      await dao.insertRelationship(entry.copyWith(
        confidence: const Value(0.9),
        description: const Value('Close colleagues'),
      ));

      final results = await dao.getRelationshipsFor('e1');
      expect(results.length, 1);
      expect(results.first.confidence, 0.9);
      expect(results.first.description, 'Close colleagues');
    });

    test('getRelationshipsFor returns empty for unknown entity', () async {
      final results = await dao.getRelationshipsFor('unknown');
      expect(results, isEmpty);
    });
  });

  group('KnowledgeDao - UserProfile', () {
    test('getProfile returns default when empty', () async {
      final profile = await dao.getProfile();
      expect(profile.id, 1);
      expect(profile.version, 1);
      expect(profile.profileJson, contains('"identity"'));
      expect(profile.profileJson, contains('"communicationStyle"'));
    });

    test('getProfile returns same default on repeated calls', () async {
      final p1 = await dao.getProfile();
      final p2 = await dao.getProfile();
      expect(p1.profileJson, p2.profileJson);
      expect(p1.version, p2.version);
    });

    test('updateProfile changes JSON and increments version', () async {
      // Ensure default is created first
      await dao.getProfile();

      const newJson = '{"identity":{"name":"Art"}}';
      await dao.updateProfile(newJson);

      final profile = await dao.getProfile();
      expect(profile.profileJson, newJson);
      expect(profile.version, 2);
    });

    test('updateProfile increments version each time', () async {
      await dao.getProfile();

      await dao.updateProfile('{"v":1}');
      await dao.updateProfile('{"v":2}');
      await dao.updateProfile('{"v":3}');

      final profile = await dao.getProfile();
      expect(profile.version, 4); // 1 (default) + 3 updates
      expect(profile.profileJson, '{"v":3}');
    });

    test('updateProfile creates profile if none exists', () async {
      // Skip getProfile — go straight to update
      await dao.updateProfile('{"custom":true}');

      final profile = await dao.getProfile();
      expect(profile.profileJson, '{"custom":true}');
      expect(profile.version, 1);
    });
  });
}
