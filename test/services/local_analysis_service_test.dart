import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/local_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('method.naturalLanguage');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('analyze returns parsed NLTagger result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'analyzeText') {
        return {
          'language': 'en',
          'entities': [
            {
              'name': 'John Smith',
              'type': 'PersonalName',
              'start': 0,
              'length': 10,
            },
          ],
          'nouns': ['meeting', 'budget'],
        };
      }
      return null;
    });

    final service = LocalAnalysisService();
    final result = await service.analyze('John Smith discussed the meeting budget.');

    expect(result.language, 'en');
    expect(result.entities, hasLength(1));
    expect(result.entities.first.name, 'John Smith');
    expect(result.entities.first.type, 'PersonalName');
    expect(result.entities.first.start, 0);
    expect(result.entities.first.length, 10);
    expect(result.nouns, ['meeting', 'budget']);
  });

  test('analyze handles empty text gracefully', () async {
    // Should never call the platform channel for empty text.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      fail('Platform channel should not be invoked for empty text');
    });

    final service = LocalAnalysisService();
    final result = await service.analyze('');

    expect(result.language, '');
    expect(result.entities, isEmpty);
    expect(result.nouns, isEmpty);
  });

  test('analyze handles PlatformException gracefully', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ERROR', message: 'NLTagger failed');
    });

    final service = LocalAnalysisService();
    final result = await service.analyze('Some text that will fail.');

    expect(result.language, '');
    expect(result.entities, isEmpty);
    expect(result.nouns, isEmpty);
  });

  test('analyze parses multiple entities in single text', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'analyzeText') {
        return {
          'language': 'en',
          'entities': [
            {
              'name': 'Alice',
              'type': 'PersonalName',
              'start': 0,
              'length': 5,
            },
            {
              'name': 'Acme Corp',
              'type': 'OrganizationName',
              'start': 16,
              'length': 9,
            },
            {
              'name': 'New York',
              'type': 'PlaceName',
              'start': 29,
              'length': 8,
            },
          ],
          'nouns': ['office', 'meeting'],
        };
      }
      return null;
    });

    final service = LocalAnalysisService();
    final result =
        await service.analyze('Alice works at Acme Corp in New York office meeting.');

    expect(result.language, 'en');
    expect(result.entities, hasLength(3));

    expect(result.entities[0].name, 'Alice');
    expect(result.entities[0].type, 'PersonalName');

    expect(result.entities[1].name, 'Acme Corp');
    expect(result.entities[1].type, 'OrganizationName');
    expect(result.entities[1].start, 16);

    expect(result.entities[2].name, 'New York');
    expect(result.entities[2].type, 'PlaceName');

    expect(result.nouns, ['office', 'meeting']);
  });
}
