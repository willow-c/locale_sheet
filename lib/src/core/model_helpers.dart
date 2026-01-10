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

// Locale helper: normalize and validate locale tags.
/// Normalize a locale tag by trimming surrounding whitespace.
///
/// This function does not change separator characters; it preserves
/// underscores (`_`) and hyphens (`-`) as provided by the caller.
/// Separator normalization (e.g. converting `-` to `_` for ARB
/// filenames) is performed by exporters or other callers when needed.
///
/// Examples: ` zh_Hant_TW ` -> `zh_Hant_TW`.
String normalizeLocaleTag(String input) => input.trim();

/// Returns true when [input] looks like a BCP-47-like locale tag.
///
/// Accepts patterns like: `language`, `language-region`,
/// `language-script-region` and additional variants. This is a practical,
/// permissive check. Both hyphen (`-`) and underscore (`_`) separators in
/// incoming strings are accepted (they are treated equivalently for parsing
/// purposes).
bool isValidLocaleTag(String input) {
  final tag = normalizeLocaleTag(input);
  if (tag.isEmpty) return false;
  if (tag.contains(RegExp(r'[\\/\s]'))) return false;
  // disallow dot characters in the tag
  if (tag.contains('.')) return false;
  // Accept either '-' or '_' as separators in incoming tags for validation.
  final parseTag = tag.replaceAll('_', '-');
  final parts = parseTag.split('-');
  final language = parts[0];
  if (!RegExp(r'^[A-Za-z]{2,8}$').hasMatch(language)) return false;

  var idx = 1;
  if (parts.length > idx && RegExp(r'^[A-Za-z]{4}$').hasMatch(parts[idx])) {
    idx++;
  }
  if (parts.length > idx &&
      RegExp(r'^([A-Za-z]{2}|\d{3})$').hasMatch(parts[idx])) {
    idx++;
  }
  for (var i = idx; i < parts.length; i++) {
    if (!RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(parts[i])) return false;
  }
  return true;
}

/// Additional filename safety checks for ARB output.
///
/// This check permits underscores (`_`) because ARB filenames follow the
/// Flutter convention (e.g. `app_en_US.arb`). Exporters may convert
/// hyphens to underscores when generating ARB filenames; this helper only
/// validates that the tag can be safely used as part of a filename.
bool isSafeArbLocaleTag(String input) {
  final tag = normalizeLocaleTag(input);
  if (!isValidLocaleTag(tag)) return false;

  // Basic file-safety checks
  // Leading dot is invalid for filenames. Slash/backslash checks are
  // redundant because `isValidLocaleTag` already rejects those characters.
  if (tag.startsWith('.')) return false;
  // allow underscore in filenames (Flutter convention), in addition to hyphen
  if (tag.contains(RegExp(r'[^A-Za-z0-9_\-]'))) return false;
  if (tag.contains('--')) return false;
  if (tag.startsWith('-') || tag.endsWith('-')) return false;

  // Windows-specific checks
  final fileBase = 'app_$tag';
  final upperTag = tag.toUpperCase();
  final upperBase = fileBase.toUpperCase();
  final reserved = <String>{
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };
  if (reserved.contains(upperTag) || reserved.contains(upperBase)) return false;
  if (fileBase.endsWith(' ') || fileBase.endsWith('.')) return false;

  return true;
}
