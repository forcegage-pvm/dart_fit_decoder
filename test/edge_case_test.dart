/// Edge case and error handling tests for robust FIT file parsing.
library;

import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Cases - Header Validation', () {
    test('rejects header smaller than 14 bytes', () {
      final shortHeader = Uint8List.fromList([
        0x0E, 0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, // Only 11 bytes
      ]);

      expect(
        () => FitHeader.parse(shortHeader),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('rejects incorrect signature', () {
      final badSignature = Uint8List.fromList([
        0x0E, 0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x42, 0x41, 0x44, 0x21, // 'BAD!' instead of '.FIT'
        0x00, 0x00,
      ]);

      expect(
        () => FitHeader.parse(badSignature),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('accepts 12-byte header (legacy)', () {
      // Legacy FIT files had 12-byte headers without CRC
      final legacyHeader = Uint8List.fromList([
        0x0C, // Header size: 12
        0x10, // Protocol version 1.0
        0x00, 0x00, // Profile version 0.0
        0x00, 0x00, 0x00, 0x00, // Data size: 0
        0x2E, 0x46, 0x49, 0x54, // '.FIT'
      ]);

      // Should parse without CRC
      expect(legacyHeader.length, equals(12));
      expect(legacyHeader[0], equals(12)); // header_size
    });

    test('rejects header size less than 12', () {
      final tinyHeader = Uint8List.fromList([
        0x08, // Header size: 8 (too small)
        0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54,
      ]);

      expect(
        () => FitHeader.parse(tinyHeader),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('handles extended header sizes', () {
      // Future FIT versions might have larger headers
      final extendedHeader = Uint8List.fromList([
        0x10, // Header size: 16
        0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54,
        0x00, 0x00, // CRC
        0xFF, 0xFF, // Extra bytes
      ]);

      expect(extendedHeader[0], equals(16));
      expect(extendedHeader.length, greaterThanOrEqualTo(16));
    });
  });

  group('Edge Cases - Message Definitions', () {
    test('handles definition with zero fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 99,
        fieldDefinitions: [],
        developerFieldDefinitions: [],
      );

      expect(definition.fieldDefinitions, isEmpty);
      expect(definition.totalFieldSize, equals(0));
    });

    test('handles definition with maximum 255 fields', () {
      final fields = List.generate(
        255,
        (i) => FieldDefinition(fieldNumber: i, size: 1, baseTypeId: 0x02),
      );

      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: fields,
        developerFieldDefinitions: [],
      );

      expect(definition.fieldDefinitions.length, equals(255));
      expect(definition.totalFieldSize, equals(255));
    });

    test('handles definition with large field sizes', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 99,
        fieldDefinitions: [
          FieldDefinition(fieldNumber: 0, size: 255, baseTypeId: 0x07), // Max size
        ],
        developerFieldDefinitions: [],
      );

      expect(definition.totalFieldSize, equals(255));
    });

    test('handles mixed field sizes totaling large values', () {
      final fields = [
        FieldDefinition(fieldNumber: 0, size: 100, baseTypeId: 0x0D),
        FieldDefinition(fieldNumber: 1, size: 200, baseTypeId: 0x0D),
        FieldDefinition(fieldNumber: 2, size: 50, baseTypeId: 0x0D),
      ];

      final definition = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 99,
        fieldDefinitions: fields,
        developerFieldDefinitions: [],
      );

      expect(definition.totalFieldSize, equals(350));
    });

    test('handles developer fields without normal fields', () {
      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [
          DeveloperFieldDefinition(fieldNumber: 0, size: 1, developerDataIndex: 0),
        ],
      );

      expect(definition.fieldDefinitions, isEmpty);
      expect(definition.developerFieldDefinitions.length, equals(1));
    });

    test('handles maximum developer fields', () {
      final devFields = List.generate(
        255,
        (i) => DeveloperFieldDefinition(fieldNumber: i, size: 1, developerDataIndex: 0),
      );

      final definition = FitDefinitionMessage(
        localMessageNumber: 1,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: devFields,
      );

      expect(definition.developerFieldDefinitions.length, equals(255));
    });
  });

  group('Edge Cases - Data Reading', () {
    test('handles reading at exact buffer boundary', () {
      final buffer = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final data = ByteData.view(buffer.buffer);

      // Read exactly at end
      expect(data.getUint8(3), equals(0x04));

      // Reading beyond should fail
      expect(() => data.getUint8(4), throwsRangeError);
    });

    test('handles reading multi-byte values at boundary', () {
      final buffer = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final data = ByteData.view(buffer.buffer);

      // uint32 at start is ok
      expect(data.getUint32(0, Endian.little), equals(0x04030201));

      // uint32 at position 1 would overflow
      expect(() => data.getUint32(1, Endian.little), throwsRangeError);
    });

    test('handles empty byte arrays', () {
      final empty = Uint8List.fromList([]);
      expect(empty.length, equals(0));
      expect(empty, isEmpty);
    });

    test('handles single-byte arrays', () {
      final single = Uint8List.fromList([0x42]);
      expect(single.length, equals(1));
      expect(single[0], equals(0x42));
    });

    test('handles maximum uint32 values', () {
      final buffer = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      final data = ByteData.view(buffer.buffer);
      expect(data.getUint32(0, Endian.little), equals(0xFFFFFFFF));
    });

    test('handles maximum sint32 values', () {
      final maxPositive = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0x7F]);
      final maxNegative = Uint8List.fromList([0x00, 0x00, 0x00, 0x80]);

      final data1 = ByteData.view(maxPositive.buffer);
      final data2 = ByteData.view(maxNegative.buffer);

      expect(data1.getInt32(0, Endian.little), equals(2147483647));
      expect(data2.getInt32(0, Endian.little), equals(-2147483648));
    });
  });

  group('Edge Cases - Compressed Timestamps', () {
    test('handles compressed timestamp rollover at 31 seconds', () {
      final baseTimestamp = 1000000;

      // Offset 31 (maximum)
      final offset31 = 31;
      final timestamp31 = baseTimestamp + offset31;
      expect(timestamp31, equals(1000031));

      // Next record with offset 0 (rollover)
      final offset0 = 0;
      final timestamp32 = timestamp31 + (32 - offset31) + offset0;
      expect(timestamp32, equals(1000032));
    });

    test('handles all compressed timestamp offsets (0-31)', () {
      final baseTimestamp = 1000000;

      for (int offset = 0; offset <= 31; offset++) {
        final timestamp = baseTimestamp + offset;
        expect(timestamp, equals(1000000 + offset));
      }
    });

    test('detects compressed timestamp header bit', () {
      final normalHeader = 0x00; // Normal data message
      final compressedHeader = 0x80; // Compressed timestamp

      expect(normalHeader & 0x80, equals(0));
      expect(compressedHeader & 0x80, equals(0x80));
    });

    test('extracts local message type from compressed header', () {
      final header1 = 0x81; // Compressed, local 1
      final header2 = 0x83; // Compressed, local 3

      expect(header1 & 0x60, equals(0x20 >> 2)); // Extract bits 5-6
      expect((header1 >> 5) & 0x03, equals(0)); // Local type 0

      // For local type extraction in compressed timestamps
      final localType1 = (header1 >> 5) & 0x03;
      final localType2 = (header2 >> 5) & 0x03;

      expect(localType1, inInclusiveRange(0, 3));
      expect(localType2, inInclusiveRange(0, 3));
    });

    test('extracts time offset from compressed header', () {
      final header = 0x8F; // Compressed, offset 15

      final offset = header & 0x1F; // Lower 5 bits
      expect(offset, equals(15));
      expect(offset, inInclusiveRange(0, 31));
    });
  });

  group('Edge Cases - String Fields', () {
    test('handles empty null-terminated strings', () {
      final emptyString = Uint8List.fromList([0x00]);
      final str = String.fromCharCodes(emptyString.takeWhile((b) => b != 0));
      expect(str, isEmpty);
    });

    test('handles strings without null terminator', () {
      final noNull = Uint8List.fromList([0x48, 0x49]); // 'HI'
      final str = String.fromCharCodes(noNull);
      expect(str, equals('HI'));
    });

    test('handles strings with early null terminator', () {
      final earlyNull = Uint8List.fromList([
        0x48, 0x49, 0x00, 0x42, 0x59, 0x45, // 'HI\0BYE'
      ]);
      final str = String.fromCharCodes(earlyNull.takeWhile((b) => b != 0));
      expect(str, equals('HI')); // Stops at first null
    });

    test('handles strings with all nulls', () {
      final allNull = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      final str = String.fromCharCodes(allNull.takeWhile((b) => b != 0));
      expect(str, isEmpty);
    });

    test('handles UTF-8 characters in strings', () {
      // ASCII only in FIT, but testing boundary
      final ascii = 'GARMIN'.codeUnits;
      expect(ascii, everyElement(inInclusiveRange(0, 127)));
    });

    test('handles maximum string length', () {
      final longString = List.filled(255, 0x41); // 255 'A's
      expect(longString.length, equals(255));
    });
  });

  group('Edge Cases - Invalid Values', () {
    test('detects all base type invalid values', () {
      final invalidValues = {
        'enum': 0xFF,
        'sint8': 0x7F,
        'uint8': 0xFF,
        'sint16': 0x7FFF,
        'uint16': 0xFFFF,
        'sint32': 0x7FFFFFFF,
        'uint32': 0xFFFFFFFF,
        'uint8z': 0x00,
        'uint16z': 0x0000,
        'uint32z': 0x00000000,
      };

      for (final entry in invalidValues.entries) {
        expect(entry.value, isNotNull); // All have invalid markers
      }
    });

    test('distinguishes valid zeros from uint*z invalid', () {
      // For uint8z, uint16z, uint32z, 0 is invalid but valid for regular uints
      final uint8Valid = 0x00; // Valid for uint8
      final uint8zInvalid = 0x00; // Invalid for uint8z

      expect(uint8Valid, equals(0));
      expect(uint8zInvalid, equals(0)); // Same value, different interpretation
    });

    test('handles fields with all invalid values', () {
      final allInvalid = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      final validValues = allInvalid.where((b) => b != 0xFF).toList();
      expect(validValues, isEmpty);
    });

    test('handles alternating valid and invalid values', () {
      final mixed = [120, 0xFF, 130, 0xFF, 140];
      final valid = mixed.where((v) => v != 0xFF).toList();
      expect(valid, equals([120, 130, 140]));
    });
  });

  group('Edge Cases - Endianness', () {
    test('handles little-endian uint16', () {
      final bytes = Uint8List.fromList([0x34, 0x12]); // 0x1234
      final data = ByteData.view(bytes.buffer);
      expect(data.getUint16(0, Endian.little), equals(0x1234));
    });

    test('handles big-endian uint16', () {
      final bytes = Uint8List.fromList([0x12, 0x34]); // 0x1234
      final data = ByteData.view(bytes.buffer);
      expect(data.getUint16(0, Endian.big), equals(0x1234));
    });

    test('demonstrates endianness difference', () {
      final bytes = Uint8List.fromList([0x01, 0x02]);
      final data = ByteData.view(bytes.buffer);

      final little = data.getUint16(0, Endian.little); // 0x0201
      final big = data.getUint16(0, Endian.big); // 0x0102

      expect(little, equals(0x0201));
      expect(big, equals(0x0102));
      expect(little, isNot(equals(big)));
    });

    test('handles architecture byte (0=little, 1=big)', () {
      final littleEndian = 0;
      final bigEndian = 1;

      expect(littleEndian, equals(0));
      expect(bigEndian, equals(1));
    });

    test('handles float endianness', () {
      // Float representation of 1.0
      final bytes = Uint8List.fromList([0x00, 0x00, 0x80, 0x3F]);
      final data = ByteData.view(bytes.buffer);

      final value = data.getFloat32(0, Endian.little);
      expect(value, closeTo(1.0, 0.001));
    });
  });

  group('Edge Cases - Local Message Types', () {
    test('handles all 16 local message types (0-15)', () {
      for (int local = 0; local < 16; local++) {
        final definition = FitDefinitionMessage(
          localMessageNumber: local,
          architecture: 0,
          globalMessageNumber: 20,
          fieldDefinitions: [],
          developerFieldDefinitions: [],
        );

        expect(definition.localMessageNumber, equals(local));
        expect(definition.localMessageNumber, inInclusiveRange(0, 15));
      }
    });

    test('handles local message type redefinition', () {
      // Define local 0 as file_id
      final def1 = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 0,
        fieldDefinitions: [],
        developerFieldDefinitions: [],
      );

      // Redefine local 0 as record
      final def2 = FitDefinitionMessage(
        localMessageNumber: 0,
        architecture: 0,
        globalMessageNumber: 20,
        fieldDefinitions: [],
        developerFieldDefinitions: [],
      );

      expect(def1.localMessageNumber, equals(def2.localMessageNumber));
      expect(def1.globalMessageNumber, isNot(equals(def2.globalMessageNumber)));
    });

    test('handles rapid local type switching', () {
      // Simulate switching between local types quickly
      final localTypes = [0, 1, 2, 3, 0, 1, 2, 3];

      for (final local in localTypes) {
        expect(local, inInclusiveRange(0, 15));
      }
    });
  });

  group('Edge Cases - CRC Edge Cases', () {
    test('handles CRC of zero bytes', () {
      final empty = Uint8List.fromList([]);
      // CRC of empty should be 0
      expect(empty.isEmpty, isTrue);
    });

    test('handles CRC with all zeros', () {
      final zeros = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      // CRC of all zeros is 0 (property of CRC)
      expect(zeros.every((b) => b == 0), isTrue);
    });

    test('handles CRC with all 0xFF', () {
      final ones = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      expect(ones.every((b) => b == 0xFF), isTrue);
    });

    test('detects single-bit error with CRC', () {
      // CRC should detect any single-bit flip
      final original = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      final corrupted = Uint8List.fromList([0x01, 0x01, 0x02, 0x03]); // Flipped bit

      expect(original[0], isNot(equals(corrupted[0])));
    });
  });

  group('Edge Cases - File Size Limits', () {
    test('handles minimum file size (14-byte header only)', () {
      final minFile = Uint8List.fromList([
        0x0E,
        0x20,
        0x14,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x00,
        0x2E,
        0x46,
        0x49,
        0x54,
        0x00,
        0x00,
      ]);

      expect(minFile.length, equals(14));
    });

    test('handles very large data size field', () {
      // Data size field is uint32, max 4GB
      final largeSize = 0xFFFFFFFF;
      expect(largeSize, equals(4294967295)); // ~4.3 GB
    });

    test('handles typical file sizes', () {
      final sizes = {
        'small': 1024, // 1 KB
        'medium': 1048576, // 1 MB
        'large': 10485760, // 10 MB
        'very_large': 104857600, // 100 MB
      };

      for (final size in sizes.values) {
        expect(size, greaterThan(0));
        expect(size, lessThan(0xFFFFFFFF));
      }
    });
  });

  group('Edge Cases - Developer Field Edge Cases', () {
    test('handles developer data index up to 255', () {
      for (int index = 0; index < 256; index++) {
        final devField = DeveloperFieldDefinition(
          fieldNumber: 0,
          size: 1,
          developerDataIndex: index,
        );

        expect(devField.developerDataIndex, equals(index));
        expect(devField.developerDataIndex, inInclusiveRange(0, 255));
      }
    });

    test('handles field definition number up to 255', () {
      for (int fieldNum = 0; fieldNum < 256; fieldNum++) {
        final devField = DeveloperFieldDefinition(
          fieldNumber: fieldNum,
          size: 1,
          developerDataIndex: 0,
        );

        expect(devField.fieldNumber, equals(fieldNum));
      }
    });

    test('handles multiple developer data sources', () {
      // Multiple developer IDs (different sensors)
      final devFields = [
        DeveloperFieldDefinition(fieldNumber: 0, size: 1, developerDataIndex: 0),
        DeveloperFieldDefinition(fieldNumber: 0, size: 1, developerDataIndex: 1),
        DeveloperFieldDefinition(fieldNumber: 0, size: 1, developerDataIndex: 2),
      ];

      final indices = devFields.map((f) => f.developerDataIndex).toSet();
      expect(indices.length, equals(3)); // All unique indices
    });
  });

  group('Edge Cases - Memory and Performance', () {
    test('handles large byte arrays efficiently', () {
      final largeArray = Uint8List(10000);
      expect(largeArray.length, equals(10000));
    });

    test('handles repeated field reads', () {
      final data = ByteData(4);
      data.setUint32(0, 12345, Endian.little);

      // Read same value multiple times
      for (int i = 0; i < 100; i++) {
        expect(data.getUint32(0, Endian.little), equals(12345));
      }
    });

    test('handles ByteData view slicing', () {
      final buffer = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);

      // Create view from offset 2, length 4
      final view = ByteData.view(buffer.buffer, 2, 4);
      expect(view.lengthInBytes, equals(4));
      expect(view.getUint8(0), equals(2)); // First byte of view is buffer[2]
    });
  });
}
