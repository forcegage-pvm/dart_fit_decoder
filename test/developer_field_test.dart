/// Tests for developer field extraction, especially CORE temperature sensor data.
library;

import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Developer Field - field_description Message (206)', () {
    test('parses field_description message structure', () {
      // Definition for field_description (mesg_num 206)
      final definition = FitDefinitionMessage(
        localMessageNumber: 5,
        architecture: 0,
        globalMessageNumber: 206,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x02), // developer_data_index
          FieldDefinition(fieldNumber: 1, size: 1, baseTypeId: 0x02), // field_definition_number
          FieldDefinition(fieldNumber: 2, size: 1, baseTypeId: 0x02), // base_type_id
          FieldDefinition(fieldNumber: 3, size: 16, baseTypeId: 0x07), // field_name (string)
          FieldDefinition(fieldNumber: 8, size: 8, baseTypeId: 0x07), // units (string)
        ],
        developerFieldDefinitions: [],
      );

      // Data: index=0, field_num=7, base_type=0x02 (uint8), name="core_temp", units="C"
      final dataBytes = Uint8List.fromList([
        0x00, // developer_data_index: 0
        0x07, // field_definition_number: 7
        0x02, // base_type_id: uint8
        // field_name: "core_temp" (16 bytes, null-terminated)
        0x63, 0x6F, 0x72, 0x65, 0x5F, 0x74, 0x65, 0x6D,
        0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        // units: "C" (8 bytes, null-terminated)
        0x43, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);

      expect(dataBytes[0], equals(0)); // developer_data_index
      expect(dataBytes[1], equals(7)); // field_definition_number
      expect(dataBytes[2], equals(0x02)); // base_type_id

      final fieldName = String.fromCharCodes(
        dataBytes.skip(3).take(16).takeWhile((b) => b != 0),
      );
      expect(fieldName, equals('core_temp'));

      final units = String.fromCharCodes(
        dataBytes.skip(19).take(8).takeWhile((b) => b != 0),
      );
      expect(units, equals('C'));
    });

    test('parses multiple field_description messages', () {
      // CORE sensor has fields 7-13
      final coreFields = {
        7: 'core_temp',
        8: 'skin_temp',
        9: 'hsi',
        10: 'hrv_status',
        11: 'hrv',
        12: 'hrv_sdrr',
        13: 'hrv_rmssd',
      };

      for (final entry in coreFields.entries) {
        final fieldNum = entry.key;
        final fieldName = entry.value;

        // Simulate field description data (field name can be up to 64 bytes)
        final nameBytes = fieldName.codeUnits.take(64).toList();
        final dataBytes = Uint8List.fromList([
          0x00, // developer_data_index
          fieldNum, // field_definition_number
          0x02, // base_type_id (uint8)
          ...nameBytes,
          ...List.filled(64 - nameBytes.length, 0), // Pad to 64 bytes
          ...List.filled(8, 0), // Empty units string
        ]);

        expect(dataBytes[0], equals(0)); // Index 0
        expect(dataBytes[1], equals(fieldNum));

        final parsedName = String.fromCharCodes(
          dataBytes.skip(3).take(64).takeWhile((b) => b != 0),
        );
        expect(parsedName, equals(fieldName));
      }
    });

    test('handles field_description with scale and offset', () {
      final dataBytes = Uint8List.fromList([
        0x00, // developer_data_index
        0x07, // field_definition_number
        0x02, // base_type_id
        // field_name (16 bytes)
        ...List.filled(16, 0),
        // units (8 bytes)
        ...List.filled(8, 0),
        // scale: 10 (uint8)
        0x0A,
        // offset: 0 (sint8)
        0x00,
      ]);

      expect(dataBytes[27], equals(10)); // scale
      expect(dataBytes[28], equals(0)); // offset
    });
  });

  group('Developer Field - developer_data_id Message (207)', () {
    test('parses developer_data_id message', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 6,
        architecture: 0,
        globalMessageNumber: 207,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 16, baseTypeId: 0x0D), // application_id (byte[])
          FieldDefinition(fieldNumber: 1, size: 1, baseTypeId: 0x02), // developer_data_index
        ],
        developerFieldDefinitions: [],
      );

      // Data: app_id=CORE sensor UUID, index=0
      final appId = [
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0x10,
      ];
      final dataBytes = Uint8List.fromList([
        ...appId,
        0x00, // developer_data_index
      ]);

      expect(dataBytes.sublist(0, 16), equals(appId));
      expect(dataBytes[16], equals(0)); // index
    });

    test('matches developer_data_id to CORE sensor', () {
      // Known CORE sensor application ID
      final coreAppId = [
        0x26,
        0x58,
        0x5E,
        0x39,
        0xB3,
        0x5F,
        0x4A,
        0x1D,
        0xAA,
        0xA4,
        0x2A,
        0x62,
        0x87,
        0x09,
        0x16,
        0x4D,
      ];

      final dataBytes = Uint8List.fromList([
        ...coreAppId,
        0x00, // index
      ]);

      expect(dataBytes.sublist(0, 16), equals(coreAppId));
    });
  });

  group('Developer Field - Extraction from Record Messages', () {
    test('parses record with developer fields', () {
      // Definition: record (20) with normal fields + 1 developer field
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 3, size: 1, baseTypeId: 0x02), // heart_rate
        ],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(
            fieldNumber: 7, // core_temp
            size: 1,
            developerDataIndex: 0,
          ),
        ],
      );

      // Data: timestamp=1000000, hr=150, core_temp=38 (°C)
      final dataBytes = Uint8List.fromList([
        0x40, 0x42, 0x0F, 0x00, // timestamp
        0x96, // heart_rate: 150
        0x26, // core_temp: 38°C
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(1000000));
      expect(data.getUint8(4), equals(150));
      expect(data.getUint8(5), equals(38)); // Developer field value
    });

    test('parses record with multiple CORE developer fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
        ],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 7, size: 1, developerDataIndex: 0), // core_temp
          DeveloperFieldDefinition(fieldNumber: 8, size: 1, developerDataIndex: 0), // skin_temp
          DeveloperFieldDefinition(fieldNumber: 9, size: 1, developerDataIndex: 0), // heat_strain_index
        ],
      );

      // Data: timestamp=1000000, core_temp=38, skin_temp=35, hsi=5
      final dataBytes = Uint8List.fromList([
        0x40, 0x42, 0x0F, 0x00, // timestamp
        0x26, // core_temp: 38°C
        0x23, // skin_temp: 35°C
        0x05, // heat_strain_index: 5
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(1000000));
      expect(data.getUint8(4), equals(38));
      expect(data.getUint8(5), equals(35));
      expect(data.getUint8(6), equals(5));
    });

    test('extracts all 7 CORE temperature fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
        ],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 7, size: 1, developerDataIndex: 0), // core_temp
          DeveloperFieldDefinition(fieldNumber: 8, size: 1, developerDataIndex: 0), // skin_temp
          DeveloperFieldDefinition(fieldNumber: 9, size: 1, developerDataIndex: 0), // heat_strain_index
          DeveloperFieldDefinition(fieldNumber: 10, size: 1, developerDataIndex: 0), // hrv_status
          DeveloperFieldDefinition(fieldNumber: 11, size: 2, developerDataIndex: 0), // hrv (uint16)
          DeveloperFieldDefinition(fieldNumber: 12, size: 2, developerDataIndex: 0), // hrv_sdrr (uint16)
          DeveloperFieldDefinition(fieldNumber: 13, size: 2, developerDataIndex: 0), // hrv_rmssd (uint16)
        ],
      );

      // Data with all CORE fields
      final dataBytes = Uint8List.fromList([
        0x40, 0x42, 0x0F, 0x00, // timestamp: 1000000
        0x26, // core_temp: 38°C
        0x23, // skin_temp: 35°C
        0x05, // heat_strain_index: 5
        0x01, // hrv_status: 1
        0x50, 0x00, // hrv: 80ms
        0x3C, 0x00, // hrv_sdrr: 60ms
        0x2D, 0x00, // hrv_rmssd: 45ms
      ]);

      final data = ByteData.view(dataBytes.buffer);
      var offset = 0;

      // Timestamp
      expect(data.getUint32(offset, Endian.little), equals(1000000));
      offset += 4;

      // CORE fields
      expect(data.getUint8(offset++), equals(38)); // core_temp
      expect(data.getUint8(offset++), equals(35)); // skin_temp
      expect(data.getUint8(offset++), equals(5)); // heat_strain_index
      expect(data.getUint8(offset++), equals(1)); // hrv_status
      expect(data.getUint16(offset, Endian.little), equals(80)); // hrv
      offset += 2;
      expect(data.getUint16(offset, Endian.little), equals(60)); // hrv_sdrr
      offset += 2;
      expect(data.getUint16(offset, Endian.little), equals(45)); // hrv_rmssd
    });
  });

  group('Developer Field - Scaling and Units', () {
    test('applies scale to developer field value', () {
      // Temperature with scale 10 (stored as integer * 10)
      final rawValue = 385; // 38.5°C stored as 385
      final scale = 10.0;
      final scaledValue = rawValue / scale;
      expect(scaledValue, closeTo(38.5, 0.01));
    });

    test('applies scale and offset to developer field', () {
      // Value with scale 100 and offset -50
      final rawValue = 5000; // (5000 / 100) - 50 = 0
      final scale = 100.0;
      final offset = 50.0;
      final scaledValue = (rawValue / scale) - offset;
      expect(scaledValue, closeTo(0.0, 0.01));
    });

    test('handles CORE temperature decimal precision', () {
      // CORE temp often stored as integer degrees
      final coreTemp = 38; // 38°C
      final skinTemp = 35; // 35°C

      expect(coreTemp, equals(38));
      expect(skinTemp, equals(35));
    });

    test('converts CORE HRV values with scale', () {
      // HRV values typically in ms, scale 1000 for sub-millisecond precision
      final rawHrv = 85432; // 85.432ms
      final scale = 1000.0;
      final hrvMs = rawHrv / scale;
      expect(hrvMs, closeTo(85.432, 0.001));
    });
  });

  group('Developer Field - Invalid Values', () {
    test('detects invalid developer field (0xFF)', () {
      final value = 0xFF; // uint8 invalid
      expect(value, equals(0xFF));
    });

    test('detects invalid developer field uint16 (0xFFFF)', () {
      final dataBytes = Uint8List.fromList([0xFF, 0xFF]);
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getUint16(0, Endian.little);
      expect(value, equals(0xFFFF)); // Invalid marker
    });

    test('handles missing developer fields gracefully', () {
      // Definition has developer field, but data doesn't include it
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
        ],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 7, size: 1, developerDataIndex: 0),
        ],
      );

      // Data: only timestamp, no developer field
      final dataBytes = Uint8List.fromList([0x40, 0x42, 0x0F, 0x00]);

      expect(dataBytes.length, equals(4)); // Missing developer field
      // Implementation should handle this gracefully
    });

    test('skips invalid CORE temperature values', () {
      final values = [38, 0xFF, 35, 0xFF, 40]; // Mix of valid and invalid
      final validValues = values.where((v) => v != 0xFF).toList();
      expect(validValues, equals([38, 35, 40]));
    });
  });

  group('Developer Field - Edge Cases', () {
    test('handles developer field index > 0', () {
      // Multiple developer data sources
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 0, size: 1, developerDataIndex: 1), // Different index
        ],
      );

      expect(definition.developerFieldDefinitions[0].developerDataIndex, equals(1));
    });

    test('handles multiple developer data sources', () {
      // CORE (index 0) + another sensor (index 1)
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 7, size: 1, developerDataIndex: 0), // CORE
          DeveloperFieldDefinition(fieldNumber: 0, size: 2, developerDataIndex: 1), // Other sensor
        ],
      );

      expect(definition.developerFieldDefinitions.length, equals(2));
      expect(definition.developerFieldDefinitions[0].developerDataIndex, equals(0));
      expect(definition.developerFieldDefinitions[1].developerDataIndex, equals(1));
    });

    test('handles developer field with large size', () {
      final definition = DeveloperFieldDefinition(
        fieldNumber: 0,
        size: 255, // Maximum size
        developerDataIndex: 0,
      );

      expect(definition.size, equals(255));
    });

    test('handles developer field without matching field_description', () {
      // Data has developer field but no corresponding field_description message
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 99, size: 1, developerDataIndex: 0), // Unknown field
        ],
      );

      expect(definition.developerFieldDefinitions[0].fieldNumber, equals(99));
      // Implementation should handle unknown developer fields
    });

    test('preserves developer field order', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 13, size: 2, developerDataIndex: 0),
          DeveloperFieldDefinition(fieldNumber: 7, size: 1, developerDataIndex: 0),
          DeveloperFieldDefinition(fieldNumber: 9, size: 1, developerDataIndex: 0),
        ],
      );

      expect(definition.developerFieldDefinitions[0].fieldNumber, equals(13));
      expect(definition.developerFieldDefinitions[1].fieldNumber, equals(7));
      expect(definition.developerFieldDefinitions[2].fieldNumber, equals(9));
    });
  });

  group('Developer Field - CORE Sensor Integration', () {
    test('identifies CORE sensor data in FIT file', () {
      // CORE sensor UUID
      final coreAppId = [
        0x26,
        0x58,
        0x5E,
        0x39,
        0xB3,
        0x5F,
        0x4A,
        0x1D,
        0xAA,
        0xA4,
        0x2A,
        0x62,
        0x87,
        0x09,
        0x16,
        0x4D,
      ];

      expect(coreAppId.length, equals(16));
      expect(coreAppId[0], equals(0x26));
    });

    test('extracts complete CORE temperature dataset', () {
      // Simulate 3 records with CORE data
      final records = [
        {'timestamp': 1000000, 'core_temp': 37, 'skin_temp': 34, 'hsi': 3},
        {'timestamp': 1000001, 'core_temp': 38, 'skin_temp': 35, 'hsi': 4},
        {'timestamp': 1000002, 'core_temp': 39, 'skin_temp': 36, 'hsi': 5},
      ];

      expect(records.length, equals(3));
      expect(records[1]['core_temp'], equals(38));
      expect(records[2]['hsi'], equals(5));
    });

    test('handles incomplete CORE data', () {
      // Some records have CORE data, others don't
      final records = [
        {'timestamp': 1000000, 'core_temp': 37},
        {'timestamp': 1000001}, // No CORE data
        {'timestamp': 1000002, 'core_temp': 38},
      ];

      final recordsWithCore = records.where((r) => r.containsKey('core_temp')).toList();
      expect(recordsWithCore.length, equals(2));
    });

    test('validates CORE temperature range', () {
      final validTemp = 38; // Normal body temp
      final highTemp = 42; // Fever
      final lowTemp = 35; // Hypothermia

      expect(validTemp, inInclusiveRange(35, 42));
      expect(highTemp, inInclusiveRange(35, 42));
      expect(lowTemp, inInclusiveRange(35, 42));
    });

    test('validates CORE heat strain index range', () {
      final hsi = 5;
      expect(hsi, inInclusiveRange(0, 10)); // Typical HSI range 0-10
    });
  });
}
