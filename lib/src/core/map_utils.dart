/// 値による等価比較とハッシュのための Map ユーティリティ。
///
/// Dart の `Map` は既定では同一性で比較されるため、`==` / `hashCode` を
/// 値で実装するモデルはこれらを使います。
library;

/// Compare two maps for equality of keys and values.
bool mapEquals(Map<Object?, Object?> a, Map<Object?, Object?> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    if (a[k] != b[k]) return false;
  }
  return true;
}

/// Compute a hash for a map by combining key/value hashes.
///
/// エントリのハッシュを排他的論理和で合成します。排他的論理和は順序に
/// 依存しないため、キーを並べ替える必要はありません。並べ替えていた頃は
/// 無駄な処理であるうえ、`Comparable` でないキーを渡すと実行時例外に
/// なるという問題もありました。
int mapHash(Map<Object?, Object?> map) {
  var hash = 0;
  for (final entry in map.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
