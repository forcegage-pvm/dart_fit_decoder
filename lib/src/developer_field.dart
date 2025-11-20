/// Represents a developer-defined field in a FIT message.
library;

/// A custom field defined by a developer or manufacturer.
class DeveloperField {
  /// Developer field number (0-255).
  final int fieldNumber;
  
  /// Field name from field_description message.
  final String? name;
  
  /// Developer data index.
  final int developerDataIndex;
  
  /// Base type ID.
  final int baseTypeId;
  
  /// Field value.
  final dynamic value;
  
  /// Units for the field.
  final String? units;
  
  /// Scale factor.
  final double? scale;
  
  /// Offset value.
  final double? offset;
  
  const DeveloperField({
    required this.fieldNumber,
    this.name,
    required this.developerDataIndex,
    required this.baseTypeId,
    required this.value,
    this.units,
    this.scale,
    this.offset,
  });
  
  /// Get the scaled value (applies scale and offset).
  dynamic get scaledValue {
    if (value == null) return null;
    
    if (scale == null && offset == null) {
      return value;
    }
    
    if (value is num) {
      double result = value.toDouble();
      if (scale != null) result = result / scale!;
      if (offset != null) result = result - offset!;
      return result;
    }
    
    return value;
  }
  
  @override
  String toString() {
    final displayName = name ?? 'dev_field_$fieldNumber';
    final displayValue = scaledValue ?? 'null';
    final unitStr = units != null ? ' $units' : '';
    return '$displayName: $displayValue$unitStr';
  }
}
