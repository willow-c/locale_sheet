// Utility to detect named placeholders like {name} in message strings.
// Respects escaping via double braces (e.g. `{{` / `}}`).
/// Returns the set of placeholder names found in [message]. Uses a simple
/// identifier pattern by default but it can be overridden via [nameRegex].
Set<String> detectPlaceholders(
  String message, {
  String nameRegex = '[A-Za-z_][A-Za-z0-9_]*',
}) {
  if (message.isEmpty) return <String>{};

  // Temporarily mask escaped double-braces so they are not treated as
  // placeholders.
  final masked = message
      .replaceAll('{{', '<<LBRACE>>')
      .replaceAll('}}', '<<RBRACE>>');

  final pattern = RegExp(r'\{(' + nameRegex + r')\}');
  final matches = pattern.allMatches(masked);
  final result = <String>{};
  for (final m in matches) {
    if (m.groupCount >= 1) {
      final name = m.group(1);
      if (name != null && name.isNotEmpty) result.add(name);
    }
  }

  return result;
}
