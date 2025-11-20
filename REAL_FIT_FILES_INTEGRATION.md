# Real FIT File Integration Testing

## Overview

This document describes the integration testing setup using real Garmin FIT files to validate the dart_fit_decoder implementation.

## Test Files

### Source Location
Real FIT files are located in: `python/.fit/`

Six Garmin activity files from various dates:
- `2020-12-03/joubertjp.2020-12-05...fit` (7.6 MB)
- `2024-08-31/tp-2023646.2024-09-01...FIT` (3.5 MB)
- `2025-09-06/tp-2023646.2025-09-07...FIT` (3.9 MB)
- `2025-09-13/tp-2023646.2025-09-14...FIT` (3.8 MB)
- `2025-09-24/tp-2023646.2025-09-24...FIT` (1.08 MB) ← **Selected as activity_small.fit**
- `2025-10-26/tp-2023646.2025-10-26...FIT` (1.88 MB) ← **Selected as activity_recent.fit**

### Test Fixtures

Two files have been copied to `test/fixtures/` for testing:

#### activity_small.fit
- **Source**: `python/.fit/2025-09-24/tp-2023646.2025-09-24-10-21-54-019Z.GarminPing.AAAAAGjTxkGYx34y.FIT`
- **Size**: 1,083,157 bytes
- **Why chosen**: Smallest file for faster test execution
- **Activity Details**:
  - Type: Cycling (road)
  - Date: 2025-09-24 04:08:51
  - Duration: 22,240 seconds (~6.2 hours)
  - Distance: 167,669 meters (~167.67 km)
  - Laps: 11
  - Records: 21,395
  - Heart Rate: avg=127 bpm, max=142 bpm
  - Calories: 4,529 kcal
  - Device: Garmin product 3843, serial 3438526423
  - Developer Fields: 107, 137, 138, 144 (not CORE temperature)

#### activity_recent.fit
- **Source**: `python/.fit/2025-10-26/tp-2023646.2025-10-26-13-23-16-784Z.GarminPing.AAAAAGj-IMQ_uYSx.FIT`
- **Size**: 1,880,938 bytes
- **Why chosen**: Most recent file with developer field infrastructure
- **Activity Details**:
  - Type: Cycling (road)
  - Date: 2025-10-26 05:32:46
  - Duration: 26,295 seconds (~7.3 hours)
  - Distance: 186,677 meters (~186.68 km)
  - Laps: 15
  - Records: 25,359
  - Heart Rate: avg=113 bpm, max=126 bpm
  - Calories: 4,832 kcal
  - Device: Garmin product 3843
  - **Special Feature**: Contains developer_data_id_mesgs (1) and field_description_mesgs (14)
  - Developer Fields: 107, 137, 138, 144

## Python Analysis Tool

### analyze_test_fit.py

Created to analyze FIT file structure using the official `garmin_fit_sdk` library.

**Features**:
- Reads FIT files and decodes all messages
- Counts message types and identifies all present types
- Extracts file_id metadata (manufacturer, product, serial, type)
- Analyzes first and last record messages
- Summarizes lap messages
- Extracts session summary data
- Detects developer fields (including CORE temperature fields 7-13)
- Outputs detailed console report and JSON summary

**Usage**:
```bash
# Activate Python environment
python\.venv\Scripts\Activate.ps1

# Analyze a FIT file
python python/analyze_test_fit.py "path/to/file.fit"

# Analyze both test fixtures
python python/analyze_test_fit.py test/fixtures/activity_small.fit
python python/analyze_test_fit.py test/fixtures/activity_recent.fit
```

**Analysis Results** (activity_small.fit):
```
Message Types (30 total):
- file_id_mesgs: 1
- record_mesgs: 21,395
- lap_mesgs: 11
- session_mesgs: 1
- developer_data_id_mesgs: 0
- field_description_mesgs: 0

First Record:
- timestamp: 2025-09-24 04:08:51
- position_lat: -307520087 semicircles
- position_long: 338524530 semicircles
- heart_rate: 103 bpm
- cadence: 86 rpm
- temperature: 17°C
- distance: 0 meters

Developer Fields Found: 107, 137, 138, 144
CORE Temperature Fields (7-13): NOT FOUND
```

