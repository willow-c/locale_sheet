import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  test('library exposes convertExcelToArb function', () {
    expect(convertExcelToArb, isA<Function>());
  });
}
