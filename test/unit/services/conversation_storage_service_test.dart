// ABOUTME: Unit tests for conversation storage service implementations
// ABOUTME: Tests all CRUD operations, search, filtering, and stream functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../../../lib/services/conversation_storage_service.dart';
import '../../../lib/models/conversation_model.dart';
import '../../../lib/models/transcription_segment.dart';
import '../../../lib/core/utils/logging_service.dart';

import 'conversation_storage_service_test.mocks.dart';
import '../../test_helpers.dart';

@GenerateMocks([LoggingService])
void main() {
  group('InMemoryConversationStorageService', () {
    late InMemoryConversationStorageService storageService;
    late MockLoggingService mockLogger;

    setUp(() {
      mockLogger = MockLoggingService();
      storageService = InMemoryConversationStorageService(logger: mockLogger);
    });

    tearDown(() async {
      await storageService.dispose();
    });

    group('Basic CRUD Operations', () {
      test('should start with empty conversations list', () async {
        final conversations = await storageService.getAllConversations();
        expect(conversations, isEmpty);
      });

      test('should save and retrieve a conversation', () async {
        final conversation = TestHelpers.createSampleConversation();
        
        await storageService.saveConversation(conversation);
        
        final retrieved = await storageService.getConversation(conversation.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(conversation.id));
        expect(retrieved.title, equals(conversation.title));
      });

      test('should return null for non-existent conversation', () async {
        final retrieved = await storageService.getConversation('non-existent');
        expect(retrieved, isNull);
      });

      test('should update existing conversation', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        final updatedConversation = conversation.copyWith(
          title: 'Updated Title',
          lastUpdated: DateTime.now(),
        );
        
        await storageService.updateConversation(updatedConversation);
        
        final retrieved = await storageService.getConversation(conversation.id);
        expect(retrieved!.title, equals('Updated Title'));
      });

      test('should delete conversation', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        await storageService.deleteConversation(conversation.id);
        
        final retrieved = await storageService.getConversation(conversation.id);
        expect(retrieved, isNull);
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, isEmpty);
      });

      test('should replace conversation with same ID when saving', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        final updatedConversation = conversation.copyWith(
          title: 'New Title',
          lastUpdated: DateTime.now(),
        );
        
        await storageService.saveConversation(updatedConversation);
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, hasLength(1));
        expect(allConversations.first.title, equals('New Title'));
      });
    });

    group('Multiple Conversations', () {
      test('should handle multiple conversations', () async {
        final conversation1 = TestHelpers.createSampleConversation(id: 'conv1');
        final conversation2 = TestHelpers.createSampleConversation(id: 'conv2');
        final conversation3 = TestHelpers.createSampleConversation(id: 'conv3');
        
        await storageService.saveConversation(conversation1);
        await storageService.saveConversation(conversation2);
        await storageService.saveConversation(conversation3);
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, hasLength(3));
      });

      test('should sort conversations by start time (newest first)', () async {
        final now = DateTime.now();
        final conversation1 = TestHelpers.createSampleConversation(
          id: 'conv1',
          startTime: now.subtract(const Duration(hours: 2)),
        );
        final conversation2 = TestHelpers.createSampleConversation(
          id: 'conv2',
          startTime: now.subtract(const Duration(hours: 1)),
        );
        final conversation3 = TestHelpers.createSampleConversation(
          id: 'conv3',
          startTime: now,
        );
        
        // Save in random order
        await storageService.saveConversation(conversation1);
        await storageService.saveConversation(conversation3);
        await storageService.saveConversation(conversation2);
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations[0].id, equals('conv3')); // Newest
        expect(allConversations[1].id, equals('conv2')); // Middle
        expect(allConversations[2].id, equals('conv1')); // Oldest
      });
    });

    group('Search Functionality', () {
      late ConversationModel conversation1;
      late ConversationModel conversation2;
      late ConversationModel conversation3;

      setUp(() async {
        conversation1 = TestHelpers.createSampleConversation(
          id: 'conv1',
          title: 'Team Meeting',
          segments: [
            TestHelpers.createSampleSegment(content: 'Let\'s discuss the project'),
            TestHelpers.createSampleSegment(content: 'We need to finish by Friday'),
          ],
        );
        
        conversation2 = TestHelpers.createSampleConversation(
          id: 'conv2',
          title: 'Client Call',
          segments: [
            TestHelpers.createSampleSegment(content: 'The client wants changes'),
            TestHelpers.createSampleSegment(content: 'Budget approval needed'),
          ],
        );
        
        conversation3 = TestHelpers.createSampleConversation(
          id: 'conv3',
          title: 'Code Review',
          segments: [
            TestHelpers.createSampleSegment(content: 'This function needs optimization'),
            TestHelpers.createSampleSegment(content: 'Unit tests are missing'),
          ],
        );

        await storageService.saveConversation(conversation1);
        await storageService.saveConversation(conversation2);
        await storageService.saveConversation(conversation3);
      });

      test('should search conversations by title', () async {
        final results = await storageService.searchConversations('Team');
        
        expect(results, hasLength(1));
        expect(results.first.id, equals('conv1'));
      });

      test('should search conversations by segment content', () async {
        final results = await storageService.searchConversations('client');
        
        expect(results, hasLength(1));
        expect(results.first.id, equals('conv2'));
      });

      test('should search conversations by participant name', () async {
        final results = await storageService.searchConversations('Alice');
        
        expect(results, hasLength(3)); // All conversations have Alice
      });

      test('should return empty results for non-matching query', () async {
        final results = await storageService.searchConversations('nonexistent');
        
        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await storageService.searchConversations('TEAM');
        
        expect(results, hasLength(1));
        expect(results.first.id, equals('conv1'));
      });
    });

    group('Date Range Filtering', () {
      test('should filter conversations by date range', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));
        
        final conversation1 = TestHelpers.createSampleConversation(
          id: 'conv1',
          startTime: yesterday,
        );
        final conversation2 = TestHelpers.createSampleConversation(
          id: 'conv2',
          startTime: now,
        );
        final conversation3 = TestHelpers.createSampleConversation(
          id: 'conv3',
          startTime: tomorrow,
        );
        
        await storageService.saveConversation(conversation1);
        await storageService.saveConversation(conversation2);
        await storageService.saveConversation(conversation3);
        
        final results = await storageService.getConversationsByDateRange(
          yesterday.subtract(const Duration(hours: 1)),
          now.add(const Duration(hours: 1)),
        );
        
        expect(results, hasLength(2));
        expect(results.map((c) => c.id), containsAll(['conv1', 'conv2']));
      });

      test('should return empty results for non-matching date range', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        final futureStart = DateTime.now().add(const Duration(days: 1));
        final futureEnd = DateTime.now().add(const Duration(days: 2));
        
        final results = await storageService.getConversationsByDateRange(
          futureStart,
          futureEnd,
        );
        
        expect(results, isEmpty);
      });
    });

    group('Stream Functionality', () {
      test('should emit conversation updates via stream', () async {
        final conversation = TestHelpers.createSampleConversation();
        
        expectLater(
          storageService.conversationStream,
          emitsInOrder([
            [conversation], // After save
            [], // After delete
          ]),
        );
        
        await storageService.saveConversation(conversation);
        await storageService.deleteConversation(conversation.id);
      });

      test('should emit updates when conversation is updated', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        final updatedConversation = conversation.copyWith(
          title: 'Updated Title',
          lastUpdated: DateTime.now(),
        );
        
        expectLater(
          storageService.conversationStream,
          emits([updatedConversation]),
        );
        
        await storageService.updateConversation(updatedConversation);
      });

      test('should handle multiple rapid updates', () async {
        final conversation1 = TestHelpers.createSampleConversation(id: 'conv1');
        final conversation2 = TestHelpers.createSampleConversation(id: 'conv2');
        final conversation3 = TestHelpers.createSampleConversation(id: 'conv3');
        
        // Save multiple conversations rapidly
        await storageService.saveConversation(conversation1);
        await storageService.saveConversation(conversation2);
        await storageService.saveConversation(conversation3);
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, hasLength(3));
      });
    });

    group('Error Handling', () {
      test('should handle update of non-existent conversation gracefully', () async {
        final conversation = TestHelpers.createSampleConversation();
        
        // Should not throw error
        await storageService.updateConversation(conversation);
        
        final retrieved = await storageService.getConversation(conversation.id);
        expect(retrieved, isNull);
      });

      test('should handle delete of non-existent conversation gracefully', () async {
        // Should not throw error
        await storageService.deleteConversation('non-existent');
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, isEmpty);
      });

      test('should handle empty search query', () async {
        final conversation = TestHelpers.createSampleConversation();
        await storageService.saveConversation(conversation);
        
        final results = await storageService.searchConversations('');
        expect(results, hasLength(1));
      });
    });

    group('Logging', () {
      test('should log save operations', () async {
        final conversation = TestHelpers.createSampleConversation();
        
        await storageService.saveConversation(conversation);
        
        verify(mockLogger.log(
          'InMemoryConversationStorageService',
          'Saving conversation: ${conversation.id}',
          LogLevel.info,
        )).called(1);
      });

      test('should log delete operations', () async {
        const conversationId = 'test-id';
        
        await storageService.deleteConversation(conversationId);
        
        verify(mockLogger.log(
          'InMemoryConversationStorageService',
          'Deleting conversation: $conversationId',
          LogLevel.info,
        )).called(1);
      });

      test('should log search operations', () async {
        const query = 'test query';
        
        await storageService.searchConversations(query);
        
        verify(mockLogger.log(
          'InMemoryConversationStorageService',
          'Searching conversations: $query',
          LogLevel.debug,
        )).called(1);
      });
    });

    group('Performance', () {
      test('should handle large number of conversations efficiently', () async {
        // Create 1000 conversations
        final conversations = List.generate(1000, (index) =>
          TestHelpers.createSampleConversation(id: 'conv_$index'),
        );
        
        // Measure save time
        final stopwatch = Stopwatch()..start();
        
        for (final conversation in conversations) {
          await storageService.saveConversation(conversation);
        }
        
        stopwatch.stop();
        
        // Should complete within reasonable time (adjust as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        
        final allConversations = await storageService.getAllConversations();
        expect(allConversations, hasLength(1000));
      });

      test('should handle search on large dataset efficiently', () async {
        // Create 100 conversations with searchable content
        final conversations = List.generate(100, (index) =>
          TestHelpers.createSampleConversation(
            id: 'conv_$index',
            title: index % 10 == 0 ? 'Special Meeting $index' : 'Regular Meeting $index',
          ),
        );
        
        for (final conversation in conversations) {
          await storageService.saveConversation(conversation);
        }
        
        // Measure search time
        final stopwatch = Stopwatch()..start();
        
        final results = await storageService.searchConversations('Special');
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(results, hasLength(10)); // 10 special meetings
      });
    });
  });
}