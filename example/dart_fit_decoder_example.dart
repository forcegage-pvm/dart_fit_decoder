import 'dart:io';
import 'dart:typed_data';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';

/// Example demonstrating basic FIT file parsing.
void main() async {
  print('=== Dart FIT Decoder Example ===\n');
  
  // Example 1: Parse FIT file header
  print('Example 1: Parse FIT File Header');
  print('-' * 40);
  
  // Create a minimal valid FIT file header for demonstration
  final headerBytes = Uint8List.fromList([
    14, // Header size
    0x20, // Protocol version 2.0
    0x14, 0x0A, // Profile version 10.20
    0x10, 0x00, 0x00, 0x00, // Data size: 16 bytes
    0x2E, 0x46, 0x49, 0x54, // '.FIT' signature
    0x00, 0x00, // CRC (placeholder)
  ]);
  
  try {
    final header = FitHeader.parse(headerBytes);
    print('Header Size: ${header.headerSize} bytes');
    print('Protocol Version: ${header.protocolVersionDecimal.toStringAsFixed(1)}');
    print('Profile Version: ${header.profileVersionDecimal.toStringAsFixed(2)}');
    print('Data Size: ${header.dataSize} bytes');
    print('Data Type: ${header.dataType}');
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n');
  
  // Example 2: FIT File Decoding (placeholder for now)
  print('Example 2: Decode FIT File');
  print('-' * 40);
  print('Note: Full FIT file decoding is under development.');
  print('The decoder currently parses the header and validates the file structure.');
  
  // If you have a real FIT file, you can test it like this:
  // final fitFile = File('path/to/your/activity.fit');
  // if (await fitFile.exists()) {
  //   final bytes = await fitFile.readAsBytes();
  //   final decoder = FitDecoder(bytes);
  //   final fitFile = decoder.decode();
  //   print('Decoded FIT file: $fitFile');
  // }
  
  print('\n');
  
  // Example 3: Base Types
  print('Example 3: FIT Base Types');
  print('-' * 40);
  print('Available base types:');
  for (final baseType in FitBaseTypes.all) {
    print('  ${baseType.name.padRight(10)} - ID: 0x${baseType.id.toRadixString(16).padLeft(2, "0")}, '
          'Size: ${baseType.size} byte(s), Invalid: 0x${baseType.invalidValue?.toRadixString(16) ?? "N/A"}');
  }
  
  print('\n');
  
  // Example 4: Message Types
  print('Example 4: FIT Message Types');
  print('-' * 40);
  final commonTypes = [0, 18, 19, 20, 21, 23, 206, 207];
  for (final typeNum in commonTypes) {
    final name = FitMessageType.getName(typeNum) ?? 'unknown';
    print('  Message #$typeNum: $name');
  }
  
  print('\n=== End of Examples ===');
}