**Analysis Results** (activity_recent.fit):
```
Message Types (32 total):
- file_id_mesgs: 1
- record_mesgs: 25,359
- lap_mesgs: 15
- session_mesgs: 1
- developer_data_id_mesgs: 1 ← Important!
- field_description_mesgs: 14 ← Important!

First Record:
- timestamp: 2025-10-26 05:32:46
- position_lat: -306972398 semicircles
- position_long: 338699639 semicircles
- heart_rate: 85 bpm
- cadence: 75 rpm
- temperature: 20°C
- distance: 3.73 meters

Developer Fields Found: 107, 137, 138, 144
CORE Temperature Fields (7-13): NOT FOUND
```

## Dart Integration Tests

### real_fit_file_test.dart

Comprehensive integration tests that validate the decoder against real Garmin FIT files.

**Test Structure**:

#### Group 1: activity_small.fit Tests (10 tests)
1. File exists and has expected size (1,083,157 bytes)
2. Parses FIT file header successfully
3. Header has valid protocol version (≥1.0, <3.0)
4. Header has valid profile version
5. Extracts file_id message (manufacturer=Garmin, product=3843, type=activity)
6. Extracts record messages (21,395 records)
7. First record has expected fields (timestamp, position, heart rate, cadence, temperature)
8. Records have developer fields (107, 137, 138, 144)
9. Extracts lap messages (11 laps)
10. First lap has expected data (time, distance, heart rate)
11. Extracts session message (1 session)
12. Session has expected summary data (sport, duration, distance, calories, heart rate)
13. Handles compressed timestamp records

#### Group 2: activity_recent.fit Tests (7 tests)
1. File exists and has expected size (1,880,938 bytes)
2. Parses FIT file header
3. Has developer_data_id message (1 message)
4. Has field_description messages (14 messages)
5. Field_description defines developer fields
6. Records have matching developer fields
7. Extracts multiple laps (15 laps)
8. Session has complete activity summary

#### Group 3: Performance Tests (2 tests)
1. Decodes small file in reasonable time (<5 seconds)
2. Handles large record count efficiently (25,000+ records)

**Current Test Status** (as of TDD phase):
- ✅ 9 tests passing (header parsing, file validation)
- ❌ 18 tests failing (decoder implementation not complete)

Expected failures:
- Message extraction (getMessagesByType returns empty)
- Record extraction (no records parsed yet)
- Field value validation (no data messages yet)
- Developer field parsing (infrastructure not implemented)

## Expected Test Values

All test expectations are derived from Python analysis results:

### activity_small.fit Expected Values

**File ID**:
- type: 4 (activity)
- manufacturer: 1 (Garmin)
- product: 3843
- serial_number: 3438526423

**First Record** (record 1 of 21,395):
- timestamp: FIT timestamp for 2025-09-24 04:08:51
- position_lat: -307520087 semicircles
- position_long: 338524530 semicircles
- heart_rate: 103 bpm
- cadence: 86 rpm
- temperature: 17°C
- distance: ~0 meters

**Developer Fields** (in first record):
- Field 107: 0
- Field 137: 100
- Field 138: 100
- Field 144: 103

**First Lap** (lap 1 of 11):
- total_elapsed_time: 3997.159 seconds
- total_distance: 23504.11 meters
- avg_heart_rate: 121 bpm
- max_heart_rate: 139 bpm

**Session**:
- sport: 2 (cycling)
- sub_sport: 1 (road)
- total_elapsed_time: 22240.178 seconds
- total_distance: 167669.12 meters
- total_calories: 4529 kcal
- avg_heart_rate: 127 bpm
- max_heart_rate: 142 bpm

### activity_recent.fit Expected Values

**Message Counts**:
- record_mesgs: 25,359
- lap_mesgs: 15
- session_mesgs: 1
- developer_data_id_mesgs: 1
- field_description_mesgs: 14

**Developer Field Infrastructure**:
- 1 developer_data_id message (defines developer data source)
- 14 field_description messages (define 14 developer fields)

**Session**:
- total_distance: 186677.6 meters
- total_elapsed_time: 26295.757 seconds
- avg_heart_rate: 113 bpm

## Key Insights

### Developer Fields
Both files contain developer fields (107, 137, 138, 144), but:
- **NOT CORE temperature fields** (CORE uses fields 7-13)
- These are likely custom Garmin fields for other metrics
- `activity_recent.fit` has the full developer field infrastructure:
  - `developer_data_id` message (identifies the data source)
  - `field_description` messages (14 definitions for developer fields)

