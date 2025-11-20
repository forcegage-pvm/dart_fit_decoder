/// FIT protocol base types with their IDs, sizes, and invalid values.
library;

/// Represents a FIT base type with its metadata.
class FitBaseType {
  final int id;
  final String name;
  final int size;
  final dynamic invalidValue;
  final bool isSigned;
  final bool isString;
  
  const FitBaseType({
    required this.id,
    required this.name,
    required this.size,
    required this.invalidValue,
    this.isSigned = false,
    this.isString = false,
  });
  
  @override
  String toString() => 'FitBaseType($name, id=$id, size=$size)';
}

/// FIT protocol base types.
class FitBaseTypes {
  static const enum8 = FitBaseType(
    id: 0x00,
    name: 'enum',
    size: 1,
    invalidValue: 0xFF,
  );
  
  static const sint8 = FitBaseType(
    id: 0x01,
    name: 'sint8',
    size: 1,
    invalidValue: 0x7F,
    isSigned: true,
  );
  
  static const uint8 = FitBaseType(
    id: 0x02,
    name: 'uint8',
    size: 1,
    invalidValue: 0xFF,
  );
  
  static const sint16 = FitBaseType(
    id: 0x83,
    name: 'sint16',
    size: 2,
    invalidValue: 0x7FFF,
    isSigned: true,
  );
  
  static const uint16 = FitBaseType(
    id: 0x84,
    name: 'uint16',
    size: 2,
    invalidValue: 0xFFFF,
  );
  
  static const sint32 = FitBaseType(
    id: 0x85,
    name: 'sint32',
    size: 4,
    invalidValue: 0x7FFFFFFF,
    isSigned: true,
  );
  
  static const uint32 = FitBaseType(
    id: 0x86,
    name: 'uint32',
    size: 4,
    invalidValue: 0xFFFFFFFF,
  );
  
  static const string = FitBaseType(
    id: 0x07,
    name: 'string',
    size: 1, // Variable length
    invalidValue: null,
    isString: true,
  );
  
  static const float32 = FitBaseType(
    id: 0x88,
    name: 'float32',
    size: 4,
    invalidValue: 0xFFFFFFFF,
  );
  
  static const float64 = FitBaseType(
    id: 0x89,
    name: 'float64',
    size: 8,
    invalidValue: 0xFFFFFFFFFFFFFFFF,
  );
  
  static const uint8z = FitBaseType(
    id: 0x0A,
    name: 'uint8z',
    size: 1,
    invalidValue: 0x00,
  );
  
  static const uint16z = FitBaseType(
    id: 0x8B,
    name: 'uint16z',
    size: 2,
    invalidValue: 0x0000,
  );
  
  static const uint32z = FitBaseType(
    id: 0x8C,
    name: 'uint32z',
    size: 4,
    invalidValue: 0x00000000,
  );
  
  static const byte = FitBaseType(
    id: 0x0D,
    name: 'byte',
    size: 1,
    invalidValue: 0xFF,
  );
  
  /// Get base type by ID.
  static FitBaseType? getById(int id) {
    switch (id) {
      case 0x00: return enum8;
      case 0x01: return sint8;
      case 0x02: return uint8;
      case 0x83: return sint16;
      case 0x84: return uint16;
      case 0x85: return sint32;
      case 0x86: return uint32;
      case 0x07: return string;
      case 0x88: return float32;
      case 0x89: return float64;
      case 0x0A: return uint8z;
      case 0x8B: return uint16z;
      case 0x8C: return uint32z;
      case 0x0D: return byte;
      default: return null;
    }
  }
  
  /// Get all base types.
  static List<FitBaseType> get all => [
    enum8, sint8, uint8, sint16, uint16, sint32, uint32,
    string, float32, float64, uint8z, uint16z, uint32z, byte,
  ];
}
