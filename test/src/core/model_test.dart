import 'package:locale_sheet/src/core/model.dart';
import 'package:test/test.dart';

void main() {
  test('model barrel exports expected symbols (AAA)', () {
    // Arrange: nothing to arrange for a barrel file test

    // Act: reference exported symbols to ensure they are available
    const hasBundle = LocalizationBundle;
    const hasEntry = LocalizationEntry;
    const hasSheet = LocalizationSheet;

    // Assert: the symbols resolve to non-null Type objects
    expect(hasBundle, isNotNull);
    expect(hasEntry, isNotNull);
    expect(hasSheet, isNotNull);
  });
}