### File Structure
Both files follow standard FIT format:
1. **Header** (14 bytes with CRC)
2. **Message sequence**:
   - file_id (metadata)
   - [Optional] developer_data_id
   - [Optional] field_description messages
   - record messages (GPS, HR, power, cadence, etc.)
   - lap messages (lap summaries)
   - session message (activity summary)
   - [Other message types]
3. **File CRC** (2 bytes)

### Test Strategy
1. **TDD Approach**: Tests written first based on Python analysis
2. **Real Data Validation**: Use actual expected values from Garmin files
3. **Incremental Implementation**: Implement decoder to pass tests progressively
4. **Developer Field Focus**: `activity_recent.fit` validates full developer field workflow

## Next Steps

### Implementation Priorities

1. **Core Binary Parser** (required for all tests):
   - Binary reader with endianness support
   - Record header parsing (normal + compressed)
   - Definition message parsing
   - Data message parsing with field extraction

2. **Message Type Detection**:
   - Implement `getMessagesByType()`
   - Implement `getRecordMessages()`, `getLapMessages()`, `getSessionMessages()`
   - Message type constants and names

3. **Field Value Extraction**:
   - Field scaling and offset application
   - Field name resolution from FIT profile
   - Type-safe field value extraction

4. **Developer Field Support**:
   - Parse developer_data_id messages
   - Parse field_description messages
   - Match developer fields in data messages
   - Associate developer field definitions with values

5. **Validation**:
   - CRC validation for header and file
   - Timestamp calculations
   - Compressed timestamp header support

### CORE Temperature Search

Neither test fixture contains CORE temperature data (fields 7-13). Need to:
1. Search through remaining FIT files in `python/.fit/`
2. Use `analyze_test_fit.py` to check for CORE fields
3. Copy any files with CORE data to test fixtures
4. Create CORE-specific tests

**Search command**:
```bash
# Check all FIT files for CORE temperature fields
Get-ChildItem -Path "python\.fit" -Recurse -Filter "*.FIT" | ForEach-Object {
    Write-Host "Analyzing: $($_.FullName)"
    python python/analyze_test_fit.py "$($_.FullName)" | Select-String "CORE"
}
```

## Test Execution

### Run All Tests
```bash
cd packages/dart_fit_decoder
dart test
```

### Run Only Real FIT File Tests
```bash
dart test test/real_fit_file_test.dart
```

### Run Specific Test Group
```bash
dart test test/real_fit_file_test.dart --name "activity_small"
dart test test/real_fit_file_test.dart --name "activity_recent"
dart test test/real_fit_file_test.dart --name "Performance"
```

### Watch Mode (Re-run on Changes)
```bash
dart test --watch test/real_fit_file_test.dart
```

## Success Criteria

The real FIT file integration tests will pass when:

✅ All 27 tests in `real_fit_file_test.dart` pass
✅ Decoder correctly parses real Garmin FIT files
✅ Message counts match Python analysis exactly
✅ Field values match expected values from Python analysis
✅ Developer field infrastructure is parsed correctly
✅ Compressed timestamps are handled properly
✅ Performance is acceptable (<5 seconds for 1 MB files)

Current Progress:
- ✅ Test fixtures prepared (2 real files)
- ✅ Python analysis tool created
- ✅ Expected values documented
- ✅ Integration tests written (27 tests)
- ⏳ Decoder implementation (in progress)
- ❌ CORE temperature files (not yet found)

## File Manifest

**Test Files**:
- `test/fixtures/activity_small.fit` - 1.08 MB Garmin cycling activity
- `test/fixtures/activity_recent.fit` - 1.88 MB Garmin cycling activity with developer fields

**Test Code**:
- `test/real_fit_file_test.dart` - 27 integration tests validating real FIT file parsing

**Analysis Tools**:
- `python/analyze_test_fit.py` - Python script using garmin_fit_sdk to analyze FIT files

**Documentation**:
- `REAL_FIT_FILES_INTEGRATION.md` - This file
- `TEST_SUITE_SUMMARY.md` - Original TDD test suite documentation

## References

- [FIT SDK Documentation](https://developer.garmin.com/fit/overview/)
- [Garmin FIT Python SDK](https://pypi.org/project/garmin-fit-sdk/)
- Original test files: `python/.fit/` directory
