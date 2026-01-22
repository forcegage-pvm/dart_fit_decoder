/// Main FIT file decoder.
///
/// This decoder implements the Garmin FIT (Flexible and Interoperable Data Transfer)
/// protocol for parsing binary FIT files. It supports:
/// - All FIT base types (uint8, sint16, float32, etc.)
/// - Standard message types (record, lap, session, etc.)
/// - Developer fields (including CORE body temperature sensor data)
/// - Compressed timestamps
/// - CRC validation
///
/// Example usage:
/// ```dart
/// final decoder = FitDecoder(fitBytes);
/// final fitFile = decoder.decode();
/// final records = fitFile.getRecordMessages();
/// ```
library;

import 'dart:typed_data';

import 'developer_field.dart';
import 'exceptions.dart';
import 'fit_base_type.dart';
import 'fit_data_message.dart';
import 'fit_definition_message.dart';
import 'fit_field.dart';
import 'fit_file.dart';
import 'fit_header.dart';
import 'fit_message.dart';

/// Decoder for parsing FIT files.
///
/// The FitDecoder processes binary FIT files and extracts:
/// - File header (protocol version, profile version, data size)
/// - Definition messages (field definitions for each message type)
/// - Data messages (actual field values)
/// - Developer fields (custom fields including CORE temperature data)
///
/// The decoder maintains state during parsing including:
/// - Current position in the byte stream
/// - Cached definition messages for each local message number
/// - Last timestamp for compressed timestamp calculation
/// - Developer field definitions from field_description messages
class FitDecoder {
  /// Raw FIT file bytes.
  final Uint8List bytes;

  /// Current position in the byte stream.
  int _position = 0;

  /// Parsed header.
  FitHeader? _header;

  /// All parsed messages (definition and data messages).
  final List<FitMessage> _messages = [];

  /// Definition messages cache (local message number -> definition).
  ///
  /// FIT files use local message numbers (0-15) that map to global message types.
  /// Definition messages establish this mapping and must be cached for parsing
  /// subsequent data messages.
  final Map<int, FitDefinitionMessage> _definitions = {};

  /// Last valid timestamp for compressed timestamp headers.
  ///
  /// Compressed timestamp headers contain a 5-bit time offset (0-31 seconds)
  /// from the last full timestamp. This field tracks that base timestamp.
  int _lastTimestamp = 0;

  /// Developer field definitions (developer_data_index -> field_definition_number -> field info).
  ///
  /// Developer fields (like CORE temperature) require two-stage parsing:
  /// 1. Parse field_description messages (type 206) to get field names and types
  /// 2. Use these definitions to parse developer field values in data messages
  ///
  /// Structure: Map<developer_data_index, Map<field_number, field_info>>
  final Map<String, Map<int, _DeveloperFieldInfo>> _developerFieldDefinitions = {};

