import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/knowledge_base.dart';

void main() {
  late HelixDatabase db;
  late UserKnowledgeBase kb;

  setUp(() {
    db = HelixDatabase.testWith(NativeDatabase.memory());
    kb = UserKnowledgeBase(db.knowledgeDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Entity management', () {
    test('addOrUpdateEntity stores and retrieves', () async {
      await kb.addOrUpdateEntity(
        name: 'Alice',
        type: 'person',
        metadata: {'title': 'Engineer'},
        source: 'passive',
      );

      final entity = await kb.findEntity('Alice');
      expect(entity, isNotNull);
      expect(entity!.name, 'Alice');
      expect(entity.type, 'person');
      expect(entity.source, 'passive');

      final meta = jsonDecode(entity.metadata!) as Map<String, dynamic>;
      expect(meta['title'], 'Engineer');
    });

    test('addOrUpdateEntity increments mention count on second call', () async {
      await kb.addOrUpdateEntity(
        name: 'Bob',
        type: 'person',
        source: 'passive',
      );

      final first = await kb.findEntity('Bob');
      expect(first, isNotNull);
      expect(first!.mentionCount, 1);

      await kb.addOrUpdateEntity(
        name: 'Bob',
        type: 'person',
        source: 'passive',
      );

      final second = await kb.findEntity('Bob');
      expect(second, isNotNull);
      expect(second!.mentionCount, 2);
      // ID should be the same (reused)
      expect(second.id, first.id);
    });

    test('empty name is skipped', () async {
      await kb.addOrUpdateEntity(
        name: '',
        type: 'person',
        source: 'passive',
      );

      final results = await kb.getTopEntities();
      expect(results, isEmpty);
    });

    test('whitespace-only name is skipped', () async {
      await kb.addOrUpdateEntity(
        name: '   ',
        type: 'person',
        source: 'passive',
      );

      final results = await kb.getTopEntities();
      expect(results, isEmpty);
    });

    test('name is trimmed for lookup', () async {
      await kb.addOrUpdateEntity(
        name: '  Alice  ',
        type: 'person',
        source: 'passive',
      );

      final entity = await kb.findEntity('Alice');
      expect(entity, isNotNull);
      expect(entity!.name, 'Alice');
    });

    test('searchEntities returns matching results', () async {
      await kb.addOrUpdateEntity(
          name: 'Alice Smith', type: 'person', source: 'passive');
      await kb.addOrUpdateEntity(
          name: 'Bob Jones', type: 'person', source: 'passive');

      final results = await kb.searchEntities('Alice');
      expect(results.length, 1);
      expect(results.first.name, 'Alice Smith');
    });
  });

  group('Relationship management', () {
    test('addRelationship stores and retrieves', () async {
      await kb.addOrUpdateEntity(
          name: 'Alice', type: 'person', source: 'passive');
      await kb.addOrUpdateEntity(
          name: 'Acme Corp', type: 'company', source: 'passive');

      final alice = await kb.findEntity('Alice');
      final acme = await kb.findEntity('Acme Corp');

      await kb.addRelationship(
        entityAId: alice!.id,
        entityBId: acme!.id,
        relationType: 'works_at',
        description: 'Alice works at Acme Corp',
      );

      final rels = await kb.getRelationshipsFor(alice.id);
      expect(rels.length, 1);
      expect(rels.first.relationType, 'works_at');
      expect(rels.first.entityAId, alice.id);
      expect(rels.first.entityBId, acme.id);
    });
  });

  group('User profile', () {
    test('getProfile returns default initially', () async {
      final json = await kb.getProfile();
      final profile = jsonDecode(json) as Map<String, dynamic>;
      expect(profile.containsKey('identity'), isTrue);
      expect(profile.containsKey('communicationStyle'), isTrue);

      final identity = profile['identity'] as Map<String, dynamic>;
      expect(identity['name'], '');
    });

    test('updateProfile deep-merges updates', () async {
      // Set name
      await kb.updateProfile({
        'identity': {'name': 'Art', 'role': 'Developer'},
      });

      var json = await kb.getProfile();
      var profile = jsonDecode(json) as Map<String, dynamic>;
      var identity = profile['identity'] as Map<String, dynamic>;
      expect(identity['name'], 'Art');
      expect(identity['role'], 'Developer');
      // company should still exist from default (empty string)
      expect(identity.containsKey('company'), isTrue);

      // Deep merge: update role only, name should remain
      await kb.updateProfile({
        'identity': {'role': 'Senior Developer'},
      });

      json = await kb.getProfile();
      profile = jsonDecode(json) as Map<String, dynamic>;
      identity = profile['identity'] as Map<String, dynamic>;
      expect(identity['name'], 'Art');
      expect(identity['role'], 'Senior Developer');
    });

    test('updateProfile overwrites non-map values', () async {
      await kb.updateProfile({
        'interests': ['music', 'coding'],
      });

      final json = await kb.getProfile();
      final profile = jsonDecode(json) as Map<String, dynamic>;
      expect(profile['interests'], ['music', 'coding']);
    });
  });

  group('Context building', () {
    test('buildContextSummary returns formatted string with entity info',
        () async {
      // Set up profile
      await kb.updateProfile({
        'identity': {'name': 'Art', 'role': 'Engineer', 'company': 'Helix'},
      });

      // Add people
      await kb.addOrUpdateEntity(
        name: 'Alice',
        type: 'person',
        metadata: {'title': 'CTO'},
        source: 'passive',
      );
      await kb.addOrUpdateEntity(
        name: 'Bob',
        type: 'person',
        metadata: {'role': 'PM'},
        source: 'passive',
      );

      // Add company
      await kb.addOrUpdateEntity(
        name: 'Acme Corp',
        type: 'company',
        source: 'passive',
      );

      final summary = await kb.buildContextSummary();
      expect(summary, contains('[User Knowledge Context]'));
      expect(summary, contains('Name: Art'));
      expect(summary, contains('Role: Engineer'));
      expect(summary, contains('Company: Helix'));
      expect(summary, contains('Key people:'));
      expect(summary, contains('Alice (CTO)'));
      expect(summary, contains('Bob (PM)'));
      expect(summary, contains('Key companies:'));
      expect(summary, contains('Acme Corp'));
    });

    test('buildContextSummary with empty profile still has header', () async {
      final summary = await kb.buildContextSummary();
      expect(summary, contains('[User Knowledge Context]'));
    });
  });
}
