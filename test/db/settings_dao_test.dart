import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late TestFixture fixture;

  setUp(() => fixture = TestFixture());
  tearDown(() => fixture.close());

  group('SettingsDao', () {
    test('returns null for a key that has never been set', () async {
      expect(await fixture.settings.get('missing'), isNull);
    });

    test('set and get round-trips a value', () async {
      await fixture.settings.set('theme', 'dark');
      expect(await fixture.settings.get('theme'), 'dark');
    });

    test('set overwrites an existing value', () async {
      await fixture.settings.set('zoom', '1.0');
      await fixture.settings.set('zoom', '1.5');
      expect(await fixture.settings.get('zoom'), '1.5');
    });

    test('remove deletes a key so get returns null', () async {
      await fixture.settings.set('active_stack', 'abc');
      await fixture.settings.remove('active_stack');
      expect(await fixture.settings.get('active_stack'), isNull);
    });

    test('remove on a non-existent key is a no-op', () async {
      await expectLater(fixture.settings.remove('ghost'), completes);
    });

    test('multiple independent keys do not interfere', () async {
      await fixture.settings.set('a', '1');
      await fixture.settings.set('b', '2');
      expect(await fixture.settings.get('a'), '1');
      expect(await fixture.settings.get('b'), '2');
    });
  });
}
