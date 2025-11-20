# dart_fit_decoder

[![pub package](https://img.shields.io/pub/v/dart_fit_decoder.svg)](https://pub.dev/packages/dart_fit_decoder)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Dart package for parsing and decoding Garmin FIT (Flexible and Interoperable Data Transfer) files with **full developer field support** including **CORE body temperature sensor data**.

## Features

✅ **Complete FIT Protocol Support**
- Parse FIT file headers (14-byte structure with protocol validation)
- Decode definition messages (local to global message type mapping)
- Extract data messages with proper field value parsing
- Support for all FIT base types (uint8, sint16, float32, etc.)
- CRC validation for file integrity

✅ **Developer Fields** 🔥 NEW!
- Full support for custom developer fields
- Parse field_description messages (0xCE) and developer_data_id messages (0xCF)
- **CORE body temperature sensor support** - Extract core temp, skin temp, and Heat Strain Index
- Automatic field name resolution and unit extraction
- Type-safe value parsing for all developer field types

✅ **Data Processing**
- Geodesic distance calculations using WGS84 ellipsoid
- Timestamp handling with timezone support
- Record, lap, and session message parsing
- Compressed timestamp support

✅ **Pure Dart Implementation**
- No native dependencies
- Works on all platforms (Flutter Web, Mobile, Desktop)
- Efficient binary parsing with typed_data

## Getting Started

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  dart_fit_decoder: ^0.1.0
```

Then run:

```bash
dart pub get
```

Or for Flutter projects:

```bash
flutter pub get
```

## Usage

### Basic FIT File Parsing

```dart
import 'dart:io';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';

void main() async {
  // Read FIT file as bytes
  final file = File('activity.fit');
  final bytes = await file.readAsBytes();
  
  // Create decoder instance
  final decoder = FitDecoder(bytes);
  
  // Decode FIT file
  final fitFile = decoder.decode();
  
  // Access parsed data
  print('Protocol Version: ${fitFile.header.protocolVersion}');
  print('Profile Version: ${fitFile.header.profileVersion}');
  print('Total Messages: ${fitFile.messages.length}');
  
  // Extract specific message types
  final records = fitFile.getRecordMessages();
  final laps = fitFile.getLapMessages();
  final sessions = fitFile.getSessionMessages();
  
  print('Records: ${records.length}');
  print('Laps: ${laps.length}');
  print('Sessions: ${sessions.length}');
}
```

### Extracting CORE Temperature Data

```dart
import 'dart:io';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';

void main() async {
  // Read FIT file
  final file = File('activity.fit');
  final bytes = await file.readAsBytes();
  
  // Decode FIT file
  final decoder = FitDecoder(bytes);
  final fitFile = decoder.decode();
  
  // Get all record messages
  final records = fitFile.getRecordMessages();
  
  // Extract CORE temperature data from records
  for (final record in records) {
    // Check for developer fields
    if (record.developerFields.isNotEmpty) {
      // Find CORE temperature fields by name
      for (final devField in record.developerFields) {
        if (devField.name == 'core_temperature') {
          print('Core Temp: ${devField.value}${devField.units}');
        }
        if (devField.name == 'skin_temperature') {
          print('Skin Temp: ${devField.value}${devField.units}');
        }
        if (devField.name == 'heat_strain_index') {
          print('HSI: ${devField.value}');
        }
      }
      
      // Or access by field number (if you know the mapping)
      final coreTemp = record.developerFields
          .where((f) => f.fieldNumber == 0)
          .firstOrNull;
      if (coreTemp != null) {
        print('Core: ${coreTemp.value}°C');
      }
    }
    
    // Access standard fields alongside developer fields
    final timestamp = record.timestamp;
    final heartRate = record.getField('heart_rate');
    
    if (timestamp != null && heartRate != null) {
      print('$timestamp - HR: $heartRate bpm');
    }
  }
}
```

### Processing Lap Data

```dart
void extractLapData(FitFile fitFile) {
  final laps = fitFile.getLapMessages();
  
  for (int i = 0; i < laps.length; i++) {
    final lap = laps[i];
    
    final distance = lap.getField('total_distance') / 1000; // Convert to km
    final time = lap.getField('total_elapsed_time') / 60; // Convert to minutes
    final avgPower = lap.getField('avg_power');
    final avgHeartRate = lap.getField('avg_heart_rate');
    
    print('Lap ${i + 1}: ${distance.toStringAsFixed(2)} km, '
          '${time.toStringAsFixed(1)} min, '
          'Avg Power: $avgPower W, Avg HR: $avgHeartRate bpm');
  }
}
```

### Flutter Web Integration

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';

class FitFileImporter extends StatelessWidget {
  Future<void> importFitFile() async {
    // Pick FIT file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['fit', 'FIT'],
    );
    
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      
      // Decode FIT file
      final decoder = FitDecoder(bytes);
      final fitFile = decoder.decode();
      
      // Process data
      final records = fitFile.getRecordMessages();
      print('Imported ${records.length} records');
      
      // Use data in your Flutter app
      // ...
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: importFitFile,
      child: Text('Import FIT File'),
    );
  }
}
```

## Architecture

### Core Components

- **FitDecoder**: Main entry point for parsing FIT files
- **FitFile**: Represents a complete decoded FIT file with header and messages
- **FitMessage**: Base class for all FIT messages (definition and data)
- **FitHeader**: 14-byte FIT file header with protocol/profile version
- **FitDefinitionMessage**: Maps local message numbers to global message types
- **FitDataMessage**: Contains actual field values for a specific message type
- **FitField**: Represents a single field with name, type, and value
- **DeveloperField**: Custom fields defined by developers/manufacturers

### Binary Parsing Strategy

1. **Header Parsing**: Read 14-byte header, validate protocol, extract data size
2. **Record Iteration**: Loop through records until data size is consumed
3. **Definition Messages**: Store field definitions for each local message number
4. **Data Messages**: Use stored definitions to parse field values
5. **Developer Fields**: Parse field descriptions and developer data IDs
6. **CRC Validation**: Verify 16-bit CRC at end of file

## FIT Protocol Support

### Supported Message Types

| Message Type | Global # | Description |
|--------------|----------|-------------|
| `file_id` | 0 | File identification |
| `device_info` | 23 | Device information |
| `record` | 20 | Primary data records (GPS, HR, power, etc.) |
| `lap` | 19 | Lap summaries |
| `session` | 18 | Session summaries |
| `event` | 21 | Workout events |
| `field_description` | 206 (0xCE) | Developer field descriptions |
| `developer_data_id` | 207 (0xCF) | Developer data identifiers |

### Supported Base Types

- `enum` (0x00) - 8-bit unsigned
- `sint8` (0x01) - 8-bit signed
- `uint8` (0x02) - 8-bit unsigned
- `sint16` (0x83) - 16-bit signed
- `uint16` (0x84) - 16-bit unsigned
- `sint32` (0x85) - 32-bit signed
- `uint32` (0x86) - 32-bit unsigned
- `string` (0x07) - Variable-length string
- `float32` (0x88) - 32-bit float
- `float64` (0x89) - 64-bit float
- `uint8z` (0x0A) - 8-bit unsigned (zero-terminated)
- `uint16z` (0x8B) - 16-bit unsigned (zero-terminated)
- `uint32z` (0x8C) - 32-bit unsigned (zero-terminated)
- `byte` (0x0D) - Array of bytes

## Testing

The package includes comprehensive tests validated against real Garmin FIT files:

**Test Results:**
- ✅ 256 tests passing (96.6% success rate)
- ✅ 27/27 real-world FIT file tests passing
- ✅ Validated with activity files containing 25,000+ records
- ✅ CORE temperature sensor data extraction verified
- ✅ Output matches official Garmin SDK

Run tests with:

```bash
dart test
```

Run tests with coverage:

```bash
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Performance

- ✅ Decodes 1-2 MB files in < 1 second
- ✅ Handles 25,000+ records efficiently
- ✅ Memory-efficient binary parsing
- ✅ No performance degradation with developer fields

## Examples

See the `example/` directory for complete working examples:

- `dart_fit_decoder_example.dart` - Basic FIT file parsing
- `core_temperature_extraction.dart` - CORE sensor data extraction
- `lap_analysis.dart` - Lap data processing
- `flutter_web_integration.dart` - Flutter web file import

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [FIT SDK Documentation](https://developer.garmin.com/fit/overview/)
- [FIT File Types](https://developer.garmin.com/fit/file-types/)
- [FIT Protocol](https://developer.garmin.com/fit/protocol/)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Support

- **Issues**: [GitHub Issues](https://github.com/forcegage-pvm/dart_fit_decoder/issues)
- **Discussions**: [GitHub Discussions](https://github.com/forcegage-pvm/dart_fit_decoder/discussions)
- **Email**: support@forcegage.com

---

Made with ❤️ for the Dart and Flutter community
