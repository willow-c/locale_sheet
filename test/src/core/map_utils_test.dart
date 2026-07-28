import 'package:locale_sheet/src/core/map_utils.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// Comparable を実装しないキー。並べ替えを行う実装では実行時例外になる。
@immutable
class _Key {
  const _Key(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is _Key && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  /// mapEqualsが件数・キー・値のいずれの違いも検出することを検証
  /// Arrange-Act-Assertパターン
  test('mapEquals compares keys and values', () {
    // Arrange
    const base = {'a': 1, 'b': 2};

    // Act & Assert
    expect(mapEquals(base, const {'a': 1, 'b': 2}), isTrue);
    // 並び順は等価性に影響しない
    expect(mapEquals(base, const {'b': 2, 'a': 1}), isTrue);
    // 値が違う
    expect(mapEquals(base, const {'a': 1, 'b': 3}), isFalse);
    // キーが違う
    expect(mapEquals(base, const {'a': 1, 'c': 2}), isFalse);
    // 件数が違う
    expect(mapEquals(base, const {'a': 1}), isFalse);
    // 空同士
    expect(mapEquals(const {}, const {}), isTrue);
  });

  /// mapHashが内容の等しいMapに同じ値を返し、並び順に依存しないことを検証
  /// Arrange-Act-Assertパターン
  test('mapHash is order-independent and content-based', () {
    // Arrange
    const a = {'x': 1, 'y': 2};
    const b = {'y': 2, 'x': 1};
    const different = {'x': 1, 'y': 3};

    // Act & Assert
    expect(mapHash(a), equals(mapHash(b)));
    expect(mapHash(a), isNot(equals(mapHash(different))));
    expect(mapHash(const {}), equals(mapHash(const {})));
  });

  /// Comparableでないキーを持つMapでも例外にならないことを検証
  /// （並べ替えを行っていた頃は実行時例外になっていた）
  /// Arrange-Act-Assertパターン
  test('mapHash accepts keys that are not Comparable', () {
    // Arrange
    final map = {const _Key(1): 'one', const _Key(2): 'two'};
    final reordered = {const _Key(2): 'two', const _Key(1): 'one'};

    // Act & Assert
    expect(() => mapHash(map), returnsNormally);
    expect(mapHash(map), equals(mapHash(reordered)));
  });
}
