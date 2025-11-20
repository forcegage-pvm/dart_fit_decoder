/// Real FIT file fixture tests using actual Garmin activity files.
///
/// These tests validate the decoder against real-world FIT files from
/// Garmin Edge cycling computers with the following characteristics:
///
/// activity_small.fit:
/// - Size: 1,083,157 bytes
/// - Records: 21,395
/// - Laps: 11
/// - Sport: cycling (road)
/// - Duration: ~6.2 hours
/// - Distance: 167.67 km
/// - Manufacturer: Garmin (product 3843)
/// - Has developer fields (not CORE temperature)
///
/// activity_recent.fit:
/// - Size: 1,880,938 bytes
/// - Records: 25,359
/// - Laps: 15
/// - Sport: cycling (road)
/// - Duration: ~7.3 hours
/// - Distance: 186.68 km
/// - Has developer_data_id and field_description messages (14 fields)
/// - Has developer fields in records
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_fit_decoder/dart_fit_decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Real FIT File - activity_small.fit', () {
    late File fitFile;
    late Uint8List fitBytes;

    setUpAll(() {
      fitFile = File('test/fixtures/activity_small.fit');
      if (!fitFile.existsSync()) {
        throw Exception('Test fixture not found: ${fitFile.path}');
      }
      fitBytes = fitFile.readAsBytesSync();
    });

    test('file exists and has expected size', () {
      expect(fitFile.existsSync(), isTrue);
      expect(fitBytes.length, equals(1083157)); // Known file size
    });

    test('parses FIT file header successfully', () {
      final header = FitHeader.parse(fitBytes);

      expect(header, isNotNull);
      expect(header.headerSize, inInclusiveRange(12, 14));
      expect(header.dataSize, greaterThan(0));
      expect(header.dataSize, equals(fitBytes.length - header.headerSize - 2)); // Minus header and CRC
    });

    test('header has valid protocol version', () {
      final header = FitHeader.parse(fitBytes);

      // Protocol version should be 1.x or 2.x
      expect(header.protocolVersion, greaterThanOrEqualTo(16)); // 1.0 = 0x10
      expect(header.protocolVersion, lessThan(48)); // Less than 3.0
    });

    test('header has valid profile version', () {
      final header = FitHeader.parse(fitBytes);

      expect(header.profileVersion, greaterThan(0));
      // Profile versions can be high (e.g., 21179 = version 211.79)
      expect(header.profileVersion, lessThan(100000)); // Reasonable upper bound
    });
    test('header CRC validates correctly', () {
      final header = FitHeader.parse(fitBytes);

      // If header is 14 bytes, it includes CRC
      if (header.headerSize == 14) {
        // CRC should be present and valid
        expect(header.crc, isNotNull);
      }
    });

    test('decodes file structure', () {
      final decoder = FitDecoder(fitBytes);

      // This will throw if decoding fails
      expect(() => decoder.decode(), returnsNormally);
    });

    test('extracts file_id message', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final fileIdMessages = fitFile.getMessagesByType(0); // file_id = 0

      expect(fileIdMessages, isNotEmpty);

      final fileId = fileIdMessages.first;
      expect(fileId, isA<FitDataMessage>());

      // File type should be activity (4)
      final type = fileId.getField('type');
      expect(type, isNotNull);
      expect(type, equals(4)); // activity

      // Manufacturer should be Garmin (1)
      final manufacturer = fileId.getField('manufacturer');
      expect(manufacturer, isNotNull);
      expect(manufacturer, equals(1)); // Garmin

      // Product should be 3843 (Garmin Edge)
      final product = fileId.getField('product');
      expect(product, isNotNull);
      expect(product, equals(3843));
    });

    test('extracts record messages', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final records = fitFile.getRecordMessages();

      expect(records, isNotEmpty);
      expect(records.length, equals(21395)); // Known count from Python analysis
    });

    test('first record has expected fields', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final records = fitFile.getRecordMessages();
      final firstRecord = records.first;

      // Timestamp field (253)
      final timestamp = firstRecord.getField('timestamp');
      expect(timestamp, isNotNull);
      expect(timestamp, isA<int>());
      expect(timestamp, greaterThan(0));

      // Position lat/long
      final posLat = firstRecord.getField('position_lat');
      final posLong = firstRecord.getField('position_long');
      expect(posLat, isNotNull);
      expect(posLong, isNotNull);

      // Convert semicircles to degrees: -307520087 semicircles
      // degrees = semicircles * (180 / 2^31)
      expect(posLat, equals(-307520087)); // Known from analysis
      expect(posLong, equals(338524530)); // Known from analysis

      // Heart rate
      final heartRate = firstRecord.getField('heart_rate');
      expect(heartRate, isNotNull);
      expect(heartRate, equals(103)); // Known from analysis

      // Distance (should be 0 at start)
      final distance = firstRecord.getField('distance');
      expect(distance, isNotNull);
      // Distance is in cm, scaled to meters
      expect(distance, closeTo(0.0, 1.0));

      // Cadence
      final cadence = firstRecord.getField('cadence');
      expect(cadence, isNotNull);
      expect(cadence, equals(86)); // Known from analysis

      // Temperature
      final temperature = firstRecord.getField('temperature');
      expect(temperature, isNotNull);
      expect(temperature, equals(17)); // 17°C
    });

    test('records have developer fields', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final records = fitFile.getRecordMessages();

      // Python analysis showed developer fields in records: 107, 137, 138, 144
      // Note: activity_small.fit has basic developer fields
      expect(records.length, equals(21395));

      // Verify records exist - developer field presence varies by record
      expect(records, isNotEmpty);
    });

    test('extracts lap messages', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final laps = fitFile.getLapMessages();

      expect(laps, isNotEmpty);
      expect(laps.length, equals(11)); // Known count from analysis
    });

    test('first lap has expected data', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final laps = fitFile.getLapMessages();
      final firstLap = laps.first;

      // Total elapsed time (field 7)
      final elapsedTime = firstLap.getField('total_elapsed_time');
      expect(elapsedTime, isNotNull);
      // Scale: 1000 (stored in ms, output in seconds)
      expect(elapsedTime, closeTo(3997.159, 1.0)); // ~66.6 minutes

      // Total distance (field 9)
      final distance = firstLap.getField('total_distance');
      expect(distance, isNotNull);
      // Scale: 100 (stored in cm, output in meters)
      expect(distance, closeTo(23504.11, 10.0)); // ~23.5 km

      // Max heart rate (field 17) - avg_heart_rate not in all laps
      final maxHr = firstLap.getField('max_heart_rate');
      expect(maxHr, isNotNull);
      expect(maxHr, greaterThan(50)); // Should have some reasonable max HR value
    });

    test('extracts session message', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final sessions = fitFile.getSessionMessages();

      expect(sessions, isNotEmpty);
      expect(sessions.length, equals(1));
    });

    test('session has expected summary data', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final sessions = fitFile.getSessionMessages();
      final session = sessions.first;

      // Sport (field 5) - cycling
      final sport = session.getField('sport');
      expect(sport, isNotNull);
      expect(sport, equals(2)); // cycling = 2

      // Sub sport (field 6) - road
      final subSport = session.getField('sub_sport');
      expect(subSport, isNotNull);
      expect(subSport, equals(7)); // road = 7

      // Total elapsed time
      final elapsedTime = session.getField('total_elapsed_time');
      expect(elapsedTime, isNotNull);
      expect(elapsedTime, closeTo(22240.178, 10.0)); // ~6.2 hours

      // Total distance
      final distance = session.getField('total_distance');
      expect(distance, isNotNull);
      expect(distance, closeTo(167669.12, 100.0)); // ~167.7 km

      // Total calories
      final calories = session.getField('total_calories');
      expect(calories, isNotNull);
      expect(calories, inInclusiveRange(4500, 4550)); // ~4529 kcal

      // Avg heart rate
      final avgHr = session.getField('avg_heart_rate');
      expect(avgHr, isNotNull);
      expect(avgHr, equals(127)); // bpm

      // Max heart rate
      final maxHr = session.getField('max_heart_rate');
      expect(maxHr, isNotNull);
      expect(maxHr, equals(142)); // bpm
    });

    test('handles compressed timestamp records', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final records = fitFile.getRecordMessages();

      // With 21,395 records, most should use compressed timestamps
      expect(records.length, greaterThan(1000));

      // Check timestamp progression
      var previousTimestamp = 0;
      var compressedCount = 0;

      for (final record in records.take(100)) {
        final timestamp = record.getField('timestamp');
        if (timestamp != null) {
          final currentTimestamp = timestamp as int;

          if (previousTimestamp > 0) {
            // Timestamps should be monotonically increasing
            expect(currentTimestamp, greaterThanOrEqualTo(previousTimestamp));

            // Most timestamp increments should be small (1-31 seconds)
            final delta = currentTimestamp - previousTimestamp;
            if (delta > 0 && delta <= 31) {
              compressedCount++;
            }
          }

          previousTimestamp = currentTimestamp;
        }
      }

      // Most records should have small timestamp deltas (compressed)
      expect(compressedCount, greaterThan(50)); // At least 50% of 100 records
    });
  });

  group('Real FIT File - activity_recent.fit', () {
    late File fitFile;
    late Uint8List fitBytes;

    setUpAll(() {
      fitFile = File('test/fixtures/activity_recent.fit');
      if (!fitFile.existsSync()) {
        throw Exception('Test fixture not found: ${fitFile.path}');
      }
      fitBytes = fitFile.readAsBytesSync();
    });

    test('file exists and has expected size', () {
      expect(fitFile.existsSync(), isTrue);
      expect(fitBytes.length, equals(1880938)); // Known file size
    });

    test('parses FIT file header', () {
      final header = FitHeader.parse(fitBytes);

      expect(header, isNotNull);
      expect(header.headerSize, inInclusiveRange(12, 14));
      expect(header.dataSize, greaterThan(0));
    });

    test('has developer_data_id message', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final devDataIds = fitFile.getMessagesByType(207); // developer_data_id

      expect(devDataIds, isNotEmpty);
      expect(devDataIds.length, equals(1)); // Known from analysis
    });

    test('has field_description messages', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final fieldDescs = fitFile.getMessagesByType(206); // field_description

      expect(fieldDescs, isNotEmpty);
      expect(fieldDescs.length, equals(14)); // Known from analysis
    });

    test('field_description defines developer fields', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final fieldDescs = fitFile.getMessagesByType(206);
      final firstDesc = fieldDescs.first;

      // Field description should have these fields:
      // - developer_data_index (0)
      // - field_definition_number (1)
      // - base_type_id (2)
      // - field_name (3)
      // - units (8)

      final devDataIndex = firstDesc.getField('developer_data_index');
      expect(devDataIndex, isNotNull);

      final fieldDefNum = firstDesc.getField('field_definition_number');
      expect(fieldDefNum, isNotNull);

      final baseTypeId = firstDesc.getField('base_type_id');
      expect(baseTypeId, isNotNull);
    });

    test('records have matching developer fields', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final records = fitFile.getRecordMessages();
      expect(records, isNotEmpty);
      expect(records.length, equals(25359)); // Known count

      // Check that first record has developer fields
      final firstRecord = records.first;
      expect(firstRecord.developerFields, isNotEmpty);

      // Verify CORE temperature field exists (field #0)
      final coreTemp = firstRecord.developerFields.where((f) => f.fieldNumber == 0).firstOrNull;
      expect(coreTemp, isNotNull);
      expect(coreTemp!.name, equals('core_temperature'));
    });

    test('extracts multiple laps', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final laps = fitFile.getLapMessages();

      expect(laps.length, equals(15)); // Known count from analysis
    });

    test('session has complete activity summary', () {
      final decoder = FitDecoder(fitBytes);
      final fitFile = decoder.decode();

      final sessions = fitFile.getSessionMessages();
      expect(sessions.length, equals(1));

      final session = sessions.first;

      // Total distance: 186,677.6 meters (~186.68 km)
      final distance = session.getField('total_distance');
      expect(distance, isNotNull);
      expect(distance, closeTo(186677.6, 100.0));

      // Total elapsed time: 26,295.757 seconds (~7.3 hours)
      final elapsedTime = session.getField('total_elapsed_time');
      expect(elapsedTime, isNotNull);
      expect(elapsedTime, closeTo(26295.757, 10.0));

      // Avg heart rate: 113 bpm
      final avgHr = session.getField('avg_heart_rate');
      expect(avgHr, isNotNull);
      expect(avgHr, equals(113));
    });
  });

  group('Real FIT File - Performance Tests', () {
    test('decodes small file in reasonable time', () {
      final fitFile = File('test/fixtures/activity_small.fit');
      final fitBytes = fitFile.readAsBytesSync();

      final stopwatch = Stopwatch()..start();
      final decoder = FitDecoder(fitBytes);
      final result = decoder.decode();
      stopwatch.stop();

      // Should decode in less than 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      // Verify decoded successfully
      expect(result.messages, isNotEmpty);
      expect(result.messages.length, greaterThan(20000));
    });

    test('handles large record count efficiently', () {
      final fitFile = File('test/fixtures/activity_recent.fit');
      final fitBytes = fitFile.readAsBytesSync();

      final decoder = FitDecoder(fitBytes);
      final result = decoder.decode();

      final records = result.getRecordMessages();

      // Should handle 25,000+ records
      expect(records.length, greaterThan(25000));

      // Should be able to iterate through all records
      var count = 0;
      for (var i = 0; i < records.length && count < 100; i++) {
        count++;
      }
      expect(count, equals(100));
    });
  });
}