  /// Create a FIT decoder for the given bytes.
  ///
  /// The bytes can be from a file, network, or any other source.
  FitDecoder(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  /// Decode the FIT file and return a FitFile object.
  ///
  /// This is the main entry point for parsing. It:
  /// 1. Parses the 14-byte header
  /// 2. Iterates through all messages in the data section
  /// 3. Validates the file CRC
  /// 4. Returns a FitFile with all parsed data
  ///
  /// Throws [InvalidHeaderException] if the header is malformed.
  /// Throws [MissingDefinitionException] if a data message references an undefined local message.
  FitFile decode() {
    // Parse header
    _header = _parseHeader();

    // Parse all messages until we reach the end of data
    final dataEnd = _header!.headerSize + _header!.dataSize;
    while (_position < dataEnd && _hasMoreBytes) {
      try {
        _parseMessage();
      } catch (e) {
        // If we can't parse a message, stop to avoid corrupting the rest
        break;
      }
    }

    // Read file CRC (last 2 bytes)
    int? fileCrc;
    if (_remainingBytes >= 2) {
      fileCrc = _readUint16();
    }

    return FitFile(
      header: _header!,
      messages: _messages,
      fileCrc: fileCrc,
    );
  }

  /// Parse the FIT file header (14 bytes).
  ///
  /// The header contains:
  /// - Byte 0: Header size (12 or 14)
  /// - Byte 1: Protocol version
  /// - Bytes 2-3: Profile version
  /// - Bytes 4-7: Data size
  /// - Bytes 8-11: '.FIT' signature
  /// - Bytes 12-13: Optional CRC
  ///
  /// After parsing, advances position to start of data section.
  FitHeader _parseHeader() {
    if (bytes.length < 14) {
      throw InvalidHeaderException('File too small: ${bytes.length} bytes (minimum 14 required)');
    }

    final header = FitHeader.parse(bytes.sublist(0, 14));
    _position = header.headerSize;

    return header;
  }

  /// Parse a single message (definition or data).
  ///
  /// FIT messages have two formats:
  /// 1. Normal header (bit 7 = 0): Can be definition or data message
  /// 2. Compressed timestamp header (bit 7 = 1): Always data message with time offset
  void _parseMessage() {
    // Read record header byte
    final headerByte = _readByte();

    // Check for compressed timestamp header (bit 7 = 1)
    final isCompressedTimestamp = (headerByte & 0x80) != 0;

    if (isCompressedTimestamp) {
      _parseCompressedTimestampMessage(headerByte);
    } else {
      _parseNormalMessage(headerByte);
    }
  }

  /// Parse a normal (non-compressed timestamp) message.
  ///
  /// Normal header byte structure:
  /// - Bit 7: 0 (normal header indicator)
  /// - Bit 6: Message type (1 = definition, 0 = data)
  /// - Bit 5: Developer data flag (1 = has developer fields)
  /// - Bit 4: Reserved (must be 0)
  /// - Bits 0-3: Local message number (0-15)
  void _parseNormalMessage(int headerByte) {
    // Bit 6: 1 = definition message, 0 = data message
    final isDefinition = (headerByte & 0x40) != 0;

    // Bit 5: Developer data flag
    final hasDeveloperData = (headerByte & 0x20) != 0;

    // Bits 0-3: Local message type (0-15)
    final localMessageType = headerByte & 0x0F;

    if (isDefinition) {
      _parseDefinitionMessage(localMessageType, hasDeveloperData);
    } else {
      _parseDataMessage(localMessageType);
    }
  }

  /// Parse a compressed timestamp message.
  void _parseCompressedTimestampMessage(int headerByte) {
    // Bits 5-6: Local message type (0-3)
    final localMessageType = (headerByte >> 5) & 0x03;

    // Bits 0-4: Time offset (0-31 seconds)
    final timeOffset = headerByte & 0x1F;

    // Update timestamp with rollover handling (offset is modulo 32)
    final lastOffset = _lastTimestamp & 0x1F;
    var delta = timeOffset - lastOffset;
    if (delta < 0) {
      delta += 32;
    }
    _lastTimestamp += delta;

    // Parse data message
    _parseDataMessage(localMessageType);
  }

  /// Parse a definition message.
  void _parseDefinitionMessage(int localMessageType, bool hasDeveloperData) {
    // Reserved byte
    _readByte();

    // Architecture: 0 = little endian, 1 = big endian
    final architecture = _readByte();
    final endian = architecture == 0 ? Endian.little : Endian.big;

    // Global message number (2 bytes)
    final globalMessageNumber = _readUint16(endian);

    // Number of fields
    final numFields = _readByte();

    // Field definitions
    final fields = <FieldDefinition>[];
    for (var i = 0; i < numFields; i++) {
      final fieldDefNum = _readByte();
      final size = _readByte();
      final baseTypeId = _readByte();

      fields.add(FieldDefinition(
        fieldNumber: fieldDefNum,
        size: size,
        baseTypeId: baseTypeId,
      ));
    }

    // Developer field definitions (if present)
    final developerFields = <DeveloperFieldDefinition>[];
    if (hasDeveloperData) {
      final numDevFields = _readByte();
      for (var i = 0; i < numDevFields; i++) {
        final fieldDefNum = _readByte();
        final size = _readByte();
        final devDataIndex = _readByte();

        developerFields.add(DeveloperFieldDefinition(
          fieldNumber: fieldDefNum,
          size: size,
          developerDataIndex: devDataIndex,
        ));
      }
    }

    // Create and cache definition message
    final definition = FitDefinitionMessage(
      localMessageNumber: localMessageType,
      globalMessageNumber: globalMessageNumber,
      architecture: architecture,
      fieldDefinitions: fields,
      developerFieldDefinitions: developerFields,
    );

    _definitions[localMessageType] = definition;
    _messages.add(definition);
  }

  /// Parse a data message.
  void _parseDataMessage(int localMessageType) {
    // Get definition for this local message type
    final definition = _definitions[localMessageType];
    if (definition == null) {
      throw MissingDefinitionException(localMessageType);
    }

    final endian = definition.architecture == 0 ? Endian.little : Endian.big;

    // Parse standard fields
    final fields = <FitField>[];
    for (final fieldDef in definition.fieldDefinitions) {
      final baseType = fieldDef.baseType ?? FitBaseTypes.byte;
      final value = _readFieldValue(fieldDef.size, baseType, endian);

      // Create field with name lookup (would need FIT profile for complete names)
      fields.add(FitField(
        fieldNumber: fieldDef.fieldNumber,
        name: _getFieldName(definition.globalMessageNumber, fieldDef.fieldNumber),
        baseType: baseType,
        value: value,
        scale: _getFieldScale(definition.globalMessageNumber, fieldDef.fieldNumber),
        offset: _getFieldOffset(definition.globalMessageNumber, fieldDef.fieldNumber),
        units: _getFieldUnits(definition.globalMessageNumber, fieldDef.fieldNumber),
      ));
    }

    // Parse developer fields
    final developerFields = <DeveloperField>[];
    for (final devFieldDef in definition.developerFieldDefinitions) {
      final rawValue = _readBytes(devFieldDef.size);

      // Look up developer field definition
      final devDataIndex = devFieldDef.developerDataIndex.toString();
      final fieldDefs = _developerFieldDefinitions[devDataIndex];
      final fieldInfo = fieldDefs?[devFieldDef.fieldNumber];

      // Parse value based on base type if we have field info
      dynamic value = rawValue;
      if (fieldInfo != null) {
        final baseType = FitBaseTypes.getById(fieldInfo.baseTypeId);
        if (baseType != null && rawValue.isNotEmpty) {
          _position -= rawValue.length; // Rewind to read typed value
          value = _readFieldValue(devFieldDef.size, baseType, endian);
          // Position is already advanced by _readFieldValue
        }
      }

      developerFields.add(DeveloperField(
        fieldNumber: devFieldDef.fieldNumber,
        name: fieldInfo?.fieldName,
        developerDataIndex: devFieldDef.developerDataIndex,
        baseTypeId: fieldInfo?.baseTypeId ?? 0x0D, // Default to byte
        value: value,
        units: fieldInfo?.units,
      ));
    }

    // Extract timestamp if available
    DateTime? timestamp;
    final timestampField = fields.where((f) => f.fieldNumber == 253).firstOrNull;
    if (timestampField != null && timestampField.value != null) {
      _lastTimestamp = timestampField.value as int;
      timestamp = _fitTimestampToDateTime(_lastTimestamp);
    }

    // Create data message
    final dataMessage = FitDataMessage(
      localMessageNumber: localMessageType,
      globalMessageNumber: definition.globalMessageNumber,
      fields: fields,
      developerFields: developerFields,
      timestamp: timestamp,
    );

    _messages.add(dataMessage);

    // Cache developer field definitions if this is a field_description message
    if (definition.globalMessageNumber == 206) {
      _cacheFieldDescription(dataMessage);
    }
  }

  /// Read field value based on size and type.
  dynamic _readFieldValue(int size, FitBaseType baseType, Endian endian) {
    // Handle string type
    if (baseType.isString) {
      final stringBytes = _readBytes(size);
      // Find null terminator
      var length = stringBytes.length;
      for (var i = 0; i < stringBytes.length; i++) {
        if (stringBytes[i] == 0) {
          length = i;
          break;
        }
      }
      return String.fromCharCodes(stringBytes.sublist(0, length));
    }

    // Handle array types (multiple values of same base type)
    final numValues = size ~/ baseType.size;
    if (numValues > 1) {
      final values = <dynamic>[];
      for (var i = 0; i < numValues; i++) {
        values.add(_readTypedValue(baseType, endian));
      }
      return values;
    }

    // Handle single value
    if (numValues == 1) {
      return _readTypedValue(baseType, endian);
    }

    // If size doesn't match, read as bytes
    return _readBytes(size);
  }

  /// Read a typed value based on base type.
  dynamic _readTypedValue(FitBaseType baseType, Endian endian) {
    switch (baseType.id) {
      case 0x00: // enum
      case 0x02: // uint8
      case 0x0A: // uint8z
      case 0x0D: // byte
        return _readByte();

      case 0x01: // sint8
        final value = _readByte();
        return value > 0x7F ? value - 0x100 : value;

      case 0x84: // uint16
      case 0x8B: // uint16z
        return _readUint16(endian);

      case 0x83: // sint16
        final value = _readUint16(endian);
        return value > 0x7FFF ? value - 0x10000 : value;

      case 0x86: // uint32
      case 0x8C: // uint32z
        return _readUint32(endian);

      case 0x85: // sint32
        final value = _readUint32(endian);
        return value > 0x7FFFFFFF ? value - 0x100000000 : value;

      case 0x88: // float32
        return _readFloat32(endian);

      case 0x89: // float64
        return _readFloat64(endian);

      default:
        // Unknown type, read as bytes
        return _readBytes(baseType.size);
    }
  }

  /// Cache field description for developer fields.
  void _cacheFieldDescription(FitDataMessage message) {
    final devDataIndex = message.getField('developer_data_index')?.toString() ?? '0';
    final fieldDefNum = message.getField('field_definition_number') as int?;
    final baseTypeId = message.getField('base_type_id') as int?;
    final fieldName = message.getField('field_name') as String?;
    final units = message.getField('units') as String?;

    if (fieldDefNum != null && baseTypeId != null) {
      _developerFieldDefinitions.putIfAbsent(devDataIndex, () => {});
      _developerFieldDefinitions[devDataIndex]![fieldDefNum] = _DeveloperFieldInfo(
        fieldName: fieldName,
        baseTypeId: baseTypeId,
        units: units,
      );
    }
  }

  /// Convert FIT timestamp to DateTime.
  DateTime _fitTimestampToDateTime(int fitTimestamp) {
    // FIT timestamp is seconds since UTC 00:00 Dec 31 1989
    const fitEpoch = 631065600; // Unix timestamp for Dec 31 1989
    final unixTimestamp = fitEpoch + fitTimestamp;
    return DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000, isUtc: true);
  }

