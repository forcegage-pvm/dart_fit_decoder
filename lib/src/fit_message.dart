/// Base class for FIT messages (definition and data).
library;

/// Base class for all FIT message types.
abstract class FitMessage {
  /// Local message number (0-15).
  final int localMessageNumber;

  /// Whether this is a definition message (true) or data message (false).
  final bool isDefinition;

  /// Global message number (type).
  final int? globalMessageNumber;

  const FitMessage({
    required this.localMessageNumber,
    required this.isDefinition,
    this.globalMessageNumber,
  });

  /// Get message type name.
  String? get messageName;

  @override
  String toString();
}
