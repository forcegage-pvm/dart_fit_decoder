/// Custom exceptions for FIT file parsing errors.
library;

/// Base exception for all FIT decoder errors.
class FitDecoderException implements Exception {
  final String message;
  
  FitDecoderException(this.message);
  
  @override
  String toString() => 'FitDecoderException: $message';
}

/// Exception thrown when FIT file header is invalid.
class InvalidHeaderException extends FitDecoderException {
  InvalidHeaderException(super.message);
  
  @override
  String toString() => 'InvalidHeaderException: $message';
}

/// Exception thrown when CRC validation fails.
class InvalidCrcException extends FitDecoderException {
  InvalidCrcException(super.message);
  
  @override
  String toString() => 'InvalidCrcException: $message';
}

/// Exception thrown when message definition is not found.
class MissingDefinitionException extends FitDecoderException {
  final int localMessageNumber;
  
  MissingDefinitionException(this.localMessageNumber)
      : super('No definition found for local message number $localMessageNumber');
  
  @override
  String toString() => 'MissingDefinitionException: $message';
}

/// Exception thrown when field parsing fails.
class FieldParseException extends FitDecoderException {
  final String fieldName;
  
  FieldParseException(this.fieldName, String reason)
      : super('Failed to parse field "$fieldName": $reason');
  
  @override
  String toString() => 'FieldParseException: $message';
}

/// Exception thrown when binary data is insufficient.
class InsufficientDataException extends FitDecoderException {
  final int required;
  final int available;
  
  InsufficientDataException(this.required, this.available)
      : super('Required $required bytes, but only $available available');
  
  @override
  String toString() => 'InsufficientDataException: $message';
}
