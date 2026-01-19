import 'package:locale_sheet/src/core/placeholder_detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects simple placeholders', () {
    const msg = 'Hello {name}, you have {count} items.';
    final set = detectPlaceholders(msg);
    expect(set, containsAll(<String>['name', 'count']));
    expect(set.length, 2);
  });

  test('ignores escaped double braces', () {
    const msg = 'Curly: {{not_a_placeholder}} and real {id}';
    final set = detectPlaceholders(msg);
    expect(set, contains('id'));
    expect(set, isNot(contains('not_a_placeholder')));
  });

  test('respects identifier rules', () {
    const msg = 'Bad {123} good {good_name}';
    final set = detectPlaceholders(msg);
    expect(set, contains('good_name'));
    expect(set, isNot(contains('123')));
  });
}
