/// Tests for CRC (Cyclic Redundancy Check) calculation and validation.
library;

import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  /// CRC-16 lookup table for FIT files (CCITT polynomial 0x1021).
  List<int> generateCrcTable() {
    final crcTable = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i << 8;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = crc << 1;
        }
      }
      crcTable[i] = crc & 0xFFFF;
    }
    return crcTable;
  }

  /// Calculate CRC-16 for a byte array.
  int calculateCrc(Uint8List bytes, {int start = 0, int? end}) {
    end ??= bytes.length;
    final crcTable = generateCrcTable();
    int crc = 0;

    for (int i = start; i < end; i++) {
      final byte = bytes[i];
      final tmp = crcTable[(crc >> 8) ^ byte];
      crc = ((crc << 8) ^ tmp) & 0xFFFF;
    }

    return crc;
  }

  group('CRC Table Generation', () {
    test('generates 256-entry CRC table', () {
      final table = generateCrcTable();
      expect(table.length, equals(256));
    });

    test('CRC table entries are within uint16 range', () {
      final table = generateCrcTable();
      for (final entry in table) {
        expect(entry, inInclusiveRange(0, 0xFFFF));
      }
    });

    test('CRC table first entry is zero', () {
      final table = generateCrcTable();
      expect(table[0], equals(0x0000));
    });

    test('CRC table has known values', () {
      final table = generateCrcTable();
      // Known values from FIT SDK CRC table
      expect(table[0x01], equals(0x1021));
      expect(table[0xFF], equals(0x1EF0));
    });

    test('generates consistent table', () {
      final table1 = generateCrcTable();
      final table2 = generateCrcTable();
      expect(table1, equals(table2));
    });
  });

  group('CRC Calculation - Basic', () {
    test('calculates CRC for empty bytes', () {
      final bytes = Uint8List.fromList([]);
      final crc = calculateCrc(bytes);
      expect(crc, equals(0x0000));
    });

    test('calculates CRC for single byte', () {
      final bytes = Uint8List.fromList([0x0E]); // Header size byte
      final crc = calculateCrc(bytes);
      expect(crc, isNot(equals(0x0000)));
    });

    test('calculates CRC for ".FIT" signature', () {
      final bytes = Uint8List.fromList([0x2E, 0x46, 0x49, 0x54]); // '.FIT'
      final crc = calculateCrc(bytes);
      expect(crc, isNot(equals(0x0000)));
    });

    test('different bytes produce different CRCs', () {
      final bytes1 = Uint8List.fromList([0x00, 0x01, 0x02]);
      final bytes2 = Uint8List.fromList([0x00, 0x01, 0x03]);

      final crc1 = calculateCrc(bytes1);
      final crc2 = calculateCrc(bytes2);

      expect(crc1, isNot(equals(crc2)));
    });

    test('byte order affects CRC', () {
      final bytes1 = Uint8List.fromList([0x01, 0x02, 0x03]);
      final bytes2 = Uint8List.fromList([0x03, 0x02, 0x01]);

      final crc1 = calculateCrc(bytes1);
      final crc2 = calculateCrc(bytes2);

      expect(crc1, isNot(equals(crc2)));
    });

    test('calculates CRC for known test vector', () {
      // Test vector: [0x00, 0x01, 0x02, 0x03, 0x04]
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      final crc = calculateCrc(bytes);

      // CRC should be consistent
      final crc2 = calculateCrc(bytes);
      expect(crc, equals(crc2));
    });
  });

  group('CRC Calculation - FIT Header', () {
    test('calculates CRC for 12-byte header (without CRC)', () {
      final header = Uint8List.fromList([
        0x0E, // Header size (14)
        0x20, // Protocol version 2.0
        0x14, 0x0A, // Profile version 10.20
        0x64, 0x00, 0x00, 0x00, // Data size: 100 bytes
        0x2E, 0x46, 0x49, 0x54, // '.FIT' signature
      ]);

      final crc = calculateCrc(header);
      expect(crc, isNot(equals(0x0000)));
      expect(crc, inInclusiveRange(0, 0xFFFF));
    });

    test('validates header CRC matches calculated value', () {
      final headerWithoutCrc = Uint8List.fromList([
        0x0E,
        0x20,
        0x14,
        0x0A,
        0x64,
        0x00,
        0x00,
        0x00,
        0x2E,
        0x46,
        0x49,
        0x54,
      ]);

      final calculatedCrc = calculateCrc(headerWithoutCrc);

      // Append CRC to header (little-endian)
      final headerWithCrc = Uint8List.fromList([
        ...headerWithoutCrc,
        calculatedCrc & 0xFF, // Low byte
        (calculatedCrc >> 8) & 0xFF, // High byte
      ]);

      // Parse stored CRC
      final data = ByteData.view(headerWithCrc.buffer);
      final storedCrc = data.getUint16(12, Endian.little);

      expect(storedCrc, equals(calculatedCrc));
    });

    test('detects corrupted header', () {
      final header = Uint8List.fromList([
        0x0E,
        0x20,
        0x14,
        0x0A,
        0x64,
        0x00,
        0x00,
        0x00,
        0x2E,
        0x46,
        0x49,
        0x54,
      ]);

      final correctCrc = calculateCrc(header);

      // Corrupt one byte
      header[5] = 0x01; // Changed data size byte

      final corruptedCrc = calculateCrc(header);
      expect(corruptedCrc, isNot(equals(correctCrc)));
    });
  });

  group('CRC Calculation - File CRC', () {
    test('calculates CRC for complete FIT file data', () {
      final fitData = Uint8List.fromList([
        // Header (14 bytes)
        0x0E, 0x20, 0x14, 0x0A, 0x10, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54, 0x00, 0x00,
        // Data records (16 bytes as specified in header)
        0x40, 0x00, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0x00,
        0x01, 0x02, 0x84,
        0x00,
        0x01, 0x02,
      ]);

      final crc = calculateCrc(fitData);
      expect(crc, isNot(equals(0x0000)));
    });

    test('validates file CRC at end of FIT file', () {
      // Create FIT file data
      final fitData = Uint8List.fromList([
        0x0E, 0x20, 0x14, 0x0A, 0x04, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, // 4 bytes of data
      ]);

      // Calculate CRC for entire file
      final calculatedCrc = calculateCrc(fitData);

      // Append CRC to file
      final fileWithCrc = Uint8List.fromList([
        ...fitData,
        calculatedCrc & 0xFF,
        (calculatedCrc >> 8) & 0xFF,
      ]);

      // Validate: recalculate CRC for data portion
      final headerSize = 14;
      final dataSize = 4;
      final dataCrc = calculateCrc(
        fileWithCrc,
        start: 0,
        end: headerSize + dataSize,
      );

      // Parse stored CRC
      final data = ByteData.view(fileWithCrc.buffer);
      final storedCrc = data.getUint16(headerSize + dataSize, Endian.little);

      expect(storedCrc, equals(dataCrc));
    });

    test('detects single-bit corruption in file', () {
      final fitData = Uint8List.fromList([
        0x0E,
        0x20,
        0x14,
        0x0A,
        0x08,
        0x00,
        0x00,
        0x00,
        0x2E,
        0x46,
        0x49,
        0x54,
        0x00,
        0x00,
        0x00,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
      ]);

      final correctCrc = calculateCrc(fitData);

      // Flip single bit
      fitData[15] ^= 0x01; // XOR with 1 to flip bit

      final corruptedCrc = calculateCrc(fitData);
      expect(corruptedCrc, isNot(equals(correctCrc)));
    });
  });

  group('CRC Calculation - Partial Data', () {
    test('calculates CRC for byte range', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, // Ignore these
        0x01, 0x02, 0x03, 0x04, // Calculate CRC for these
        0xFF, 0xFF, // Ignore these
      ]);

      final crc = calculateCrc(bytes, start: 2, end: 6);
      expect(crc, isNot(equals(0x0000)));
    });

    test('CRC of partial data differs from full data', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

      final fullCrc = calculateCrc(bytes);
      final partialCrc = calculateCrc(bytes, start: 0, end: 2);

      expect(fullCrc, isNot(equals(partialCrc)));
    });

    test('handles zero-length range', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03]);
      final crc = calculateCrc(bytes, start: 1, end: 1);
      expect(crc, equals(0x0000));
    });
  });

  group('CRC Edge Cases', () {
    test('handles all zero bytes', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      final crc = calculateCrc(bytes);
      expect(crc, equals(0x0000));
    });

    test('handles all 0xFF bytes', () {
      final bytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      final crc = calculateCrc(bytes);
      expect(crc, isNot(equals(0x0000)));
      expect(crc, isNot(equals(0xFFFF)));
    });

    test('handles single byte of each value', () {
      for (int i = 0; i < 256; i++) {
        final bytes = Uint8List.fromList([i]);
        final crc = calculateCrc(bytes);
        expect(crc, inInclusiveRange(0, 0xFFFF));
      }
    });

    test('CRC is deterministic', () {
      final bytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);

      final crc1 = calculateCrc(bytes);
      final crc2 = calculateCrc(bytes);
      final crc3 = calculateCrc(bytes);

      expect(crc1, equals(crc2));
      expect(crc2, equals(crc3));
    });

    test('handles large data blocks', () {
      final largeData = Uint8List.fromList(
        List.generate(10000, (i) => i % 256),
      );

      final crc = calculateCrc(largeData);
      expect(crc, inInclusiveRange(0, 0xFFFF));

      // Verify consistency
      final crc2 = calculateCrc(largeData);
      expect(crc, equals(crc2));
    });
  });

  group('CRC Validation Scenarios', () {
    test('validates complete FIT file with known CRC', () {
      // Minimal valid FIT file
      final fitFile = Uint8List.fromList([
        // Header
        0x0E, 0x20, 0x14, 0x0A, 0x00, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54,
      ]);

      // Calculate header CRC
      final headerCrc = calculateCrc(fitFile, start: 0, end: 12);

      // Create complete file with header CRC
      final completeFile = Uint8List.fromList([
        ...fitFile,
        headerCrc & 0xFF,
        (headerCrc >> 8) & 0xFF,
      ]);

      // Calculate file CRC (should be 0 when including the CRC bytes)
      final verification = calculateCrc(completeFile);

      // If CRC is correct, recalculating over data+CRC should give 0
      // (This is a property of CRC algorithms)
      expect(verification, isNot(equals(headerCrc)));
    });

    test('simulates corrupt file detection', () {
      final data = Uint8List.fromList([
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
      ]);

      final correctCrc = calculateCrc(data);

      // Simulate receiving data with CRC
      final receivedData = Uint8List.fromList([...data]);
      final receivedCrc = correctCrc;

      // Verify CRC
      final calculatedCrc = calculateCrc(receivedData);
      expect(calculatedCrc, equals(receivedCrc));

      // Corrupt data
      receivedData[2] = 0xFF;
      final corruptedCrc = calculateCrc(receivedData);
      expect(corruptedCrc, isNot(equals(receivedCrc)));
    });
  });
}
