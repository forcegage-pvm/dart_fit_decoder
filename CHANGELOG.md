# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-20

### Added
- Initial package scaffolding
- Basic package structure with lib/, test/, example/ directories
- Comprehensive README with usage examples
- MIT License
- pubspec.yaml with package metadata and dependencies
- CI/CD workflow templates

### Planned Features
- FIT file header parsing (14-byte structure)
- Definition message parsing (local to global message mapping)
- Data message parsing with field extraction
- Developer field support (field_description and developer_data_id)
- CRC validation
- Record, lap, and session message extraction
- CORE temperature sensor data support
- Geodesic distance calculations
- Comprehensive test suite
- Example applications

## [Unreleased]

### To Be Implemented
- Binary reader with typed_data support
- All FIT base types (uint8, sint16, float32, etc.)
- Compressed timestamp support
- Message type registry
- Field value scaling and unit conversion
- Multi-file batch processing
- Performance optimization for large files

---

[0.1.0]: https://github.com/forcegage-pvm/dart_fit_decoder/releases/tag/v0.1.0

