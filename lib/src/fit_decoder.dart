/// Main FIT file decoder.
library;

import 'dart:typed_data';

import 'exceptions.dart';
import 'fit_file.dart';
import 'fit_header.dart';
import 'fit_message.dart';

/// Decoder for parsing FIT files.
class FitDecoder {
  /// Raw FIT file bytes.
  final Uint8List bytes;

  /// Current position in the byte stream.
  int _position = 0;

  /// Parsed header.
  FitHeader? _header;

  /// All parsed messages.
  final List<FitMessage> _messages = [];

  FitDecoder(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  /// Decode the FIT file and return a FitFile object.
  FitFile decode() {
    // Parse header
    _header = _parseHeader();

    // TODO: Implement full decoding logic
    // - Parse definition messages
    // - Parse data messages
    // - Handle developer fields
    // - Validate CRC

    // For now, return a FitFile with just the header
    return FitFile(
      header: _header!,
      messages: _messages,
      fileCrc: null,
    );
  }

  /// Parse the FIT file header.
  FitHeader _parseHeader() {
    if (bytes.length < 14) {
      throw InvalidHeaderException('File too small: ${bytes.length} bytes (minimum 14 required)');
    }

    final header = FitHeader.parse(bytes.sublist(0, 14));
    _position = header.headerSize;

    return header;
  }

  /// Check if more bytes are available.
  bool get _hasMoreBytes => _position < bytes.length;

  /// Get remaining bytes count.
  int get _remainingBytes => bytes.length - _position;

  /// Read a single byte.
  int _readByte() {
    if (!_hasMoreBytes) {
      throw InsufficientDataException(1, 0);
    }
    return bytes[_position++];
  }

  /// Read multiple bytes.
  Uint8List _readBytes(int count) {
    if (_remainingBytes < count) {
      throw InsufficientDataException(count, _remainingBytes);
    }
    final result = bytes.sublist(_position, _position + count);
    _position += count;
    return result;
  }
}
