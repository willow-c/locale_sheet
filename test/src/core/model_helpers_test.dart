import 'package:locale_sheet/src/core/model_helpers.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeLocaleTag trims but preserves underscores', () {
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

  test('isValidLocaleTag accepts common tags and rejects bad ones', () {
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

  test('isValidLocaleTag accepts common forms (additional)', () {
    // Arrange
    const a = 'en';
    const b = 'zh-Hant-HK';
    const c = 'zh_Hant_TW';

    // Act
    final ra = isValidLocaleTag(a);
    final rb = isValidLocaleTag(b);
    final rc = isValidLocaleTag(c);

    // Assert
    expect(ra, isTrue);
    expect(rb, isTrue);
    expect(rc, isTrue);
  });

  test('isValidLocaleTag rejects other invalid inputs', () {
    // Arrange
    const a = '';
    const b = 'a';
    const c = 'in/valid';
    const d = 'en.';

    // Act
    final ra = isValidLocaleTag(a);
    final rb = isValidLocaleTag(b);
    final rc = isValidLocaleTag(c);
    final rd = isValidLocaleTag(d);

    // Assert
    expect(ra, isFalse);
    expect(rb, isFalse);
    expect(rc, isFalse);
    expect(rd, isFalse);
  });

  test('isSafeArbLocaleTag enforces filename safety and Windows rules', () {
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
  });

  test(
    'isSafeArbLocaleTag rejects tags with double hyphen or leading/trailing hyphen',
    () {
      // Arrange
      const a = 'en--US';
      const b = '-en';
      const c = 'en-';

      // Act
      final ra = isSafeArbLocaleTag(a);
      final rb = isSafeArbLocaleTag(b);
      final rc = isSafeArbLocaleTag(c);

      // Assert
      expect(ra, isFalse);
      expect(rb, isFalse);
      expect(rc, isFalse);
    },
  );
}
