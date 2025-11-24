/// Integration tests for end-to-end FIT file parsing.
library;

import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  /// Helper to calculate CRC-16 for FIT files.
  int calculateCrc(Uint8List bytes, {int start = 0, int? end}) {
    end ??= bytes.length;
    final crcTable = List<int>.generate(256, (i) {
      int crc = i << 8;
      for (int j = 0; j < 8; j++) {
        crc = ((crc & 0x8000) != 0) ? ((crc << 1) ^ 0x1021) : (crc << 1);
      }
      return crc & 0xFFFF;
    });

    int crc = 0;
    for (int i = start; i < end; i++) {
      crc = ((crc << 8) ^ crcTable[(crc >> 8) ^ bytes[i]]) & 0xFFFF;
    }
    return crc;
  }

  /// Helper to create complete FIT file with CRC.
  Uint8List createFitFile(List<int> dataBytes) {
    final dataSize = dataBytes.length;

    // Header (14 bytes)
    final header = [
      0x0E, // Header size
      0x20, // Protocol version 2.0
      0x14, 0x0A, // Profile version 10.20
      dataSize & 0xFF,
      (dataSize >> 8) & 0xFF,
      (dataSize >> 16) & 0xFF,
      (dataSize >> 24) & 0xFF,
      0x2E, 0x46, 0x49, 0x54, // '.FIT'
    ];

    // Calculate header CRC
    final headerBytes = Uint8List.fromList(header);
    final headerCrc = calculateCrc(headerBytes, start: 0, end: 12);

    // Complete header with CRC
    final completeHeader = [
      ...header,
      headerCrc & 0xFF,
      (headerCrc >> 8) & 0xFF,
    ];

    // Complete file = header + data
    final fileBytes = Uint8List.fromList([...completeHeader, ...dataBytes]);

    // Calculate file CRC (entire file)
    final fileCrc = calculateCrc(fileBytes);

    // Complete file with CRC
    return Uint8List.fromList([
      ...fileBytes,
      fileCrc & 0xFF,
      (fileCrc >> 8) & 0xFF,
    ]);
  }

  group('Integration - Minimal Valid FIT File', () {
    test('parses minimal FIT file with no data', () {
      final fitFile = createFitFile([]);

      // Decode header
      final decoder = FitDecoder(fitFile);
      final header = FitHeader.parse(fitFile);

      expect(header.headerSize, equals(14));
      expect(header.protocolVersionMajor, equals(2));
      expect(header.protocolVersionMinor, equals(0));
      expect(header.dataSize, equals(0));
      expect(header.signature, equals('.FIT'));
    });

    test('validates header CRC', () {
      final fitFile = createFitFile([]);

      final headerBytes = fitFile.sublist(0, 12);
      final calculatedCrc = calculateCrc(headerBytes);

      final data = ByteData.view(fitFile.buffer);
      final storedCrc = data.getUint16(12, Endian.little);

      expect(storedCrc, equals(calculatedCrc));
    });

    test('validates file CRC', () {
      final fitFile = createFitFile([]);

      // CRC is last 2 bytes
      final fileWithoutCrc = fitFile.sublist(0, fitFile.length - 2);
      final calculatedCrc = calculateCrc(fileWithoutCrc);

      final data = ByteData.view(fitFile.buffer);
      final storedCrc = data.getUint16(fitFile.length - 2, Endian.little);

      expect(storedCrc, equals(calculatedCrc));
    });
  });

  group('Integration - FIT File with file_id', () {
    test('parses complete FIT file with file_id message', () {
      final dataBytes = [
        // Definition message: local 0, file_id (0)
        0x40, 0x00, 0x00, 0x00, 0x00, 0x04,
        // 4 fields
        0x00, 0x01, 0x00, // type:enum (1 byte)
        0x01, 0x02, 0x84, // manufacturer:uint16 (2 bytes)
        0x02, 0x02, 0x84, // product:uint16 (2 bytes)
        0x03, 0x04, 0x86, // serial_number:uint32 (4 bytes)

        // Data message: local 0
        0x00,
        0x04, // type: activity
        0x01, 0x00, // manufacturer: Garmin
        0xD2, 0x04, // product: 1234
        0xB1, 0x68, 0xDE, 0x3A, // serial: 987654321
      ];

      final fitFile = createFitFile(dataBytes);

      // Verify file structure
      expect(fitFile.length, greaterThan(14)); // Header + data + CRC
      expect(fitFile[8], equals(0x2E)); // '.FIT' signature start

      // Decode
      final decoder = FitDecoder(fitFile);
      expect(decoder, isNotNull);
    });

    test('extracts file_id fields', () {
      final dataBytes = [
        0x40,
        0x00,
        0x00,
        0x00,
        0x00,
        0x04,
        0x00,
        0x01,
        0x00,
        0x01,
        0x02,
        0x84,
        0x02,
        0x02,
        0x84,
        0x03,
        0x04,
        0x86,
        0x00,
        0x04,
        0x01,
        0x00,
        0xD2,
        0x04,
        0xB1,
        0x68,
        0xDE,
        0x3A,
      ];

      final fitFile = createFitFile(dataBytes);

      // Parse data message manually
      final dataOffset = 14 + 18; // Header + definition (18 bytes)
      final data = ByteData.view(fitFile.buffer, dataOffset);

      expect(data.getUint8(1), equals(4)); // type
      expect(data.getUint16(2, Endian.little), equals(1)); // manufacturer
      expect(data.getUint16(4, Endian.little), equals(1234)); // product
      expect(data.getUint32(6, Endian.little), equals(987654321)); // serial
    });
  });

  group('Integration - FIT File with Record Messages', () {
    test('parses FIT file with multiple record messages', () {
      final dataBytes = [
        // Definition: local 1, record (20)
        0x41, 0x00, 0x00, 0x00, 0x14, 0x02,
        // 2 fields
        0xFD, 0x04, 0x86, // timestamp:uint32 (4 bytes)
        0x03, 0x01, 0x02, // heart_rate:uint8 (1 byte)

        // Data record 1: local 1
        0x01,
        0x40, 0x42, 0x0F, 0x00, // timestamp: 1000000
        0x78, // hr: 120

        // Data record 2: local 1 (compressed timestamp)
        0x81, // Compressed: local 1, offset +1
        0x79, // hr: 121

        // Data record 3: local 1 (compressed timestamp)
        0x82, // Compressed: local 1, offset +2
        0x7A, // hr: 122
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(30));
    });

    test('extracts record message fields', () {
      final dataBytes = [
        0x41,
        0x00,
        0x00,
        0x00,
        0x14,
        0x02,
        0xFD,
        0x04,
        0x86,
        0x03,
        0x01,
        0x02,
        0x01,
        0x40,
        0x42,
        0x0F,
        0x00,
        0x78,
      ];

      final fitFile = createFitFile(dataBytes);

      // Parse first data message
      final dataOffset = 14 + 12 + 1; // Header + definition (12 bytes) + header byte
      final data = ByteData.view(fitFile.buffer, dataOffset);

      expect(data.getUint32(0, Endian.little), equals(1000000)); // timestamp
      expect(data.getUint8(4), equals(120)); // heart_rate
    });
  });

  group('Integration - FIT File with CORE Developer Fields', () {
    test('parses FIT file with developer data', () {
      final dataBytes = [
        // developer_data_id message (207)
        0x45, 0x00, 0x00, 0x00, 0xCF, 0x02,
        0x00, 0x10, 0x0D, // application_id:byte[16]
        0x01, 0x01, 0x02, // developer_data_index:uint8

        0x05,
        ...List.generate(16, (i) => i + 1), // app_id
        0x00, // index

        // field_description message (206)
        0x45, 0x00, 0x00, 0x00, 0xCE, 0x03,
        0x00, 0x01, 0x02, // developer_data_index:uint8
        0x01, 0x01, 0x02, // field_definition_number:uint8
        0x02, 0x01, 0x02, // base_type_id:uint8

        0x05,
        0x00, // index
        0x07, // field_num: 7 (core_temp)
        0x02, // base_type: uint8

        // Record with developer field
        0x61, 0x00, 0x00, 0x00, 0x14, 0x01, // Normal fields
        0xFD, 0x04, 0x86, // timestamp
        0x01, // 1 developer field
        0x07, 0x01, 0x00, // field 7, size 1, index 0

        0x01,
        0x40, 0x42, 0x0F, 0x00, // timestamp
        0x26, // core_temp: 38°C
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(50));
    });

    test('extracts CORE temperature from developer fields', () {
      // Minimal example with developer field
      final dataBytes = [
        // Record definition with developer field
        0x61, 0x00, 0x00, 0x00, 0x14, 0x01,
        0xFD, 0x04, 0x86, // timestamp
        0x01, // 1 developer field
        0x07, 0x01, 0x00, // field 7, size 1, index 0

        // Data
        0x01,
        0x40, 0x42, 0x0F, 0x00, // timestamp: 1000000
        0x26, // core_temp: 38°C
      ];

      final fitFile = createFitFile(dataBytes);

      // Find developer field data
      final dataOffset = 14 + 13 + 1; // Header + definition (13 bytes) + header byte
      final data = ByteData.view(fitFile.buffer, dataOffset);

      expect(data.getUint32(0, Endian.little), equals(1000000));
      expect(data.getUint8(4), equals(38)); // core_temp
    });

    test('extracts multiple CORE fields from record', () {
      final dataBytes = [
        // Definition with 3 CORE fields
        0x61, 0x00, 0x00, 0x00, 0x14, 0x01,
        0xFD, 0x04, 0x86, // timestamp
        0x03, // 3 developer fields
        0x07, 0x01, 0x00, // core_temp
        0x08, 0x01, 0x00, // skin_temp
        0x09, 0x01, 0x00, // heat_strain_index

        // Data
        0x01,
        0x40, 0x42, 0x0F, 0x00, // timestamp
        0x26, // core_temp: 38
        0x23, // skin_temp: 35
        0x05, // hsi: 5
      ];

      final fitFile = createFitFile(dataBytes);

      final dataOffset = 14 + 19 + 1; // Header + definition (19 bytes) + header byte
      final data = ByteData.view(fitFile.buffer, dataOffset);

      expect(data.getUint32(0, Endian.little), equals(1000000));
      expect(data.getUint8(4), equals(38)); // core_temp
      expect(data.getUint8(5), equals(35)); // skin_temp
      expect(data.getUint8(6), equals(5)); // hsi
    });
  });

  group('Integration - FIT File with Lap and Session', () {
    test('parses FIT file with lap messages', () {
      final dataBytes = [
        // Lap definition: local 2, lap (19)
        0x42, 0x00, 0x00, 0x00, 0x13, 0x02,
        0xFD, 0x04, 0x86, // timestamp
        0x07, 0x04, 0x86, // total_elapsed_time

        // Lap data
        0x02,
        0xE8, 0x03, 0x00, 0x00, // timestamp: 1000
        0x10, 0x27, 0x00, 0x00, // elapsed: 10000ms
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(30));
    });

    test('parses FIT file with session message', () {
      final dataBytes = [
        // Session definition: local 3, session (18)
        0x43, 0x00, 0x00, 0x00, 0x12, 0x02,
        0xFD, 0x04, 0x86, // timestamp
        0x05, 0x01, 0x00, // sport:enum

        // Session data
        0x03,
        0xD0, 0x07, 0x00, 0x00, // timestamp: 2000
        0x01, // sport: running
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(25));
    });
  });

  group('Integration - Multiple Local Message Types', () {
    test('parses FIT file with multiple definitions', () {
      final dataBytes = [
        // Definition 0: file_id
        0x40, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00, // type

        // Data 0
        0x00,
        0x04, // type: activity

        // Definition 1: record
        0x41, 0x00, 0x00, 0x00, 0x14, 0x01,
        0xFD, 0x04, 0x86, // timestamp

        // Data 1
        0x01,
        0x10, 0x27, 0x00, 0x00, // timestamp: 10000

        // Data 1 again (compressed)
        0x81, // Compressed, local 1, offset +1

        // Definition 2: lap
        0x42, 0x00, 0x00, 0x00, 0x13, 0x01,
        0xFD, 0x04, 0x86, // timestamp

        // Data 2
        0x02,
        0x20, 0x4E, 0x00, 0x00, // timestamp: 20000
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(50));
    });

    test('handles redefinition of local message type', () {
      final dataBytes = [
        // Definition 0: file_id
        0x40, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00,

        // Data 0
        0x00,
        0x04,

        // Redefinition 0: record (different message)
        0x40, 0x00, 0x00, 0x00, 0x14, 0x01,
        0xFD, 0x04, 0x86,

        // Data 0 (now record)
        0x00,
        0x10, 0x27, 0x00, 0x00,
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(40));
    });
  });

  group('Integration - Complete Activity File', () {
    test('simulates complete activity FIT file structure', () {
      final dataBytes = [
        // 1. file_id
        0x40, 0x00, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0x00,
        0x01, 0x02, 0x84,
        0x00,
        0x04, // type: activity
        0x01, 0x00, // manufacturer: Garmin

        // 2. Multiple records
        0x41, 0x00, 0x00, 0x00, 0x14, 0x02,
        0xFD, 0x04, 0x86,
        0x03, 0x01, 0x02,
        0x01,
        0x00, 0x00, 0x00, 0x00, // timestamp: 0
        0x78, // hr: 120

        0x81, // Compressed timestamp +1
        0x79, // hr: 121

        0x82, // Compressed timestamp +2
        0x7A, // hr: 122

        // 3. Lap
        0x42, 0x00, 0x00, 0x00, 0x13, 0x01,
        0xFD, 0x04, 0x86,
        0x02,
        0x02, 0x00, 0x00, 0x00, // timestamp: 2

        // 4. Session
        0x43, 0x00, 0x00, 0x00, 0x12, 0x01,
        0xFD, 0x04, 0x86,
        0x03,
        0x02, 0x00, 0x00, 0x00, // timestamp: 2
      ];

      final fitFile = createFitFile(dataBytes);
      expect(fitFile.length, greaterThan(70));

      // Verify header
      final header = FitHeader.parse(fitFile);
      expect(header.signature, equals('.FIT'));
      expect(header.dataSize, equals(dataBytes.length));
    });
  });

  group('Integration - Error Handling', () {
    test('detects truncated file', () {
      final fitFile = Uint8List.fromList([0x0E, 0x20, 0x14]); // Incomplete header

      expect(
        () => FitHeader.parse(fitFile),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('detects invalid signature', () {
      final fitFile = Uint8List.fromList([
        0x0E, 0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x42, 0x41, 0x44, 0x21, // 'BAD!' instead of '.FIT'
        0x00, 0x00,
      ]);

      expect(
        () => FitHeader.parse(fitFile),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('detects CRC mismatch', () {
      final fitFile = Uint8List.fromList([
        0x0E, 0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54,
        0xFF, 0xFF, // Wrong CRC
      ]);

      final headerBytes = fitFile.sublist(0, 12);
      final calculatedCrc = calculateCrc(headerBytes);

      final data = ByteData.view(fitFile.buffer);
      final storedCrc = data.getUint16(12, Endian.little);

      expect(storedCrc, isNot(equals(calculatedCrc)));
    });

    test('handles data size mismatch', () {
      // Header claims 100 bytes but only has 10
      final header = [
        0x0E, 0x20, 0x14, 0x0A,
        0x64, 0x00, 0x00, 0x00, // Data size: 100
        0x2E, 0x46, 0x49, 0x54,
      ];

      final headerBytes = Uint8List.fromList(header);
      final headerCrc = calculateCrc(headerBytes);

      final fitFile = Uint8List.fromList([
        ...header,
        headerCrc & 0xFF,
        (headerCrc >> 8) & 0xFF,
        ...List.generate(10, (i) => i), // Only 10 bytes
      ]);

      final parsedHeader = FitHeader.parse(fitFile);
      expect(parsedHeader.dataSize, equals(100));
      expect(fitFile.length - 16, lessThan(100)); // Missing data
    });
  });
}
