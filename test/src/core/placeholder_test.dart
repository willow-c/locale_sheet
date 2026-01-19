import 'package:locale_sheet/locale_sheet.dart';
import 'package:test/test.dart';

void main() {
  test('Placeholder fromMap and toMap with all fields', () {
    final m = {'type': 'int', 'example': '1', 'source': 'detected'};
    final p = Placeholder.fromMap(m);

    expect(p.type, 'int');
    expect(p.example, '1');
    expect(p.source, 'detected');

    final back = p.toMap();
    expect(back['type'], 'int');
    expect(back['example'], '1');
    expect(back['source'], 'detected');
  });

  test('Placeholder fromMap with missing values defaults and nulls', () {
    final m = <String, Object?>{};
    final p = Placeholder.fromMap(m);
    expect(p.type, 'String');
    expect(p.example, isNull);
    expect(p.source, isNull);

    final back = p.toMap();
    expect(back.containsKey('example'), isFalse);
    expect(back.containsKey('source'), isFalse);
  });

  test('Placeholder equality and hashCode', () {
    const a = Placeholder(type: 'String', example: 'x', source: 's');
    const b = Placeholder(type: 'String', example: 'x', source: 's');
    const c = Placeholder(type: 'int');

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a == c, isFalse);
  });
}
