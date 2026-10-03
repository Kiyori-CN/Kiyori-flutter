import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';

void main() {
  test('v2 pool defaults untested and v3 persists status until key edit', () {
    final original = ModelPoolKey.create('fixture-old')
        .withAvailability('AVAILABLE');
    final encoded = ModelCredentials(keys: [original]).encode();
    expect(
      ModelCredentials.decode(encoded).keys.single.availability,
      'AVAILABLE',
    );
    final v2 = jsonDecode(encoded) as Map<String, dynamic>;
    v2['version'] = 2;
    expect(
      ModelCredentials.decode(jsonEncode(v2)).keys.single.availability,
      'UNTESTED',
    );
    final edited = original.edited('fixture-new');
    expect(edited.id, original.id);
    expect(edited.availability, 'UNTESTED');
  });
  test('text import trims lines and BOM without merging repeated values', () {
    final values = ModelPoolKey.importLines(
      '\uFEFF first \r\n\nsecond\rfirst\n',
    );
    expect(values.map((k) => k.key), ['first', 'second', 'first']);
    expect(values.map((k) => k.id).toSet(), hasLength(3));
  });
  test(
    'legacy pool migrates without merging duplicate values or changing order',
    () {
      final encoded = jsonEncode({
        'version': 1,
        'apiKey': 'fixture-primary',
        'headers': {'X-Fixture': 'fixture-header'},
        'usePool': true,
        'keys': ['fixture-a', 'fixture-a', 'fixture-b'],
        'rotation': 'RANDOM',
      });
      final migrated = ModelCredentials.decode(encoded);
      expect(migrated.keys.map((k) => k.key), [
        'fixture-a',
        'fixture-a',
        'fixture-b',
      ]);
      expect(migrated.keys.map((k) => k.id).toSet(), hasLength(3));
      expect(jsonDecode(migrated.encode())['version'], 3);
      final reopened = ModelCredentials.decode(migrated.encode());
      expect(reopened.encode(), migrated.encode());
      expect(reopened.apiKey, 'fixture-primary');
      expect(reopened.headers, {'X-Fixture': 'fixture-header'});
      expect(reopened.rotation, 'RANDOM');
    },
  );

  test('edit preserves identity and enabled state across encrypted payload roundtrip', () {
    final generated = ModelPoolKey.create('fixture-one');
    final original = ModelPoolKey(
      id: generated.id,
      key: generated.key,
      name: generated.name,
      enabled: false,
    );
    final edited = original.edited('new');
    expect(edited.id, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(edited.id, original.id);
    expect(edited.enabled, isFalse);
    expect(edited.name, 'API Key new');
    final loaded = ModelCredentials.decode(
      ModelCredentials(keys: [edited]).encode(),
    );
    expect(loaded.keys.single.toJson(), edited.toJson());
  });

  test(
    'malformed or ambiguous payload fails without including sensitive input',
    () {
      const key = ModelPoolKey(
        id: 'duplicate',
        key: 'fixture-sensitive',
        name: 'name',
      );
      for (final value in [
        'invalid fixture-sensitive',
        jsonEncode({'version': 99, 'apiKey': 'fixture-sensitive'}),
        jsonEncode({
          'version': 2,
          'apiKey': '',
          'headers': {},
          'usePool': true,
          'keys': [key.toJson(), key.toJson()],
          'rotation': 'ROUND_ROBIN',
        }),
        jsonEncode({
          'version': 1,
          'apiKey': '',
          'headers': {'X-Fixture': 'fixture-sensitive\r\nInjected: value'},
          'usePool': false,
          'keys': [],
          'rotation': 'ROUND_ROBIN',
        }),
      ]) {
        expect(
          () => ModelCredentials.decode(value),
          throwsA(
            isA<FormatException>()
                .having(
                  (e) => e.message,
                  'redacted message',
                  '安全凭据无法读取，请保留原数据并重试',
                )
                .having((e) => e.source, 'no input attached', isNull),
          ),
        );
      }
    },
  );
}