  /// Get field name from FIT profile (simplified version).
  String? _getFieldName(int? globalMessageNumber, int fieldNumber) {
    // This is a simplified mapping - a complete implementation would use the full FIT profile
    if (globalMessageNumber == 0) {
      // file_id
      switch (fieldNumber) {
        case 0:
          return 'type';
        case 1:
          return 'manufacturer';
        case 2:
          return 'product';
        case 3:
          return 'serial_number';
        case 4:
          return 'time_created';
        case 5:
          return 'number';
      }
    } else if (globalMessageNumber == 20) {
      // record
      switch (fieldNumber) {
        case 253:
          return 'timestamp';
        case 0:
          return 'position_lat';
        case 1:
          return 'position_long';
        case 2:
          return 'altitude';
        case 3:
          return 'heart_rate';
        case 4:
          return 'cadence';
        case 5:
          return 'distance';
        case 6:
          return 'speed';
        case 7:
          return 'power';
        case 13:
          return 'temperature';
      }
    } else if (globalMessageNumber == 19) {
      // lap
      switch (fieldNumber) {
        case 253:
          return 'timestamp';
        case 7:
          return 'total_elapsed_time';
        case 9:
          return 'total_distance';
        case 16:
          return 'avg_heart_rate';
        case 17:
          return 'max_heart_rate';
      }
    } else if (globalMessageNumber == 18) {
      // session
      switch (fieldNumber) {
        case 253:
          return 'timestamp';
        case 5:
          return 'sport';
        case 6:
          return 'sub_sport';
        case 7:
          return 'total_elapsed_time';
        case 9:
          return 'total_distance';
        case 11:
          return 'total_calories';
        case 16:
          return 'avg_heart_rate';
        case 17:
          return 'max_heart_rate';
      }
    } else if (globalMessageNumber == 206) {
      // field_description
      switch (fieldNumber) {
        case 0:
          return 'developer_data_index';
        case 1:
          return 'field_definition_number';
        case 2:
          return 'base_type_id';
        case 3:
          return 'field_name';
        case 8:
          return 'units';
      }
    }
    return null;
  }

