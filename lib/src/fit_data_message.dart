/// Data message containing actual field values.
library;

import 'developer_field.dart';
import 'fit_field.dart';
import 'fit_message.dart';
import 'fit_message_type.dart';

/// Data message with field values.
class FitDataMessage extends FitMessage {
  /// Standard fields in this message.
  final List<FitField> fields;

  /// Developer-defined fields in this message.
  final List<DeveloperField> developerFields;

  /// Timestamp for this message (if available).
  final DateTime? timestamp;

  const FitDataMessage({
    required super.localMessageNumber,
    required super.globalMessageNumber,
    required this.fields,
    this.developerFields = const [],
    this.timestamp,
  }) : super(isDefinition: false);

  @override
  String? get messageName => FitMessageType.getName(globalMessageNumber ?? -1);

  /// Get a field value by field number.
  dynamic getFieldByNumber(int fieldNumber) {
    for (final field in fields) {
      if (field.fieldNumber == fieldNumber) {
        return field.scaledValue;
      }
    }
    return null;
  }

  /// Get a field value by name.
  dynamic getField(String name) {
    for (final field in fields) {
      if (field.name == name) {
        return field.scaledValue;
      }
    }
    return null;
  }

  /// Get a developer field value by field number.
  dynamic getDeveloperFieldByNumber(int fieldNumber) {
    for (final devField in developerFields) {
      if (devField.fieldNumber == fieldNumber) {
        return devField.scaledValue;
      }
    }
    return null;
  }

  /// Get a developer field value by name.
  dynamic getDeveloperField(String name) {
    for (final devField in developerFields) {
      if (devField.name == name) {
        return devField.scaledValue;
      }
    }
    return null;
  }

  /// Get all field names and values as a map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    // Add standard fields
    for (final field in fields) {
      if (field.isValid && field.name != null) {
        map[field.name!] = field.scaledValue;
      }
    }

    // Add developer fields
    for (final devField in developerFields) {
      if (devField.name != null) {
        map[devField.name!] = devField.scaledValue;
      }
    }

    return map;
  }

  /// Check if this is a record message (GPS data, HR, power, etc.).
  bool get isRecord => globalMessageNumber == FitMessageType.record;

  /// Check if this is a lap message.
  bool get isLap => globalMessageNumber == FitMessageType.lap;

  /// Check if this is a session message.
  bool get isSession => globalMessageNumber == FitMessageType.session;

  @override
  String toString() {
    final name = messageName ?? 'unknown';
    return 'FitDataMessage('
        'local=$localMessageNumber, '
        'global=$globalMessageNumber ($name), '
        'fields=${fields.length}, '
        'devFields=${developerFields.length}'
        ')';
  }
}
