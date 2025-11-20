import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('FitHeader', () {
    test('parses valid header correctly', () {
      final headerBytes = Uint8List.fromList([
        14, // Header size
        0x20, // Protocol version 2.0
        0x14, 0x0A, // Profile version 10.20
        0x64, 0x00, 0x00, 0x00, // Data size: 100 bytes
        0x2E, 0x46, 0x49, 0x54, // '.FIT' signature
        0xAB, 0xCD, // CRC
      ]);

      final header = FitHeader.parse(headerBytes);

      expect(header.headerSize, equals(14));
      expect(header.protocolVersion, equals(0x20));
      expect(header.profileVersion, equals(0x0A14));
      expect(header.dataSize, equals(100));
      expect(header.dataType, equals('.FIT'));
      expect(header.crc, equals(0xCDAB));
    });

    test('throws InvalidHeaderException for short header', () {
      final shortBytes = Uint8List.fromList([1, 2, 3, 4]);

      expect(
        () => FitHeader.parse(shortBytes),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('throws InvalidHeaderException for invalid signature', () {
      final invalidBytes = Uint8List.fromList([
        14,
        0x20,
        0x14, 0x0A,
        0x64, 0x00, 0x00, 0x00,
        0x46, 0x41, 0x4B, 0x45, // 'FAKE' instead of '.FIT'
        0xAB, 0xCD,
      ]);

      expect(
        () => FitHeader.parse(invalidBytes),
        throwsA(isA<InvalidHeaderException>()),
      );
    });

    test('calculates protocol version correctly', () {
      final headerBytes = Uint8List.fromList([
        14,
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
        0xAB,
        0xCD,
      ]);

      final header = FitHeader.parse(headerBytes);
      expect(header.protocolVersionDecimal, equals(2.0));
    });
  });

  group('FitBaseTypes', () {
    test('getById returns correct base type', () {
      expect(FitBaseTypes.getById(0x00)?.name, equals('enum'));
      expect(FitBaseTypes.getById(0x02)?.name, equals('uint8'));
      expect(FitBaseTypes.getById(0x84)?.name, equals('uint16'));
      expect(FitBaseTypes.getById(0x88)?.name, equals('float32'));
    });

    test('getById returns null for invalid ID', () {
      expect(FitBaseTypes.getById(0xFF), isNull);
    });

    test('all base types have valid properties', () {
      for (final baseType in FitBaseTypes.all) {
        expect(baseType.id, isNotNull);
        expect(baseType.name, isNotEmpty);
        expect(baseType.size, greaterThan(0));
      }
    });
  });

  group('FitMessageType', () {
    test('getName returns correct message name', () {
      expect(FitMessageType.getName(0), equals('file_id'));
      expect(FitMessageType.getName(18), equals('session'));
      expect(FitMessageType.getName(19), equals('lap'));
      expect(FitMessageType.getName(20), equals('record'));
      expect(FitMessageType.getName(206), equals('field_description'));
    });

    test('getName returns null for unknown message number', () {
      expect(FitMessageType.getName(9999), isNull);
    });

    test('isDeveloperFieldMessage identifies developer messages', () {
      expect(FitMessageType.isDeveloperFieldMessage(206), isTrue);
      expect(FitMessageType.isDeveloperFieldMessage(207), isTrue);
      expect(FitMessageType.isDeveloperFieldMessage(20), isFalse);
    });
  });

  group('FitDecoder', () {
    test('decodes header from minimal FIT file', () {
      final fitBytes = Uint8List.fromList([
        14, 0x20, 0x14, 0x0A, 0x10, 0x00, 0x00, 0x00,
        0x2E, 0x46, 0x49, 0x54, 0x00, 0x00,
        // Minimal data (16 bytes as specified in header)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);

      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      expect(fitFile.header.headerSize, equals(14));
      expect(fitFile.header.dataSize, equals(16));
    });
  });

  group('FitField', () {
    test('scaledValue applies scale correctly', () {
      final field = FitField(
        fieldNumber: 1,
        name: 'speed',
        baseType: FitBaseTypes.uint16,
        value: 1000,
        scale: 1000.0,
        units: 'm/s',
      );

      expect(field.scaledValue, equals(1.0));
    });

    test('scaledValue applies offset correctly', () {
      final field = FitField(
        fieldNumber: 2,
        name: 'temperature',
        baseType: FitBaseTypes.sint8,
        value: 100,
        offset: 50.0,
        units: '°C',
      );

      expect(field.scaledValue, equals(50.0));
    });

    test('isValid returns false for invalid values', () {
      final field = FitField(
        fieldNumber: 3,
        name: 'heart_rate',
        baseType: FitBaseTypes.uint8,
        value: 0xFF, // Invalid value for uint8
      );

      expect(field.isValid, isFalse);
    });
  });
}
