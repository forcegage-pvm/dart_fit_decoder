/// Tests for binary reading operations with different endianness.
library;

import 'dart:typed_data';
import 'package:test/test.dart';

void main() {
  group('Binary Reader - Little Endian', () {
    test('reads uint8 correctly', () {
      final bytes = Uint8List.fromList([0xFF, 0x00, 0x7F, 0x01]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint8(0), equals(0xFF));
      expect(data.getUint8(1), equals(0x00));
      expect(data.getUint8(2), equals(0x7F));
      expect(data.getUint8(3), equals(0x01));
    });

    test('reads sint8 correctly', () {
      final bytes = Uint8List.fromList([0x7F, 0x80, 0xFF, 0x01]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getInt8(0), equals(127));
      expect(data.getInt8(1), equals(-128));
      expect(data.getInt8(2), equals(-1));
      expect(data.getInt8(3), equals(1));
    });

    test('reads uint16 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, // 65535
        0x00, 0x00, // 0
        0x01, 0x00, // 1
        0x34, 0x12, // 4660
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint16(0, Endian.little), equals(0xFFFF));
      expect(data.getUint16(2, Endian.little), equals(0x0000));
      expect(data.getUint16(4, Endian.little), equals(0x0001));
      expect(data.getUint16(6, Endian.little), equals(0x1234));
    });

    test('reads sint16 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0x7F, // 32767
        0x00, 0x80, // -32768
        0xFF, 0xFF, // -1
        0x01, 0x00, // 1
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getInt16(0, Endian.little), equals(32767));
      expect(data.getInt16(2, Endian.little), equals(-32768));
      expect(data.getInt16(4, Endian.little), equals(-1));
      expect(data.getInt16(6, Endian.little), equals(1));
    });

    test('reads uint32 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0xFF, // 4294967295
        0x00, 0x00, 0x00, 0x00, // 0
        0x78, 0x56, 0x34, 0x12, // 305419896
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint32(0, Endian.little), equals(0xFFFFFFFF));
      expect(data.getUint32(4, Endian.little), equals(0x00000000));
      expect(data.getUint32(8, Endian.little), equals(0x12345678));
    });

    test('reads sint32 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0x7F, // 2147483647
        0x00, 0x00, 0x00, 0x80, // -2147483648
        0xFF, 0xFF, 0xFF, 0xFF, // -1
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getInt32(0, Endian.little), equals(2147483647));
      expect(data.getInt32(4, Endian.little), equals(-2147483648));
      expect(data.getInt32(8, Endian.little), equals(-1));
    });

    test('reads float32 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x80, 0x3F, // 1.0
        0x00, 0x00, 0x00, 0x40, // 2.0
        0xDB, 0x0F, 0x49, 0x40, // 3.14159
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getFloat32(0, Endian.little), closeTo(1.0, 0.0001));
      expect(data.getFloat32(4, Endian.little), closeTo(2.0, 0.0001));
      expect(data.getFloat32(8, Endian.little), closeTo(3.14159, 0.0001));
    });

    test('reads float64 little-endian correctly', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F, // 1.0
        0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40, // 3.14159265359
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getFloat64(0, Endian.little), closeTo(1.0, 0.0001));
      expect(data.getFloat64(8, Endian.little), closeTo(3.14159265359, 0.0001));
    });

    test('reads null-terminated string correctly', () {
      final bytes = Uint8List.fromList([
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, // 'Hello\0'
        0x46, 0x49, 0x54, 0x00, // 'FIT\0'
      ]);

      String readString(Uint8List bytes, int offset, int maxLength) {
        final chars = <int>[];
        for (int i = 0; i < maxLength; i++) {
          final byte = bytes[offset + i];
          if (byte == 0) break;
          chars.add(byte);
        }
        return String.fromCharCodes(chars);
      }

      expect(readString(bytes, 0, 10), equals('Hello'));
      expect(readString(bytes, 6, 10), equals('FIT'));
    });
  });

  group('Binary Reader - Big Endian', () {
    test('reads uint16 big-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, // 65535
        0x12, 0x34, // 4660
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint16(0, Endian.big), equals(0xFFFF));
      expect(data.getUint16(2, Endian.big), equals(0x1234));
    });

    test('reads sint16 big-endian correctly', () {
      final bytes = Uint8List.fromList([
        0x7F, 0xFF, // 32767
        0x80, 0x00, // -32768
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getInt16(0, Endian.big), equals(32767));
      expect(data.getInt16(2, Endian.big), equals(-32768));
    });

    test('reads uint32 big-endian correctly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0xFF, // 4294967295
        0x12, 0x34, 0x56, 0x78, // 305419896
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint32(0, Endian.big), equals(0xFFFFFFFF));
      expect(data.getUint32(4, Endian.big), equals(0x12345678));
    });

    test('reads float32 big-endian correctly', () {
      final bytes = Uint8List.fromList([
        0x3F, 0x80, 0x00, 0x00, // 1.0
        0x40, 0x49, 0x0F, 0xDB, // 3.14159
      ]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getFloat32(0, Endian.big), closeTo(1.0, 0.0001));
      expect(data.getFloat32(4, Endian.big), closeTo(3.14159, 0.0001));
    });
  });

  group('Binary Reader - Invalid Values', () {
    test('identifies invalid uint8 value', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x00]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint8(0), equals(0xFF)); // Invalid for uint8
      expect(data.getUint8(1), equals(0xFE)); // Valid
      expect(data.getUint8(2), equals(0x00)); // Valid (invalid for uint8z)
    });

    test('identifies invalid sint8 value', () {
      final bytes = Uint8List.fromList([0x7F, 0x7E, 0x80]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getInt8(0), equals(0x7F)); // Invalid for sint8
      expect(data.getInt8(1), equals(0x7E)); // Valid
    });

    test('identifies invalid uint16 value', () {
      final bytes = Uint8List.fromList([0xFF, 0xFF, 0xFE, 0xFF]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint16(0, Endian.little), equals(0xFFFF)); // Invalid
      expect(data.getUint16(2, Endian.little), equals(0xFFFE)); // Valid
    });

    test('identifies invalid float32 value', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid pattern
        0x00, 0x00, 0x80, 0x3F, // Valid: 1.0
      ]);
      final data = ByteData.view(bytes.buffer);

      final invalid = data.getUint32(0, Endian.little);
      expect(invalid, equals(0xFFFFFFFF));

      final valid = data.getFloat32(4, Endian.little);
      expect(valid, closeTo(1.0, 0.0001));
    });
  });

  group('Binary Reader - Buffer Boundaries', () {
    test('throws on reading beyond buffer', () {
      final bytes = Uint8List.fromList([0x01, 0x02]);
      final data = ByteData.view(bytes.buffer);

      expect(() => data.getUint8(2), throwsRangeError);
      expect(() => data.getUint16(1, Endian.little), throwsRangeError);
      expect(() => data.getUint32(0, Endian.little), throwsRangeError);
    });

    test('reads at exact buffer boundaries', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final data = ByteData.view(bytes.buffer);

      expect(data.getUint8(3), equals(0x04)); // Last byte
      expect(data.getUint16(2, Endian.little), equals(0x0403)); // Last 2 bytes
      expect(data.getUint32(0, Endian.little), equals(0x04030201)); // All 4 bytes
    });
  });

  group('Binary Reader - Byte Arrays', () {
    test('reads byte array correctly', () {
      final bytes = Uint8List.fromList([
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
      ]);

      final slice1 = bytes.sublist(0, 4);
      final slice2 = bytes.sublist(4, 8);

      expect(slice1, equals([0x01, 0x02, 0x03, 0x04]));
      expect(slice2, equals([0x05, 0x06, 0x07, 0x08]));
    });

    test('detects invalid byte array (all 0xFF)', () {
      final bytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);

      bool isInvalidByteArray(Uint8List bytes) {
        return bytes.every((b) => b == 0xFF);
      }

      expect(isInvalidByteArray(bytes), isTrue);
      expect(isInvalidByteArray(Uint8List.fromList([0xFF, 0xFE])), isFalse);
    });
  });
}
