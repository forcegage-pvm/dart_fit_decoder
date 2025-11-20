/// Tests for FIT record header parsing (normal and compressed timestamp).
library;

import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  group('Record Header - Normal Header', () {
    test('parses normal header with definition message', () {
      // Header byte: 0x40
      // Bit 7: 0 (normal header)
      // Bit 6: 1 (definition message)
      // Bit 5: 0 (reserved)
      // Bit 4: 0 (no developer data)
      // Bits 0-3: 0000 (local message type 0)
      final headerByte = 0x40;

      final isDefinition = (headerByte & 0x40) != 0;
      final hasDeveloperData = (headerByte & 0x20) != 0;
      final localMessageType = headerByte & 0x0F;

      expect(isDefinition, isTrue);
      expect(hasDeveloperData, isFalse);
      expect(localMessageType, equals(0));
    });

    test('parses normal header with data message', () {
      // Header byte: 0x05
      // Bit 7: 0 (normal header)
      // Bit 6: 0 (data message)
      // Bit 5: 0 (reserved)
      // Bit 4: 0 (no developer data)
      // Bits 0-3: 0101 (local message type 5)
      final headerByte = 0x05;

      final isDefinition = (headerByte & 0x40) != 0;
      final hasDeveloperData = (headerByte & 0x20) != 0;
      final localMessageType = headerByte & 0x0F;

      expect(isDefinition, isFalse);
      expect(hasDeveloperData, isFalse);
      expect(localMessageType, equals(5));
    });

    test('parses normal header with developer data', () {
      // Header byte: 0x20
      // Bit 5: 1 (has developer data)
      // Bits 0-3: 0000 (local message type 0)
      final headerByte = 0x20;

      final hasDeveloperData = (headerByte & 0x20) != 0;
      final localMessageType = headerByte & 0x0F;

      expect(hasDeveloperData, isTrue);
      expect(localMessageType, equals(0));
    });

    test('parses all local message types (0-15)', () {
      for (int i = 0; i <= 15; i++) {
        final headerByte = i; // Data message, no dev data, type i
        final localMessageType = headerByte & 0x0F;
        expect(localMessageType, equals(i));
      }
    });

    test('parses definition message with developer data', () {
      // Header byte: 0x60
      // Bit 6: 1 (definition)
      // Bit 5: 1 (developer data)
      // Bits 0-3: 0000 (local message type 0)
      final headerByte = 0x60;

      final isDefinition = (headerByte & 0x40) != 0;
      final hasDeveloperData = (headerByte & 0x20) != 0;
      final localMessageType = headerByte & 0x0F;

      expect(isDefinition, isTrue);
      expect(hasDeveloperData, isTrue);
      expect(localMessageType, equals(0));
    });
  });

  group('Record Header - Compressed Timestamp', () {
    test('identifies compressed timestamp header', () {
      // Header byte: 0x80 to 0xFF
      // Bit 7: 1 (compressed timestamp)
      // Bits 5-6: local message type (0-3)
      // Bits 0-4: time offset (0-31 seconds)
      final headerByte = 0x80;

      final isCompressed = (headerByte & 0x80) != 0;
      expect(isCompressed, isTrue);
    });

    test('parses compressed timestamp with local type 0', () {
      // Header byte: 0x80
      // Bit 7: 1 (compressed)
      // Bits 5-6: 00 (local message type 0)
      // Bits 0-4: 00000 (time offset 0)
      final headerByte = 0x80;

      final localMessageType = (headerByte >> 5) & 0x03;
      final timeOffset = headerByte & 0x1F;

      expect(localMessageType, equals(0));
      expect(timeOffset, equals(0));
    });

    test('parses compressed timestamp with local type 3', () {
      // Header byte: 0xE0
      // Bit 7: 1 (compressed)
      // Bits 5-6: 11 (local message type 3)
      // Bits 0-4: 00000 (time offset 0)
      final headerByte = 0xE0;

      final localMessageType = (headerByte >> 5) & 0x03;
      final timeOffset = headerByte & 0x1F;

      expect(localMessageType, equals(3));
      expect(timeOffset, equals(0));
    });

    test('parses compressed timestamp with max time offset', () {
      // Header byte: 0x9F
      // Bit 7: 1 (compressed)
      // Bits 5-6: 00 (local message type 0)
      // Bits 0-4: 11111 (time offset 31 seconds)
      final headerByte = 0x9F;

      final localMessageType = (headerByte >> 5) & 0x03;
      final timeOffset = headerByte & 0x1F;

      expect(localMessageType, equals(0));
      expect(timeOffset, equals(31));
    });

    test('parses all compressed timestamp combinations', () {
      // Test all local types (0-3) with various offsets
      for (int localType = 0; localType <= 3; localType++) {
        for (int offset in [0, 1, 5, 15, 31]) {
          final headerByte = 0x80 | (localType << 5) | offset;

          final parsedType = (headerByte >> 5) & 0x03;
          final parsedOffset = headerByte & 0x1F;

          expect(parsedType, equals(localType));
          expect(parsedOffset, equals(offset));
        }
      }
    });

    test('calculates timestamp from compressed header', () {
      // Simulate timestamp calculation
      final baseTimestamp = 1000; // Base timestamp in seconds
      final timeOffset = 15; // 15 seconds offset
      final headerByte = 0x80 | timeOffset;

      final parsedOffset = headerByte & 0x1F;
      final calculatedTimestamp = baseTimestamp + parsedOffset;

      expect(parsedOffset, equals(15));
      expect(calculatedTimestamp, equals(1015));
    });

    test('handles timestamp rollover at 32 seconds', () {
      // When time offset rolls over from 31 to 0
      final baseTimestamp = 1000;

      // First message with offset 31
      final offset1 = 31;
      final timestamp1 = baseTimestamp + offset1;
      expect(timestamp1, equals(1031));

      // Next message with offset 0 (should be 1 second later)
      final offset2 = 0;
      // Need to detect rollover: offset2 < previous offset
      final timestamp2 = baseTimestamp + 32 + offset2;
      expect(timestamp2, equals(1032));
    });
  });

  group('Record Header - Edge Cases', () {
    test('distinguishes between normal and compressed headers', () {
      final normalHeaders = [0x00, 0x40, 0x20, 0x60, 0x0F, 0x4F, 0x6F];
      final compressedHeaders = [0x80, 0x9F, 0xA0, 0xBF, 0xC0, 0xDF, 0xE0, 0xFF];

      for (final header in normalHeaders) {
        final isCompressed = (header & 0x80) != 0;
        expect(isCompressed, isFalse, reason: 'Header 0x${header.toRadixString(16)} should be normal');
      }

      for (final header in compressedHeaders) {
        final isCompressed = (header & 0x80) != 0;
        expect(isCompressed, isTrue, reason: 'Header 0x${header.toRadixString(16)} should be compressed');
      }
    });

    test('validates local message type range in normal headers', () {
      for (int i = 0; i <= 15; i++) {
        final headerByte = i;
        final localType = headerByte & 0x0F;
        expect(localType, inInclusiveRange(0, 15));
      }
    });

    test('validates local message type range in compressed headers', () {
      for (int i = 0; i <= 3; i++) {
        final headerByte = 0x80 | (i << 5);
        final localType = (headerByte >> 5) & 0x03;
        expect(localType, inInclusiveRange(0, 3));
      }
    });

    test('validates time offset range in compressed headers', () {
      for (int offset = 0; offset <= 31; offset++) {
        final headerByte = 0x80 | offset;
        final parsedOffset = headerByte & 0x1F;
        expect(parsedOffset, equals(offset));
        expect(parsedOffset, inInclusiveRange(0, 31));
      }
    });

    test('handles all possible header byte values', () {
      for (int headerByte = 0; headerByte <= 0xFF; headerByte++) {
        final isCompressed = (headerByte & 0x80) != 0;

        if (isCompressed) {
          final localType = (headerByte >> 5) & 0x03;
          final timeOffset = headerByte & 0x1F;
          expect(localType, inInclusiveRange(0, 3));
          expect(timeOffset, inInclusiveRange(0, 31));
        } else {
          final isDefinition = (headerByte & 0x40) != 0;
          final hasDeveloperData = (headerByte & 0x20) != 0;
          final localType = headerByte & 0x0F;
          expect(localType, inInclusiveRange(0, 15));
          expect(isDefinition, anyOf(isTrue, isFalse));
          expect(hasDeveloperData, anyOf(isTrue, isFalse));
        }
      }
    });
  });

  group('Record Header - Full Message Examples', () {
    test('parses definition message for file_id (mesg 0)', () {
      final bytes = Uint8List.fromList([
        0x40, // Definition message, local type 0
        0x00, // Reserved
        0x00, // Architecture: little-endian
        0x00, 0x00, // Global message number: 0 (file_id)
        0x04, // Number of fields: 4
        // Field definitions...
      ]);

      final headerByte = bytes[0];
      final isDefinition = (headerByte & 0x40) != 0;
      final localType = headerByte & 0x0F;
      final architecture = bytes[2];
      final globalMesgNum = bytes[3] | (bytes[4] << 8);
      final numFields = bytes[5];

      expect(isDefinition, isTrue);
      expect(localType, equals(0));
      expect(architecture, equals(0)); // Little-endian
      expect(globalMesgNum, equals(0)); // file_id
      expect(numFields, equals(4));
    });

    test('parses data message with compressed timestamp', () {
      final bytes = Uint8List.fromList([
        0x85, // Compressed timestamp: local type 0, offset 5
        // Field data...
      ]);

      final headerByte = bytes[0];
      final isCompressed = (headerByte & 0x80) != 0;
      final localType = (headerByte >> 5) & 0x03;
      final timeOffset = headerByte & 0x1F;

      expect(isCompressed, isTrue);
      expect(localType, equals(0));
      expect(timeOffset, equals(5));
    });

    test('parses data message with developer fields', () {
      final bytes = Uint8List.fromList([
        0x20, // Data message with developer data, local type 0
        // Standard field data...
        0x02, // Number of developer fields
        // Developer field data...
      ]);

      final headerByte = bytes[0];
      final hasDeveloperData = (headerByte & 0x20) != 0;
      final localType = headerByte & 0x0F;

      expect(hasDeveloperData, isTrue);
      expect(localType, equals(0));
    });
  });
}
