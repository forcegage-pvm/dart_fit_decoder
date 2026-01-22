# dart_fit_decoder Constitution

## Core Principles

### I. Pure Dart Implementation (NON-NEGOTIABLE)

**Zero native dependencies.** The package MUST:

- Use only pure Dart/Flutter SDK packages
- Work identically across all platforms (Web, Mobile, Desktop)
- Rely on `dart:typed_data` for binary parsing
- Never require platform-specific compilation or native code

**Rationale:** Cross-platform compatibility is fundamental. Native dependencies create deployment complexity, platform inconsistencies, and maintenance burden. Binary FIT parsing is fully achievable with Dart's typed data capabilities.

### II. Test-Driven Development (NON-NEGOTIABLE)

**TDD is mandatory for all features.** Development MUST follow:

1. **Write tests first** - Define expected behavior before implementation
2. **Validate with real data** - Use actual Garmin FIT files, not synthetic data only
3. **Red-Green-Refactor** - Tests fail → Implement → Tests pass → Refactor
4. **Comprehensive coverage** - Unit tests, integration tests, real-world validation

**Minimum Standards:**

- ≥95% code coverage for core decoder logic
- ≥100% real-world file test success rate
- All public APIs must have usage examples in tests
- Performance benchmarks validated with actual FIT files

**Rationale:** Binary parsing is error-prone. TDD catches edge cases, endianness issues, and protocol violations early. Real-world validation ensures production readiness.

### III. Binary Protocol Correctness (NON-NEGOTIABLE)

**Exact FIT specification compliance.** The decoder MUST:

- Match official Garmin SDK output byte-for-byte
- Handle all FIT base types (uint8, sint16, float32, etc.)
- Support both little-endian and big-endian architectures
- Correctly parse compressed timestamps
- Process developer fields per FIT protocol specification

**Validation:**

- Output must match `garmin_fit_sdk` (official Python SDK) exactly
- Test against minimum 10 different real-world FIT files
- Verify with files from multiple device manufacturers
- Include files with and without developer fields

**Rationale:** FIT is a binary protocol with strict rules. Incorrect parsing corrupts data silently. We validate against official SDKs to ensure correctness.

### IV. Immutable Data Structures

**Parsed data MUST be immutable.** All classes MUST:

- Use `final` fields exclusively
- Provide `const` constructors where possible
- Never expose mutable collections directly
- Return new instances for modifications (if needed)

**Example:**

```dart
class FitHeader {
  final int headerSize;
  final int protocolVersion;
  final int profileVersion;
  final int dataSize;

  const FitHeader({
    required this.headerSize,
    required this.protocolVersion,
    required this.profileVersion,
    required this.dataSize,
  });
}
```

**Rationale:** Immutability prevents accidental data corruption, enables safe concurrent access, and makes code easier to reason about. FIT data is read-only by nature.

### V. Clear Error Handling

**Errors MUST be explicit and actionable.** The package MUST:

- Define specific exception types for each error category
- Include context in error messages (position, expected vs actual)
- Never swallow exceptions silently
- Provide recovery guidance where possible

**Exception Categories:**

- `InvalidHeaderException` - Malformed file header
- `MissingDefinitionException` - Undefined local message referenced
- `InsufficientDataException` - File truncated or corrupted
- `UnsupportedProtocolException` - Protocol version not supported

**Rationale:** Binary parsing fails in many ways. Clear errors enable quick diagnosis. Users need to know what's wrong and where.

### VI. Documentation as Code

**Every public API MUST be documented.** Documentation MUST include:

- Purpose and behavior description
- Parameter explanations with types and constraints
- Return value documentation
- Usage examples (simple + complex scenarios)
- Performance characteristics (if relevant)
- Related APIs and common patterns

**Example:**

```dart
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
///
/// Performance: Decodes 1-2 MB files in <1 second on modern hardware.
FitFile decode() { ... }
```

**Rationale:** Good documentation reduces support burden and enables effective usage. Code is read more than written.

### VII. Performance by Design

**Efficiency MUST be built-in, not bolted-on.** The decoder MUST:

- Stream-parse files (no full-file buffering)
- Cache definition messages efficiently
- Use `ByteData` views (no unnecessary copies)
- Parse fields on-demand where beneficial
- Target <1 second for 1-2 MB files

