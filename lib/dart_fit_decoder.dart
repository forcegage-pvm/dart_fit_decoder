/// A comprehensive Dart package for parsing and decoding Garmin FIT files.
///
/// This library provides complete support for the FIT (Flexible and Interoperable
/// Data Transfer) protocol used by Garmin and other fitness device manufacturers.
///
/// Features:
/// - Parse FIT file headers and validate protocol versions
/// - Decode definition messages (local to global message type mapping)
/// - Extract data messages with proper field value parsing
/// - Full support for developer fields (custom sensor data)
/// - CRC validation for file integrity
/// - Geodesic distance calculations
///
/// Example:
/// ```dart
/// import 'dart:io';
/// import 'package:dart_fit_decoder/dart_fit_decoder.dart';
///
/// void main() async {
///   final bytes = await File('activity.fit').readAsBytes();
///   final decoder = FitDecoder(bytes);
///   final fitFile = decoder.decode();
///
///   print('Protocol Version: ${fitFile.header.protocolVersion}');
///   print('Total Messages: ${fitFile.messages.length}');
/// }
/// ```
library;

export 'src/developer_field.dart';
export 'src/exceptions.dart';
export 'src/fit_base_type.dart';
export 'src/fit_data_message.dart';
export 'src/fit_decoder.dart';
export 'src/fit_definition_message.dart';
export 'src/fit_field.dart';
export 'src/fit_file.dart';
export 'src/fit_header.dart';
export 'src/fit_message.dart';
export 'src/fit_message_type.dart';
