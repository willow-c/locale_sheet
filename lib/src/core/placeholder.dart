import 'package:meta/meta.dart';

/// Metadata describing a placeholder used inside a localized message.
@immutable
class Placeholder {
  /// Creates a [Placeholder].
  const Placeholder({required this.type, this.example, this.source});

  /// Constructs a [Placeholder] from a decoded map (e.g. from ARB metadata).
  factory Placeholder.fromMap(Map<String, dynamic> m) => Placeholder(
    type: m['type']?.toString() ?? 'String',
    example: m['example']?.toString(),
    source: m['source']?.toString(),
  );

  /// The declared type of the placeholder (e.g. `String`, `int`).
  final String type;

  /// Optional example value for documentation purposes.
  final String? example;

  /// Source of the placeholder (e.g. `declared` or `detected`).
  final String? source;

  /// Convert to a map suitable for embedding in ARB `@<key>` metadata.
  Map<String, Object?> toMap() => {
    'type': type,
    if (example != null) 'example': example,
    if (source != null) 'source': source,
  };

  @override
  bool operator ==(Object other) {
    return other is Placeholder &&
        other.type == type &&
        other.example == example &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(type, example, source);
}