**Prohibited Patterns:**

- Loading entire file into List<int> before processing
- Creating intermediate string representations of binary data
- Repeated lookups of cached definitions
- Unnecessary object allocations in hot paths

**Rationale:** FIT files can be large (100+ MB for long activities). Inefficient parsing makes the library unusable for real-world applications.

## Architecture Standards

### Binary Parsing Architecture

The decoder MUST follow this layered structure:

1. **Header Layer** (`FitHeader`)
   - Parse 14-byte header structure
   - Validate protocol and signature
   - Extract data size for bounds checking

2. **Message Parsing Layer** (`FitDecoder`)
   - Dispatch to definition or data message parsers
   - Handle compressed vs normal timestamp headers
   - Maintain state (definitions cache, last timestamp)

3. **Definition Layer** (`FitDefinitionMessage`)
   - Parse field definitions
   - Cache by local message number
   - Support developer field definitions

4. **Data Extraction Layer** (`FitDataMessage`)
   - Read typed values using base type definitions
   - Apply scaling and offsets
   - Map field numbers to names
   - Extract developer fields

5. **Type System** (`FitBaseType`)
   - Define all 14 FIT base types
   - Handle endianness correctly
   - Validate sizes and invalid values

### Developer Field Architecture

Developer fields (custom sensor data like CORE temperature) require two-stage parsing:

**Stage 1: Definition Collection**

- Parse `developer_data_id` messages (type 207)
- Parse `field_description` messages (type 206)
- Cache: `developer_data_index` → `field_number` → `(name, type, units)`

**Stage 2: Value Extraction**

- Check definition message for `hasDeveloperData` flag
- Read developer field bytes after standard fields
- Look up cached definition by index and field number
- Parse typed value using base type from cache
- Create `DeveloperField` with name, value, units

### Naming Conventions

- **Classes**: PascalCase (e.g., `FitDecoder`, `FitDataMessage`)
- **Files**: snake_case matching class name (e.g., `fit_decoder.dart`)
- **Private fields**: Leading underscore (e.g., `_position`, `_definitions`)
- **Constants**: lowerCamelCase (e.g., `fitEpoch`, not `FIT_EPOCH`)
- **Methods**: lowerCamelCase with verb prefixes (e.g., `parseMessage`, `getRecordMessages`)

### File Organization

```
lib/
├── dart_fit_decoder.dart          # Public API exports
└── src/
    ├── fit_decoder.dart            # Main decoder
    ├── fit_file.dart               # Parsed file container
    ├── fit_header.dart             # Header parser
    ├── fit_message.dart            # Base message class
    ├── fit_definition_message.dart # Definition message
    ├── fit_data_message.dart       # Data message
    ├── fit_field.dart              # Standard field
    ├── developer_field.dart        # Developer field
    ├── fit_base_type.dart          # Type system
    ├── fit_message_type.dart       # Message type constants
    └── exceptions.dart             # Exception types
```

## Testing Standards

### Test Categories (All Required)

**1. Unit Tests** (`test/*_test.dart`)

- Test each class in isolation
- Mock dependencies where needed
- Cover all edge cases and error paths
- Test file examples: `fit_decoder_test.dart`, `fit_header_test.dart`

**2. Integration Tests** (`test/integration_test.dart`)

- Test complete decode workflows
- Verify message interactions
- Test cross-cutting concerns (CRC, timestamps)

**3. Real-World Tests** (`test/real_fit_file_test.dart`)

- Use actual Garmin FIT files as fixtures
- Validate against official SDK output
- Test performance with large files (25K+ records)
- Include files with developer fields (CORE temperature)

**4. Edge Case Tests** (`test/edge_case_test.dart`)

- Truncated files
- Invalid headers
- Missing definitions
- Corrupted data
- Boundary conditions

### Test Data Management

- **Fixtures**: Store real FIT files in `test/fixtures/`
- **Size limit**: Keep fixtures <5 MB (use smallest representative files)
- **Documentation**: Document source and key characteristics of each fixture
- **Privacy**: Ensure fixtures don't contain personal data

### Test Execution Requirements

