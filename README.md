# dart_fit_decoder

[![pub package](https://img.shields.io/pub/v/dart_fit_decoder.svg)](https://pub.dev/packages/dart_fit_decoder)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Robust, pure-Dart decoding for Garmin FIT (Flexible and Interoperable Data Transfer) files with full developer-field support, including CORE body temperature data.

## Highlights

- FIT header validation and CRC handling
- Definition and data message decoding
- Developer field parsing with name/unit resolution
- Compressed timestamp support
- Works on Dart and Flutter (Web, Mobile, Desktop)

## Installation

Add to pubspec.yaml:

```yaml
dependencies:
  dart_fit_decoder: ^0.1.0
```

Get packages:

```bash
dart pub get
```

Flutter:

```bash
flutter pub get
```

## Quick start

```dart
import 'dart:io';
import 'package:dart_fit_decoder/dart_fit_decoder.dart';

void main() async {
  final bytes = await File('activity.fit').readAsBytes();
  final decoder = FitDecoder(bytes);
  final fitFile = decoder.decode();

  print('Protocol: ${fitFile.header.protocolVersion}');
  print('Messages: ${fitFile.messages.length}');
}
```

## Usage examples

### 1) Parse basic messages

```dart
final records = fitFile.getRecordMessages();
final laps = fitFile.getLapMessages();
final sessions = fitFile.getSessionMessages();

print('Records: ${records.length}');
print('Laps: ${laps.length}');
print('Sessions: ${sessions.length}');
```

### 2) Read developer fields (CORE temperature)

```dart
for (final record in fitFile.getRecordMessages()) {
  for (final devField in record.developerFields) {
    if (devField.name == 'core_temperature') {
      print('Core: ${devField.value}${devField.units}');
    }
    if (devField.name == 'skin_temperature') {
      print('Skin: ${devField.value}${devField.units}');
    }
    if (devField.name == 'heat_strain_index') {
      print('HSI: ${devField.value}');
    }
  }
}
```

### 3) Lap summaries

```dart
void printLapSummaries(FitFile fitFile) {
  final laps = fitFile.getLapMessages();
  for (var i = 0; i < laps.length; i++) {
    final lap = laps[i];
    final distanceKm = lap.getField('total_distance') / 1000;
    final timeMin = lap.getField('total_elapsed_time') / 60;
    final avgPower = lap.getField('avg_power');
    final avgHeartRate = lap.getField('avg_heart_rate');

    print('Lap ${i + 1}: ${distanceKm.toStringAsFixed(2)} km, '
        '${timeMin.toStringAsFixed(1)} min, '
        'Avg Power: $avgPower W, Avg HR: $avgHeartRate bpm');
  }
}
```

## API highlights

- `FitDecoder` parses bytes into a `FitFile`.
- `FitFile` exposes helpers like `getRecordMessages()`, `getLapMessages()`, and `getSessionMessages()`.
- `FitDataMessage` provides `fields`, `developerFields`, and `getField()` accessors.
- `DeveloperField` exposes `name`, `value`, `units`, and `fieldNumber`.

## FIT support

### Common message types

| Message Type        | Global #   | Description                                 |
| ------------------- | ---------- | ------------------------------------------- |
| `file_id`           | 0          | File identification                         |
| `device_info`       | 23         | Device information                          |
| `record`            | 20         | Primary data records (GPS, HR, power, etc.) |
| `lap`               | 19         | Lap summaries                               |
| `session`           | 18         | Session summaries                           |
| `event`             | 21         | Workout events                              |
| `field_description` | 206 (0xCE) | Developer field descriptions                |
| `developer_data_id` | 207 (0xCF) | Developer data identifiers                  |

### Base types

- `enum` (0x00), `sint8` (0x01), `uint8` (0x02)
- `sint16` (0x83), `uint16` (0x84)
- `sint32` (0x85), `uint32` (0x86)
- `float32` (0x88), `float64` (0x89)
- `string` (0x07), `byte` (0x0D)
- `uint8z` (0x0A), `uint16z` (0x8B), `uint32z` (0x8C)

## Performance

- Decodes typical 1–2 MB FIT files in under a second
- Handles large activity files with 25k+ records efficiently

## Testing

```bash
dart test
```

Coverage:

```bash
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Examples

See [example/dart_fit_decoder_example.dart](example/dart_fit_decoder_example.dart) for a complete working example.

## Contributing

See [contributing.md](contributing.md).

## Changelog

See [changelog.md](changelog.md).

## License

MIT. See [LICENSE](LICENSE).

## References

- [FIT SDK Documentation](https://developer.garmin.com/fit/overview/)
- [FIT File Types](https://developer.garmin.com/fit/file-types/)
- [FIT Protocol](https://developer.garmin.com/fit/protocol/)