  /// Get field scale factor from FIT profile.
  double? _getFieldScale(int? globalMessageNumber, int fieldNumber) {
    if (globalMessageNumber == 20) {
      // record
      switch (fieldNumber) {
        case 5:
          return 100.0; // distance (cm -> m)
        case 6:
          return 1000.0; // speed (mm/s -> m/s)
      }
    } else if (globalMessageNumber == 19 || globalMessageNumber == 18) {
      // lap, session
      switch (fieldNumber) {
        case 7:
          return 1000.0; // total_elapsed_time (ms -> s)
        case 9:
          return 100.0; // total_distance (cm -> m)
      }
    }
    return null;
  }

  /// Get field offset from FIT profile.
  double? _getFieldOffset(int? globalMessageNumber, int fieldNumber) {
    // Most fields don't have offsets
    return null;
  }

  /// Get field units from FIT profile.
  String? _getFieldUnits(int? globalMessageNumber, int fieldNumber) {
    if (globalMessageNumber == 20) {
      // record
      switch (fieldNumber) {
        case 0:
        case 1:
          return 'semicircles';
        case 2:
          return 'm';
        case 3:
          return 'bpm';
        case 4:
          return 'rpm';
        case 5:
          return 'm';
        case 6:
          return 'm/s';
        case 7:
          return 'watts';
        case 13:
          return 'C';
      }
    }
    return null;
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

  /// Read uint16 value.
  int _readUint16([Endian endian = Endian.little]) {
    final data = _readBytes(2);
    return ByteData.view(data.buffer, data.offsetInBytes).getUint16(0, endian);
  }

  /// Read uint32 value.
  int _readUint32([Endian endian = Endian.little]) {
    final data = _readBytes(4);
    return ByteData.view(data.buffer, data.offsetInBytes).getUint32(0, endian);
  }

  /// Read float32 value.
  double _readFloat32([Endian endian = Endian.little]) {
    final data = _readBytes(4);
    return ByteData.view(data.buffer, data.offsetInBytes).getFloat32(0, endian);
  }

  /// Read float64 value.
  double _readFloat64([Endian endian = Endian.little]) {
    final data = _readBytes(8);
    return ByteData.view(data.buffer, data.offsetInBytes).getFloat64(0, endian);
  }
}

/// Internal class for storing developer field metadata.
///
/// Developer fields (like CORE temperature sensor) are defined in field_description
/// messages (type 206) before they appear in data messages. This class caches the
/// metadata needed to parse developer field values.
///
/// The metadata includes:
/// - [fieldName]: Human-readable name (e.g., "core_temperature")
/// - [baseTypeId]: FIT base type ID for parsing the value (e.g., 136 = float32)
/// - [units]: Optional units string (e.g., "°C", "bpm")
///
/// Example from CORE sensor:
/// ```dart
/// _DeveloperFieldInfo(
///   fieldName: 'core_temperature',
///   baseTypeId: 136, // float32
///   units: '°C',
/// )
/// ```
class _DeveloperFieldInfo {
  /// Human-readable field name (e.g., "core_temperature", "skin_temperature").
  final String? fieldName;

  /// FIT base type ID for parsing values (e.g., 136 = float32, 2 = uint8).
  final int baseTypeId;

  /// Optional units string (e.g., "°C", "bpm", "rpm").
  final String? units;

  const _DeveloperFieldInfo({
    this.fieldName,
    required this.baseTypeId,
    this.units,
  });
}
