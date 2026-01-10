import 'package:locale_sheet/src/core/model_helpers.dart';
import 'package:test/test.dart';

void main() {
  test('isValidLocaleTag accepts common forms', () {
    expect(isValidLocaleTag('en'), isTrue);
    expect(isValidLocaleTag('zh-Hant-HK'), isTrue);
    expect(isValidLocaleTag('zh_Hant_TW'), isTrue);
  });

  test('isValidLocaleTag rejects invalid inputs', () {
    expect(isValidLocaleTag(''), isFalse);
    expect(isValidLocaleTag('a'), isFalse);
    expect(isValidLocaleTag('in/valid'), isFalse);
    expect(isValidLocaleTag('en.'), isFalse);
  });

  test('isSafeArbLocaleTag enforces filename safety', () {
    expect(isSafeArbLocaleTag('en'), isTrue);
    expect(isSafeArbLocaleTag('zh_Hant_TW'), isTrue);
    expect(isSafeArbLocaleTag('in/valid'), isFalse);
    // reserved name
    expect(isSafeArbLocaleTag('CON'), isFalse);
  });
}
