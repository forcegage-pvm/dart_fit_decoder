/// FIT file header structure (14 bytes).
library;

import 'dart:typed_data';

import 'exceptions.dart';

/// Represents the 14-byte FIT file header.
class FitHeader {
  /// Header size (always 14 for current protocol).
  final int headerSize;

  /// Protocol version (e.g., 0x20 = 2.0).
  final int protocolVersion;

  /// Profile version (e.g., 0x0A14 = 10.20).
  final int profileVersion;

  /// Size of data records in bytes.
  final int dataSize;

  /// FIT file signature ('.FIT' = 0x5449462E in little-endian).
  final String dataType;

  /// Optional CRC of the header (bytes 0-11).
  final int? crc;

  const FitHeader({
    required this.headerSize,
    required this.protocolVersion,
    required this.profileVersion,
    required this.dataSize,
    required this.dataType,
    this.crc,
  });

  /// Parse header from bytes.
  factory FitHeader.parse(Uint8List bytes) {
    if (bytes.length < 12) {
      throw InvalidHeaderException('Header too short: ${bytes.length} bytes (minimum 12 required)');
    }

    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes);

    // Byte 0: Header size
    final headerSize = data.getUint8(0);
    if (headerSize != 14 && headerSize != 12) {
      throw InvalidHeaderException('Invalid header size: $headerSize (expected 12 or 14)');
    }

    // Byte 1: Protocol version
    final protocolVersion = data.getUint8(1);

    // Bytes 2-3: Profile version (little-endian)
    final profileVersion = data.getUint16(2, Endian.little);

    // Bytes 4-7: Data size (little-endian)
    final dataSize = data.getUint32(4, Endian.little);

    // Bytes 8-11: Data type signature
    final dataType = String.fromCharCodes(bytes.sublist(8, 12));
    if (dataType != '.FIT') {
      throw InvalidHeaderException('Invalid data type signature: "$dataType" (expected ".FIT")');
    }

    // Bytes 12-13: Optional CRC (only if header size is 14)
    int? crc;
    if (headerSize == 14 && bytes.length >= 14) {
      crc = data.getUint16(12, Endian.little);
    }

    return FitHeader(
      headerSize: headerSize,
      protocolVersion: protocolVersion,
      profileVersion: profileVersion,
      dataSize: dataSize,
      dataType: dataType,
      crc: crc,
    );
  }

  /// Get protocol version as decimal (e.g., 2.0).
  double get protocolVersionDecimal => (protocolVersion >> 4) + (protocolVersion & 0x0F) / 10.0;

  /// Get profile version as decimal (e.g., 10.20).
  double get profileVersionDecimal {
    final major = profileVersion ~/ 100;
    final minor = profileVersion % 100;
    return major + minor / 100.0;
  }

  @override
  String toString() {
    return 'FitHeader('
        'size=$headerSize, '
        'protocol=${protocolVersionDecimal.toStringAsFixed(1)}, '
        'profile=${profileVersionDecimal.toStringAsFixed(2)}, '
        'dataSize=$dataSize, '
        'crc=${crc?.toRadixString(16) ?? "none"}'
        ')';
  }
}
