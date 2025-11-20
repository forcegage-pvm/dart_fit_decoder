/// Definition message that maps local message numbers to global message types.
library;

import 'fit_base_type.dart';
import 'fit_message.dart';
import 'fit_message_type.dart';

/// Field definition within a definition message.
class FieldDefinition {
  final int fieldNumber;
  final int size;
  final int baseTypeId;

  const FieldDefinition({
    required this.fieldNumber,
    required this.size,
    required this.baseTypeId,
  });

  FitBaseType? get baseType => FitBaseTypes.getById(baseTypeId);

  @override
  String toString() => 'FieldDef(num=$fieldNumber, size=$size, type=$baseTypeId)';
}

/// Developer field definition.
class DeveloperFieldDefinition {
  final int fieldNumber;
  final int size;
  final int developerDataIndex;

  const DeveloperFieldDefinition({
    required this.fieldNumber,
    required this.size,
    required this.developerDataIndex,
  });

  @override
  String toString() => 'DevFieldDef(num=$fieldNumber, size=$size, devIdx=$developerDataIndex)';
}

/// Definition message that defines the structure of data messages.
class FitDefinitionMessage extends FitMessage {
  /// Architecture (0 = little-endian, 1 = big-endian).
  final int architecture;

  /// Field definitions for standard fields.
  final List<FieldDefinition> fieldDefinitions;

  /// Developer field definitions.
  final List<DeveloperFieldDefinition> developerFieldDefinitions;

  const FitDefinitionMessage({
    required super.localMessageNumber,
    required super.globalMessageNumber,
    required this.architecture,
    required this.fieldDefinitions,
    this.developerFieldDefinitions = const [],
  }) : super(isDefinition: true);

  /// Check if architecture is little-endian.
  bool get isLittleEndian => architecture == 0;

  /// Check if architecture is big-endian.
  bool get isBigEndian => architecture == 1;

  /// Get total size of all fields in bytes.
  int get totalFieldSize {
    int size = 0;
    for (final field in fieldDefinitions) {
      size += field.size;
    }
    for (final devField in developerFieldDefinitions) {
      size += devField.size;
    }
    return size;
  }

  @override
  String? get messageName => FitMessageType.getName(globalMessageNumber ?? -1);

  @override
  String toString() {
    final name = messageName ?? 'unknown';
    return 'FitDefinitionMessage('
        'local=$localMessageNumber, '
        'global=$globalMessageNumber ($name), '
        'arch=${isLittleEndian ? "LE" : "BE"}, '
        'fields=${fieldDefinitions.length}, '
        'devFields=${developerFieldDefinitions.length}'
        ')';
  }
}
