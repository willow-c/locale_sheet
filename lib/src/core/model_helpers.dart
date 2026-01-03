/// モデル内で使う簡易ヘルパー関数群。
bool mapEquals(Map a, Map b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    if (a[k] != b[k]) return false;
  }
  return true;
}

int mapHash(Map m) {
  var h = 0;
  final keys = m.keys.toList()..sort();
  for (final k in keys) {
    h = h ^ Object.hash(k, m[k]);
  }
  return h;
}
