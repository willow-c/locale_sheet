import 'package:locale_sheet/src/core/model_helpers.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeLocaleTag trims but preserves underscores (AAA)', () {
    // Arrange
    const input1 = ' zh_Hant_TW ';
    const input2 = 'en';

    // Act
    final out1 = normalizeLocaleTag(input1);
    final out2 = normalizeLocaleTag(input2);

    // Assert
    expect(out1, 'zh_Hant_TW');
    expect(out2, 'en');
  });

  test('isValidLocaleTag accepts common tags and rejects bad ones (AAA)', () {
    // Arrange
    const valid = ['en', 'en-US', 'sr_Latn_RS', 'zh-Hant-TW'];
    const invalid = ['', 'not a locale', 'bad/tag', '1n'];

    // Act
    final validResults = valid.map(isValidLocaleTag).toList();
    final invalidResults = invalid.map(isValidLocaleTag).toList();

    // Assert
    for (final r in validResults) {
      expect(r, isTrue);
    }
    for (final r in invalidResults) {
      expect(r, isFalse);
    }
  });

  test(
    'isSafeArbLocaleTag enforces filename safety and Windows rules (AAA)',
    () {
      // Arrange
      const ok = ['en', 'zh_Hant_TW', 'trailing '];
      const nok = ['in/valid', 'bad locale', 'CON', 'NUL', 'trailing.'];

      // Act
      final okResults = ok.map(isSafeArbLocaleTag).toList();
      final nokResults = nok.map(isSafeArbLocaleTag).toList();

      // Assert
      expect(okResults[0], isTrue); // 'en'
      expect(okResults[1], isTrue); // 'zh_Hant_TW'
      // trailing space is normalized/trimmed and thus acceptable
      expect(okResults[2], isTrue);

      for (final r in nokResults) {
        expect(r, isFalse);
      }
    },
  );
}
