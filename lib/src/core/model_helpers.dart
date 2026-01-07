/// モデル内で使う簡易ヘルパー関数群。
/// Compare two maps for equality of keys and values.
bool mapEquals(Map<Object?, Object?> a, Map<Object?, Object?> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    if (a[k] != b[k]) return false;
  }
  return true;
}

/// Compute a stable hash for a map by combining key/value hashes.
int mapHash(Map<Object?, Object?> m) {
  var h = 0;
  final keys = m.keys.toList()..sort();
  for (final k in keys) {
    h = h ^ Object.hash(k, m[k]);
  }
  return h;
}
