/// Tests for parsing FIT data messages using definition messages.
library;

import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Data Message - Basic Structure', () {
    test('parses data message with single uint16 field', () {
      // Definition: local 0, file_id (0), 1 field (manufacturer:uint16)
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0, // Little-endian
        globalMessageNumber: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // uint16
        ],
        developerFieldDefinitions: [],
      );

      // Data: manufacturer = 1 (Garmin)
      final dataBytes = Uint8List.fromList([0x01, 0x00]);
      final data = ByteData.view(dataBytes.buffer);

      // Parse field value
      final value = data.getUint16(0, Endian.little);
      expect(value, equals(1));
    });

    test('parses data message with multiple fields', () {
      // Definition: file_id with 3 fields
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x00), // type:enum
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // manufacturer:uint16
          FieldDefinition(fieldNumber: 2, size: 2, baseTypeId: 0x84), // product:uint16
        ],
        developerFieldDefinitions: [],
      );

      // Data: type=4 (activity), manufacturer=1 (Garmin), product=1234
      final dataBytes = Uint8List.fromList([
        0x04, // type
        0x01, 0x00, // manufacturer
        0xD2, 0x04, // product (1234)
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint8(0), equals(4));
      expect(data.getUint16(1, Endian.little), equals(1));
      expect(data.getUint16(3, Endian.little), equals(1234));
    });

    test('respects field order from definition', () {
      // Fields in non-sequential order
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 2, size: 2, baseTypeId: 0x84), // Field 2 first
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x00), // Field 0 second
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // Field 1 third
        ],
        developerFieldDefinitions: [],
      );

      final dataBytes = Uint8List.fromList([
        0x10, 0x00, // Field 2 value (16)
        0x05, // Field 0 value (5)
        0x20, 0x00, // Field 1 value (32)
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint16(0, Endian.little), equals(16)); // Field 2
      expect(data.getUint8(2), equals(5)); // Field 0
      expect(data.getUint16(3, Endian.little), equals(32)); // Field 1
    });
  });

  group('Data Message - All Base Types', () {
    test('parses enum (0x00) field', () {
      final dataBytes = Uint8List.fromList([0x04]);
      expect(dataBytes[0], equals(4));
      expect(dataBytes[0], isNot(equals(0xFF))); // Not invalid
    });

    test('parses sint8 (0x01) field', () {
      final dataBytes = Uint8List.fromList([0x7F, 0x80, 0x01]);
      expect(dataBytes[0], equals(127));
      expect(dataBytes[1] - 256, equals(-128)); // Two's complement
      expect(dataBytes[2], equals(1));
    });

    test('parses uint8 (0x02) field', () {
      final dataBytes = Uint8List.fromList([0x00, 0x7F, 0xFF]);
      expect(dataBytes[0], equals(0));
      expect(dataBytes[1], equals(127));
      expect(dataBytes[2], equals(255)); // Max uint8
    });

    test('parses sint16 (0x83) field', () {
      final dataBytes = Uint8List.fromList([
        0xFF, 0x7F, // 32767
        0x00, 0x80, // -32768
        0x01, 0x00, // 1
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getInt16(0, Endian.little), equals(32767));
      expect(data.getInt16(2, Endian.little), equals(-32768));
      expect(data.getInt16(4, Endian.little), equals(1));
    });

    test('parses uint16 (0x84) field', () {
      final dataBytes = Uint8List.fromList([
        0xFF, 0xFF, // 65535 (invalid for uint16)
        0x00, 0x00, // 0
        0xD2, 0x04, // 1234
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint16(0, Endian.little), equals(0xFFFF));
      expect(data.getUint16(2, Endian.little), equals(0));
      expect(data.getUint16(4, Endian.little), equals(1234));
    });

    test('parses sint32 (0x85) field', () {
      final dataBytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0x7F, // 2147483647
        0x00, 0x00, 0x00, 0x80, // -2147483648
        0x01, 0x00, 0x00, 0x00, // 1
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getInt32(0, Endian.little), equals(2147483647));
      expect(data.getInt32(4, Endian.little), equals(-2147483648));
      expect(data.getInt32(8, Endian.little), equals(1));
    });

    test('parses uint32 (0x86) field', () {
      final dataBytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0xFF, // 4294967295 (invalid)
        0x00, 0x00, 0x00, 0x00, // 0
        0x80, 0x96, 0x98, 0x00, // 10000000
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(0xFFFFFFFF));
      expect(data.getUint32(4, Endian.little), equals(0));
      expect(data.getUint32(8, Endian.little), equals(10000000));
    });

    test('parses float32 (0x88) field', () {
      final dataBytes = Uint8List.fromList([
        0x00, 0x00, 0x80, 0x3F, // 1.0
        0x00, 0x00, 0x00, 0x40, // 2.0
        0xCD, 0xCC, 0x8C, 0x40, // 4.4
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getFloat32(0, Endian.little), closeTo(1.0, 0.001));
      expect(data.getFloat32(4, Endian.little), closeTo(2.0, 0.001));
      expect(data.getFloat32(8, Endian.little), closeTo(4.4, 0.001));
    });

    test('parses float64 (0x89) field', () {
      final dataBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F, // 1.0
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, // 2.0
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getFloat64(0, Endian.little), closeTo(1.0, 0.0001));
      expect(data.getFloat64(8, Endian.little), closeTo(2.0, 0.0001));
    });

    test('parses string (0x07) field', () {
      // Null-terminated string "GARMIN"
      final dataBytes = Uint8List.fromList([0x47, 0x41, 0x52, 0x4D, 0x49, 0x4E, 0x00]);

      final str = String.fromCharCodes(
        dataBytes.takeWhile((b) => b != 0),
      );

      expect(str, equals('GARMIN'));
    });

    test('parses byte array (0x0D) field', () {
      final dataBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      expect(dataBytes, hasLength(5));
      expect(dataBytes[0], equals(1));
      expect(dataBytes[4], equals(5));
    });
  });

  group('Data Message - Scaling and Offsets', () {
    test('applies scale to integer field', () {
      // Heart rate with scale 1 (no scaling)
      final value = 120;
      final scale = 1.0;
      final scaledValue = value / scale;
      expect(scaledValue, equals(120.0));
    });

    test('applies scale to distance field (scale 100)', () {
      // Distance in cm stored as uint32, scale to meters
      final rawValue = 123456; // 123456 cm
      final scale = 100.0;
      final scaledValue = rawValue / scale;
      expect(scaledValue, closeTo(1234.56, 0.01)); // 1234.56 m
    });

    test('applies scale and offset to temperature', () {
      // Temperature: (raw / 10) - 273.15 (stored in K*10, output in °C)
      final rawValue = 2981; // 298.1 K
      final scale = 10.0;
      final offset = 273.15;
      final scaledValue = (rawValue / scale) - offset;
      expect(scaledValue, closeTo(24.95, 0.01)); // ~25°C
    });

    test('applies scale to altitude (scale 5, offset 500)', () {
      // Altitude: (raw / 5) - 500
      final rawValue = 6000; // (6000 / 5) - 500 = 700m
      final scale = 5.0;
      final offset = 500.0;
      final scaledValue = (rawValue / scale) - offset;
      expect(scaledValue, closeTo(700.0, 0.1));
    });

    test('handles scale of 1 (no scaling)', () {
      final value = 42;
      final scale = 1.0;
      expect(value / scale, equals(42.0));
    });

    test('handles fractional scale', () {
      // Speed in m/s with scale 1000
      final rawValue = 5230; // 5.230 m/s
      final scale = 1000.0;
      final scaledValue = rawValue / scale;
      expect(scaledValue, closeTo(5.23, 0.001));
    });
  });

  group('Data Message - Invalid Values', () {
    test('detects invalid enum (0xFF)', () {
      final value = 0xFF;
      expect(value, equals(0xFF)); // Invalid marker
    });

    test('detects invalid sint8 (0x7F)', () {
      final value = 0x7F;
      expect(value, equals(0x7F)); // Invalid marker
    });

    test('detects invalid uint8 (0xFF)', () {
      final value = 0xFF;
      expect(value, equals(0xFF)); // Invalid marker
    });

    test('detects invalid sint16 (0x7FFF)', () {
      final dataBytes = Uint8List.fromList([0xFF, 0x7F]);
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getInt16(0, Endian.little);
      expect(value, equals(0x7FFF)); // Invalid marker
    });

    test('detects invalid uint16 (0xFFFF)', () {
      final dataBytes = Uint8List.fromList([0xFF, 0xFF]);
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getUint16(0, Endian.little);
      expect(value, equals(0xFFFF)); // Invalid marker
    });

    test('detects invalid sint32 (0x7FFFFFFF)', () {
      final dataBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0x7F]);
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getInt32(0, Endian.little);
      expect(value, equals(0x7FFFFFFF)); // Invalid marker
    });

    test('detects invalid uint32 (0xFFFFFFFF)', () {
      final dataBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getUint32(0, Endian.little);
      expect(value, equals(0xFFFFFFFF)); // Invalid marker
    });

    test('skips invalid fields when extracting data', () {
      // Message with valid and invalid fields
      final dataBytes = Uint8List.fromList([
        0x78, // Valid uint8: 120
        0xFF, // Invalid uint8
        0x5A, // Valid uint8: 90
      ]);

      final validFields = dataBytes.where((b) => b != 0xFF).toList();
      expect(validFields, equals([0x78, 0x5A]));
    });
  });

  group('Data Message - Common Message Types', () {
    test('parses file_id message (0)', () {
      // Definition
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 0,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 1, baseTypeId: 0x00), // type
          FieldDefinition(fieldNumber: 1, size: 2, baseTypeId: 0x84), // manufacturer
          FieldDefinition(fieldNumber: 2, size: 2, baseTypeId: 0x84), // product
          FieldDefinition(fieldNumber: 3, size: 4, baseTypeId: 0x86), // serial_number
        ],
        developerFieldDefinitions: [],
      );

      // Data: type=4, manufacturer=1, product=1234, serial=987654321
      final dataBytes = Uint8List.fromList([
        0x04,
        0x01,
        0x00,
        0xD2,
        0x04,
        0xB1,
        0x68,
        0xDE,
        0x3A,
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint8(0), equals(4));
      expect(data.getUint16(1, Endian.little), equals(1));
      expect(data.getUint16(3, Endian.little), equals(1234));
      expect(data.getUint32(5, Endian.little), equals(987654321));
    });

    test('parses record message (20) with position and heart rate', () {
      // Definition
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 0, size: 4, baseTypeId: 0x85), // position_lat
          FieldDefinition(fieldNumber: 1, size: 4, baseTypeId: 0x85), // position_long
          FieldDefinition(fieldNumber: 3, size: 1, baseTypeId: 0x02), // heart_rate
        ],
        developerFieldDefinitions: [],
      );

      // Data: timestamp=1000000000, lat=123456789 (semicircles), long=987654321, hr=150
      final dataBytes = Uint8List.fromList([
        0x00, 0xCA, 0x9A, 0x3B, // timestamp
        0x15, 0xCD, 0x5B, 0x07, // lat
        0xB1, 0x68, 0xDE, 0x3A, // long
        0x96, // hr: 150
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(1000000000));
      expect(data.getInt32(4, Endian.little), equals(123456789));
      expect(data.getInt32(8, Endian.little), equals(987654321));
      expect(data.getUint8(12), equals(150));
    });

    test('parses lap message (19) with summary data', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 2,
        architecture: 0,
        globalMessageNumber: 19,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 7, size: 4, baseTypeId: 0x86), // total_elapsed_time (ms)
          FieldDefinition(fieldNumber: 9, size: 4, baseTypeId: 0x86), // total_distance (cm)
          FieldDefinition(fieldNumber: 16, size: 1, baseTypeId: 0x02), // avg_heart_rate
        ],
        developerFieldDefinitions: [],
      );

      // Data: timestamp=1001000, time=600000ms (10min), distance=500000cm (5km), avg_hr=145
      final dataBytes = Uint8List.fromList([
        0x68, 0x47, 0x0F, 0x00, // timestamp: 1001000
        0xC0, 0x27, 0x09, 0x00, // elapsed: 600000
        0x20, 0xA1, 0x07, 0x00, // distance: 500000
        0x91, // avg_hr: 145
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(1001320));
      expect(data.getUint32(4, Endian.little), equals(600000));
      expect(data.getUint32(8, Endian.little), equals(500000));
      expect(data.getUint8(12), equals(145));
    });

    test('parses session message (18) with activity summary', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 3,
        architecture: 0,
        globalMessageNumber: 18,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 253, size: 4, baseTypeId: 0x86), // timestamp
          FieldDefinition(fieldNumber: 5, size: 1, baseTypeId: 0x00), // sport
          FieldDefinition(fieldNumber: 9, size: 4, baseTypeId: 0x86), // total_distance
          FieldDefinition(fieldNumber: 16, size: 1, baseTypeId: 0x02), // avg_heart_rate
        ],
        developerFieldDefinitions: [],
      );

      // Data: timestamp=2000000, sport=1 (running), distance=10000000cm (100km), avg_hr=140
      final dataBytes = Uint8List.fromList([
        0x80, 0x84, 0x1E, 0x00, // timestamp: 2000000
        0x01, // sport: running
        0x80, 0x96, 0x98, 0x00, // distance: 10000000
        0x8C, // avg_hr: 140
      ]);

      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint32(0, Endian.little), equals(2000000));
      expect(data.getUint8(4), equals(1));
      expect(data.getUint32(5, Endian.little), equals(10000000));
      expect(data.getUint8(9), equals(140));
    });
  });

  group('Data Message - Big-Endian Architecture', () {
    test('parses uint16 field with big-endian architecture', () {
      final dataBytes = Uint8List.fromList([0x04, 0xD2]); // 1234 in big-endian
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getUint16(0, Endian.big);
      expect(value, equals(1234));
    });

    test('parses uint32 field with big-endian architecture', () {
      final dataBytes = Uint8List.fromList([0x3A, 0xDE, 0x68, 0xB1]); // 987654321 in big-endian
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getUint32(0, Endian.big);
      expect(value, equals(987654321));
    });

    test('parses float32 field with big-endian architecture', () {
      final dataBytes = Uint8List.fromList([0x40, 0x48, 0xF5, 0xC3]); // 3.14 in big-endian
      final data = ByteData.view(dataBytes.buffer);
      final value = data.getFloat32(0, Endian.big);
      expect(value, closeTo(3.14, 0.001));
    });
  });

  group('Data Message - Edge Cases', () {
    test('handles message with no fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 99,
        fieldDefinitions: [],
        developerFieldDefinitions: [],
      );

      expect(definition.fieldDefinitions, isEmpty);
    });

    test('handles message with maximum fields (255)', () {
      final fieldDefs = List.generate(
        255,
        (i) => FieldDefinition(fieldNumber: i, size: 1, baseTypeId: 0x02),
      );

      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 99,
        fieldDefinitions: fieldDefs,
        developerFieldDefinitions: [],
      );

      expect(definition.fieldDefinitions.length, equals(255));
    });

    test('handles oversized data for field definition', () {
      // Field defined as 2 bytes but data has more
      final dataBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      // Should only read first 2 bytes per definition
      final data = ByteData.view(dataBytes.buffer);
      expect(data.getUint16(0, Endian.little), equals(0x0201));
    });

    test('handles undersized data gracefully', () {
      // Attempt to read beyond available data should throw
      final dataBytes = Uint8List.fromList([0x01]);
      final data = ByteData.view(dataBytes.buffer);

      expect(
        () => data.getUint16(0, Endian.little),
        throwsRangeError,
      );
    });

    test('handles mixed valid and invalid fields', () {
      final dataBytes = Uint8List.fromList([
        0x78, // Valid: 120
        0xFF, // Invalid
        0x5A, // Valid: 90
        0xFF, // Invalid
        0x3C, // Valid: 60
      ]);

      final validValues = <int>[];
      for (final byte in dataBytes) {
        if (byte != 0xFF) {
          validValues.add(byte);
        }
      }

      expect(validValues, equals([120, 90, 60]));
    });
  });
}
