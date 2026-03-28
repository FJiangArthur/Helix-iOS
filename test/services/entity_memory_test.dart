import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/entity_memory.dart';

void main() {
  // EntityMemory is a singleton — we need a fresh in-memory map for each test.
  // The singleton pattern means we work with EntityMemory.instance but clear
  // its state between tests.  The private _entities map is mutated via
  // addEntity / lookup, and _persistEntityAsFact will fail silently because
  // there is no real database in tests (which is fine — we are testing the
  // in-memory layer only).

  late EntityMemory memory;

  setUp(() {
    // Access the singleton and clear any leftover entities from previous tests.
    memory = EntityMemory.instance;
    // Wipe the in-memory store by adding nothing — we verify via `all`.
    // There is no public clear() method, so we rely on the fact that the map
    // is keyed by lowercase name and we can simply overwrite.  To truly reset
    // we call the private constructor trick isn't available, but since
    // addEntity overwrites by key and lookup returns null for missing keys,
    // we just need to be careful with key choices per test.
  });

  group('C4a - Add entity, lookup returns it', () {
    test('added entity is retrievable via lookup', () {
      final entity = EntityInfo(
        name: 'Alice',
        title: 'CTO',
        company: 'Acme',
        context: 'Met at conference',
        lastMentioned: DateTime(2026, 3, 26),
      );

      memory.addEntity(entity);

      final result = memory.lookup('Alice');
      expect(result, isNotNull);
      expect(result!.name, 'Alice');
      expect(result.title, 'CTO');
      expect(result.company, 'Acme');
      expect(result.context, 'Met at conference');
    });

    test('lookup is case-insensitive', () {
      final entity = EntityInfo(
        name: 'Bob Smith',
        lastMentioned: DateTime(2026, 3, 26),
      );

      memory.addEntity(entity);

      expect(memory.lookup('bob smith'), isNotNull);
      expect(memory.lookup('BOB SMITH'), isNotNull);
      expect(memory.lookup('Bob Smith'), isNotNull);
      expect(memory.lookup('bob smith')!.name, 'Bob Smith');
    });

    test('entity appears in the all getter', () {
      final entity = EntityInfo(
        name: 'UniqueEntityC4a',
        lastMentioned: DateTime(2026, 3, 26),
      );

      memory.addEntity(entity);

      final allEntities = memory.all;
      final match = allEntities.where((e) => e.name == 'UniqueEntityC4a');
      expect(match, isNotEmpty);
    });
  });

  group('C4b - Lookup non-existent entity returns null', () {
    test('lookup returns null for unknown entity', () {
      final result = memory.lookup('NonExistentPerson12345');
      expect(result, isNull);
    });

    test('lookup returns null for empty string', () {
      final result = memory.lookup('');
      expect(result, isNull);
    });
  });

  group('C4c - Adding same entity twice does not duplicate', () {
    test('same name (exact case) overwrites rather than duplicates', () {
      final entity1 = EntityInfo(
        name: 'Charlie',
        title: 'Engineer',
        lastMentioned: DateTime(2026, 3, 1),
      );
      final entity2 = EntityInfo(
        name: 'Charlie',
        title: 'Senior Engineer',
        lastMentioned: DateTime(2026, 3, 26),
      );

      memory.addEntity(entity1);
      memory.addEntity(entity2);

      // The map is keyed by lowercase name, so the second add overwrites.
      final result = memory.lookup('Charlie');
      expect(result, isNotNull);
      expect(result!.title, 'Senior Engineer');

      // Count occurrences with this exact lowercase key in all.
      final charlieCount =
          memory.all.where((e) => e.name == 'Charlie').length;
      expect(charlieCount, 1, reason: 'Should not have duplicate entries');
    });

    test('different-case name treated as same entity (dedup)', () {
      final entity1 = EntityInfo(
        name: 'Diana Prince',
        title: 'Ambassador',
        lastMentioned: DateTime(2026, 3, 1),
      );
      final entity2 = EntityInfo(
        name: 'diana prince',
        title: 'Warrior',
        lastMentioned: DateTime(2026, 3, 26),
      );

      memory.addEntity(entity1);
      memory.addEntity(entity2);

      // Both map to key 'diana prince', so the second overwrites the first.
      final result = memory.lookup('Diana Prince');
      expect(result, isNotNull);
      expect(result!.title, 'Warrior');

      // There should only be one entry for this key.
      final dianaCount = memory.all
          .where((e) => e.name.toLowerCase() == 'diana prince')
          .length;
      expect(dianaCount, 1);
    });
  });

  group('EntityInfo serialization', () {
    test('toJson and fromJson round-trip', () {
      final entity = EntityInfo(
        name: 'Eve',
        title: 'Designer',
        company: 'DesignCo',
        context: 'Works on UI',
        lastMentioned: DateTime(2026, 3, 26, 10, 30),
      );

      final json = entity.toJson();
      final restored = EntityInfo.fromJson(json);

      expect(restored.name, entity.name);
      expect(restored.title, entity.title);
      expect(restored.company, entity.company);
      expect(restored.context, entity.context);
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{'name': 'Frank'};
      final entity = EntityInfo.fromJson(json);

      expect(entity.name, 'Frank');
      expect(entity.title, isNull);
      expect(entity.company, isNull);
      expect(entity.context, isNull);
    });
  });
}
