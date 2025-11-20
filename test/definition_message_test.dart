/// Tests for definition message parsing.
library;

import 'dart:typed_data';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Definition Message - Basic Structure', () {
    test('parses simple definition message without developer fields', () {
      final bytes = Uint8List.fromList([
        0x40, // Header: definition message, local type 0
        0x00, // Reserved
        0x00, // Architecture: 0 = little-endian
        0x00, 0x00, // Global message number: 0 (file_id)
        0x04, // Number of fields: 4
        // Field 1: type (field 0, size 1, base type enum)
        0x00, 0x01, 0x00,
        // Field 2: manufacturer (field 1, size 2, base type uint16)
        0x01, 0x02, 0x84,
        // Field 3: product (field 2, size 2, base type uint16)
        0x02, 0x02, 0x84,
        // Field 4: serial_number (field 3, size 4, base type uint32z)
        0x03, 0x04, 0x8C,
      ]);

      // Parse header
      final headerByte = bytes[0];
      final isDefinition = (headerByte & 0x40) != 0;
      final localMessageType = headerByte & 0x0F;

      expect(isDefinition, isTrue);
      expect(localMessageType, equals(0));

      // Parse definition
      final reserved = bytes[1];
      final architecture = bytes[2];
      final data = ByteData.view(bytes.buffer, bytes.offsetInBytes);
      final globalMessageNumber = data.getUint16(3, Endian.little);
      final numFields = bytes[5];

      expect(reserved, equals(0x00));
      expect(architecture, equals(0)); // Little-endian
      expect(globalMessageNumber, equals(0)); // file_id
      expect(numFields, equals(4));

      // Parse field definitions
      int offset = 6;
      final fields = <FieldDefinition>[];
      for (int i = 0; i < numFields; i++) {
        final fieldNum = bytes[offset];
        final size = bytes[offset + 1];
        final baseType = bytes[offset + 2];
        fields.add(FieldDefinition(
          fieldNumber: fieldNum,
          size: size,
          baseTypeId: baseType,
        ));
        offset += 3;
      }

      expect(fields.length, equals(4));
      expect(fields[0].fieldNumber, equals(0));
      expect(fields[0].size, equals(1));
      expect(fields[0].baseTypeId, equals(0x00)); // enum

      expect(fields[3].fieldNumber, equals(3));
      expect(fields[3].size, equals(4));
      expect(fields[3].baseTypeId, equals(0x8C)); // uint32z
    });

    test('parses definition message with big-endian architecture', () {
      final bytes = Uint8List.fromList([
        0x41, // Header: definition message, local type 1
        0x00, // Reserved
        0x01, // Architecture: 1 = big-endian
        0x00, 0x14, // Global message number: 20 (record) - big-endian
        0x02, // Number of fields: 2
        // Field 1
        0xFD, 0x04, 0x86, // timestamp (253, 4 bytes, uint32)
        // Field 2
        0x00, 0x02, 0x84, // heart_rate (0, 2 bytes, uint16)
      ]);

      final architecture = bytes[2];
      expect(architecture, equals(1)); // Big-endian

      final data = ByteData.view(bytes.buffer, bytes.offsetInBytes);
      final globalMessageNumber = data.getUint16(3, Endian.big);
      expect(globalMessageNumber, equals(20)); // record
    });

    test('parses definition message with developer fields', () {
      final bytes = Uint8List.fromList([
        0x60, // Header: definition with developer data, local type 0
        0x00, // Reserved
        0x00, // Architecture: little-endian
        0x14, 0x00, // Global message number: 20 (record)
        0x02, // Number of standard fields: 2
        // Standard fields
        0xFD, 0x04, 0x86, // timestamp
        0x00, 0x01, 0x02, // heart_rate
        0x02, // Number of developer fields: 2
        // Developer field 1
        0x07, 0x04, 0x00, // field 7, 4 bytes, dev data index 0
        // Developer field 2
        0x08, 0x04, 0x00, // field 8, 4 bytes, dev data index 0
      ]);

      final headerByte = bytes[0];
      final hasDeveloperData = (headerByte & 0x20) != 0;
      expect(hasDeveloperData, isTrue);

      final numFields = bytes[5];
      expect(numFields, equals(2));

      // Calculate offset to developer fields
      int offset = 6 + (numFields * 3); // After standard fields
      final numDevFields = bytes[offset];
      expect(numDevFields, equals(2));

      // Parse developer fields
      offset++;
      final devFields = <DeveloperFieldDefinition>[];
      for (int i = 0; i < numDevFields; i++) {
        final fieldNum = bytes[offset];
        final size = bytes[offset + 1];
        final devDataIndex = bytes[offset + 2];
        devFields.add(DeveloperFieldDefinition(
          fieldNumber: fieldNum,
          size: size,
          developerDataIndex: devDataIndex,
        ));
        offset += 3;
      }

      expect(devFields.length, equals(2));
      expect(devFields[0].fieldNumber, equals(7)); // CORE temperature
      expect(devFields[0].size, equals(4));
      expect(devFields[1].fieldNumber, equals(8)); // CORE skin temp
    });
  });

  group('Definition Message - Field Types', () {
    test('defines all standard FIT base types', () {
      final baseTypes = [
        0x00, // enum
        0x01, // sint8
        0x02, // uint8
        0x83, // sint16
        0x84, // uint16
        0x85, // sint32
        0x86, // uint32
        0x07, // string
        0x88, // float32
        0x89, // float64
        0x0A, // uint8z
        0x8B, // uint16z
        0x8C, // uint32z
        0x0D, // byte
      ];

      for (final baseType in baseTypes) {
        final fitBaseType = FitBaseTypes.getById(baseType);
        expect(fitBaseType, isNotNull, reason: 'Base type 0x${baseType.toRadixString(16)} should exist');
      }
    });

    test('calculates total message size from field definitions', () {
      final fields = [
        FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x00), // 1 byte
        FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // 2 bytes
        FieldDefinition(fieldNumber: 2, size: 4, baseTypeId: 0x86), // 4 bytes
        FieldDefinition(fieldNumber: 3, size: 8, baseTypeId: 0x89), // 8 bytes
      ];

      int totalSize = 0;
      for (final field in fields) {
        totalSize += field.size;
      }

      expect(totalSize, equals(15)); // 1 + 2 + 4 + 8
    });

    test('handles variable-length string fields', () {
      final field = FieldDefinition(
        fieldNumber: 5,
        size: 16, // String field with 16-byte buffer
        baseTypeId: 0x07, // string
      );

      expect(field.size, equals(16));
      expect(field.baseType?.isString, isTrue);
    });

    test('handles byte array fields', () {
      final field = FieldDefinition(
        fieldNumber: 10,
        size: 32, // 32-byte array
        baseTypeId: 0x0D, // byte
      );

      expect(field.size, equals(32));
      expect(field.baseTypeId, equals(0x0D));
    });
  });

  group('Definition Message - Multiple Local Types', () {
    test('supports 16 different local message types', () {
      for (int localType = 0; localType <= 15; localType++) {
        final headerByte = 0x40 | localType; // Definition message
        final parsedType = headerByte & 0x0F;
        expect(parsedType, equals(localType));
      }
    });

    test('maps different local types to same global type', () {
      // Common pattern: local type 0 for file_id, local type 1 for record
      final definitions = {
        0: 0, // local 0 -> file_id (global 0)
        1: 20, // local 1 -> record (global 20)
        2: 19, // local 2 -> lap (global 19)
        3: 18, // local 3 -> session (global 18)
      };

      for (final entry in definitions.entries) {
        final localType = entry.key;
        final globalType = entry.value;
        expect(globalType, isNotNull);
        expect(localType, inInclusiveRange(0, 15));
      }
    });

    test('redefines local message type with new structure', () {
      // First definition: local type 0 with 2 fields
      final def1 = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 20,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x02),
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84),
        ],
      );

      expect(def1.fieldDefinitions.length, equals(2));
      expect(def1.totalFieldSize, equals(3));

      // Redefinition: local type 0 with 3 fields
      final def2 = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 20,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x02),
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84),
          FieldDefinition(fieldNumber: 2, size: 4, baseTypeId: 0x86),
        ],
      );

      expect(def2.fieldDefinitions.length, equals(3));
      expect(def2.totalFieldSize, equals(7));
    });
  });

  group('Definition Message - Common Message Types', () {
    test('defines file_id message (global 0)', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 0,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x00), // type
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // manufacturer
          FieldDefinition(fieldNumber: 2, size: 2, baseTypeId: 0x84), // product
          FieldDefinition(fieldNumber: 3, size: 4, baseTypeId: 0x8C), // serial_number
        ],
      );

      expect(definition.globalMessageNumber, equals(0));
      expect(definition.messageName, equals('file_id'));
      expect(definition.fieldDefinitions.length, equals(4));
    });

    test('defines record message (global 20)', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        globalMessageNumber: 20,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 0, size: 4, baseTypeId: 0x85), // position_lat
          FieldDefinition(fieldNumber: 1, size: 4, baseTypeId: 0x85), // position_long
          FieldDefinition(fieldNumber: 5, size: 2, baseTypeId: 0x84), // distance
          FieldDefinition(fieldNumber: 3, size: 1, baseTypeId: 0x02), // heart_rate
          FieldDefinition(fieldNumber: 7, size: 2, baseTypeId: 0x84), // power
        ],
      );

      expect(definition.globalMessageNumber, equals(20));
      expect(definition.messageName, equals('record'));
      expect(definition.fieldDefinitions.length, equals(6));
    });

    test('defines lap message (global 19)', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 2,
        globalMessageNumber: 19,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 7, size: 4, baseTypeId: 0x86), // total_elapsed_time
          FieldDefinition(fieldNumber: 9, size: 4, baseTypeId: 0x86), // total_distance
          FieldDefinition(fieldNumber: 13, size: 2, baseTypeId: 0x84), // avg_heart_rate
        ],
      );

      expect(definition.globalMessageNumber, equals(19));
      expect(definition.messageName, equals('lap'));
    });

    test('defines developer field description (global 206)', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 5,
        globalMessageNumber: 206,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x02), // developer_data_index
          FieldDefinition(fieldNumber: 1, size: 1, baseTypeId: 0x02), // field_definition_number
          FieldDefinition(fieldNumber: 2, size: 1, baseTypeId: 0x02), // fit_base_type_id
          FieldDefinition(fieldNumber: 3, size: 32, baseTypeId: 0x07), // field_name
        ],
      );

      expect(definition.globalMessageNumber, equals(206));
      expect(definition.messageName, equals('field_description'));
    });
  });

  group('Definition Message - Edge Cases', () {
    test('handles definition with zero fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 15,
        globalMessageNumber: 999,
        architecture: 0,
        fieldDefinitions: [],
      );

      expect(definition.fieldDefinitions.length, equals(0));
      expect(definition.totalFieldSize, equals(0));
    });

    test('handles definition with maximum fields (255)', () {
      final fields = List.generate(
        255,
        (i) => FieldDefinition(fieldNumber: i, size: 1, baseTypeId: 0x02),
      );

      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 20,
        architecture: 0,
        fieldDefinitions: fields,
      );

      expect(definition.fieldDefinitions.length, equals(255));
      expect(definition.totalFieldSize, equals(255));
    });

    test('handles large field sizes', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 20,
        architecture: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 255, baseTypeId: 0x07), // Large string
        ],
      );

      expect(definition.totalFieldSize, equals(255));
    });

    test('validates architecture byte', () {
      final littleEndian = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 0,
        architecture: 0,
        fieldDefinitions: [],
      );

      final bigEndian = FitDefinitionMessage(
        localMessageNumber: 0,
        globalMessageNumber: 0,
        architecture: 1,
        fieldDefinitions: [],
      );

      expect(littleEndian.isLittleEndian, isTrue);
      expect(littleEndian.isBigEndian, isFalse);
      expect(bigEndian.isLittleEndian, isFalse);
      expect(bigEndian.isBigEndian, isTrue);
    });
  });
}
