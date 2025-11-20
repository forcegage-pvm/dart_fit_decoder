/// Represents a single field in a FIT message.
library;

import 'fit_base_type.dart';

/// A field within a FIT data message.
class FitField {
  /// Field definition number.
  final int fieldNumber;
  
  /// Field name (if known).
  final String? name;
  
  /// Base type of the field.
  final FitBaseType baseType;
  
  /// Raw field value.
  final dynamic value;
  
  /// Scale factor for numeric values.
  final double? scale;
  
  /// Offset for numeric values.
  final double? offset;
  
  /// Units for the field.
  final String? units;
  
  const FitField({
    required this.fieldNumber,
    this.name,
    required this.baseType,
    required this.value,
    this.scale,
    this.offset,
    this.units,
  });
  
  /// Get the scaled value (applies scale and offset).
  dynamic get scaledValue {
    if (value == null || value == baseType.invalidValue) {
      return null;
    }
    
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
  
  /// Check if field value is valid (not the invalid marker).
  bool get isValid {
    if (value == null) return false;
    if (baseType.invalidValue == null) return true;
    return value != baseType.invalidValue;
  }
  
  @override
  String toString() {
    final displayName = name ?? 'field_$fieldNumber';
    final displayValue = scaledValue ?? 'invalid';
    final unitStr = units != null ? ' $units' : '';
    return '$displayName: $displayValue$unitStr';
  }
}