- All tests MUST pass before merging
- Real-world tests MUST achieve 100% pass rate
- Performance tests MUST meet <1 second target for 1-2 MB files
- No skipped tests allowed in main branch (unless explicitly justified and time-boxed)

## Quality Gates

### Pre-Commit Requirements

1. `dart format` - Code formatted
2. `dart analyze` - Zero warnings/errors
3. `dart test` - All tests passing
4. Documentation updated for API changes

### Pre-Release Requirements

1. Version number incremented per semantic versioning
2. changelog.md updated with changes
3. README.md examples validated
4. Performance benchmarks re-run and documented
5. Real-world test suite expanded if new features added

### Code Review Standards

- Minimum 1 reviewer approval required
- Reviewer MUST verify test coverage
- Reviewer MUST validate against constitution principles
- Breaking changes require explicit justification

## Dependencies Policy

### Allowed Dependencies

- **Dart SDK packages**: `dart:typed_data`, `dart:math`, etc.
- **Flutter SDK packages**: For Flutter-specific features only
- **Core packages**: `typed_data`, `latlong2` (geodesic calculations)
- **Dev dependencies**: `test`, `lints`, coverage tools

### Prohibited Dependencies

- Native platform packages (e.g., FFI, platform channels)
- Packages with native code compilation
- Heavy framework dependencies (unless Flutter-specific features needed)
- Packages that duplicate Dart SDK functionality

### Dependency Addition Process

1. Justify necessity (can't implement reasonably in pure Dart)
2. Verify license compatibility (MIT, BSD, Apache 2.0)
3. Check maintenance status (recent updates, active maintainer)
4. Validate platform compatibility (works on Web, Mobile, Desktop)
5. Document in pubspec.yaml with purpose comment

## Versioning & Breaking Changes

### Semantic Versioning (MAJOR.MINOR.PATCH)

- **MAJOR**: Breaking API changes, removed features
- **MINOR**: New features, non-breaking additions
- **PATCH**: Bug fixes, performance improvements, documentation

### Breaking Change Policy

- Breaking changes REQUIRE major version bump
- Deprecation warnings MUST precede removal (minimum 1 minor version)
- Migration guide MUST be provided in CHANGELOG
- Breaking changes MUST be justified (security, correctness, major improvement)

**Example:**

```
v1.0.0 → v1.1.0: Add getSessionMessages() method (NON-BREAKING)
v1.1.0 → v1.2.0: Deprecate old API (NON-BREAKING, warning added)
v1.2.0 → v2.0.0: Remove deprecated API (BREAKING)
```

## Performance Standards

### Targets (NON-NEGOTIABLE)

- **Small files** (<1 MB): <500ms decode time
- **Medium files** (1-2 MB): <1 second decode time
- **Large files** (>10 MB): <10 seconds decode time
- **Memory**: <2x file size peak memory usage
- **Efficiency**: No performance degradation with developer fields

### Measurement

- Benchmark with `Stopwatch` in test suite
- Test on standard hardware (mid-range laptop/phone)
- Report 95th percentile times (not best case)
- Re-validate on every release

### Optimization Guidelines

- Profile before optimizing (use DevTools)
- Focus on hot paths (message parsing, field extraction)
- Avoid premature optimization
- Document performance-critical code sections

## Governance

### Constitution Authority

This constitution is the supreme authority for the dart_fit_decoder project. It supersedes:

- Individual preferences
- External coding standards (unless explicitly adopted here)
- "Common practices" that conflict with principles

### Amendment Process

1. Propose amendment with justification
2. Demonstrate need (example cases where current rules fail)
3. Impact analysis (affected code, migration effort)
4. Team review and consensus
5. Update version number and amendment date
6. Document in git commit

### Compliance

- All PRs MUST comply with constitution
- Reviewers MUST verify constitutional compliance
- Non-compliance blocks merge
- Repeated violations trigger constitution review (rules may be wrong)

### Living Document

- Constitution evolves with project needs
- Lessons learned inform amendments
- Quarterly review of principles effectiveness
- Remove rules that add friction without value

---

**Version**: 1.0.0  
**Ratified**: 2025-11-20  
**Last Amended**: 2025-11-20  
**Next Review**: 2026-02-20
