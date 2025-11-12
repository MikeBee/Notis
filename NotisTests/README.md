# Notis Test Suite

## Overview

This test suite provides comprehensive testing for Notis app's critical data integrity areas. The tests are designed to prevent data loss, corruption, and crashes.

## Test Structure

```
NotisTests/
├── TestHelpers/
│   ├── TestDataFactory.swift          # Factory for creating test data
│   └── XCTestCase+Extensions.swift    # Common test utilities
├── PersistenceControllerTests.swift   # Core Data tests
└── Services/
    ├── TagServiceTests.swift          # Tag processing tests
    ├── MarkdownFileServiceTests.swift # File system tests
    └── BackupServiceTests.swift       # Backup/restore tests
```

## Running Tests

### From Xcode
1. Open `Notis.xcodeproj`
2. Select the NotisTests target
3. Press `⌘ + U` to run all tests
4. Or press `⌘ + 6` to open Test Navigator and run individual tests

### From Command Line
```bash
xcodebuild test -scheme Notis -destination 'platform=macOS'
```

## Test Categories

### 1. Core Data Tests (`PersistenceControllerTests.swift`)
**Purpose**: Ensure Core Data operations don't lose or corrupt user data

**Tests**: 50+ tests covering:
- ✅ Store initialization without crashes (replaces fatalError)
- ✅ Sheet CRUD operations
- ✅ Group CRUD operations
- ✅ Soft delete (trash) functionality
- ✅ Data integrity (UUIDs, relationships, dates)
- ✅ Batch operations (100+ sheets)
- ✅ Query performance
- ✅ Thread safety
- ✅ Error recovery

**Key Protection**: Prevents crashes when Core Data initialization fails (our recent fix).

### 2. Tag Service Tests (`TagServiceTests.swift`)
**Purpose**: Verify tag processing doesn't crash and correctly handles inline tags

**Tests**: 25+ tests covering:
- ✅ Inline hashtag detection (#tag)
- ✅ Nested tags (#project/work/client)
- ✅ Special characters and unicode
- ✅ Tag hierarchy creation/deletion
- ✅ Tag-sheet associations
- ✅ Duplicate tag handling
- ✅ Performance with 100+ tags
- ✅ Regex compilation safety (our recent fix)

**Key Protection**: Ensures the `try!` → `guard let try?` fix works correctly.

### 3. Markdown File Service Tests (`MarkdownFileServiceTests.swift`)
**Purpose**: Prevent file corruption and data loss during file operations

**Tests**: 30+ tests covering:
- ✅ File creation with valid YAML frontmatter
- ✅ Special characters and emoji preservation
- ✅ Line break preservation
- ✅ YAML parsing (valid, invalid, malformed)
- ✅ File updates without data loss
- ✅ File deletion
- ✅ Trash operations
- ✅ Round-trip save/load integrity
- ✅ Multiple file collision prevention
- ✅ Error handling (read-only directories, corrupted files)
- ✅ Performance with large content (10,000+ lines)
- ✅ Batch operations (50 files)

**Key Protection**: Ensures notes are never corrupted when saved to/loaded from disk.

### 4. Backup Service Tests (`BackupServiceTests.swift`)
**Purpose**: Verify backups work correctly and don't lose data

**Tests**: 20+ tests covering:
- ✅ Backup creation with no data
- ✅ Backup creation with multiple sheets
- ✅ Group hierarchy preservation
- ✅ Relationship preservation
- ✅ UUID preservation
- ✅ Date preservation
- ✅ Concurrent backup prevention
- ✅ Error handling (corrupted data, empty strings)
- ✅ Performance with 100+ sheets
- ✅ Memory leak prevention

**Key Protection**: Ensures backups reliably protect user data.

## Test Helpers

### TestDataFactory
Provides factory methods for creating test objects:
- `createSheet()` - Creates test sheets
- `createSheets(count:)` - Batch creates sheets
- `createGroup()` - Creates groups with optional parents
- `createTag()` - Creates tags
- `createTagPath()` - Creates hierarchical tags
- `createGoal()` - Creates goals
- `createTemplate()` - Creates templates

### XCTestCase Extensions
Common utilities for all tests:
- `waitForCondition()` - Wait for async conditions
- `createTestPersistenceController()` - In-memory Core Data
- `saveContext()` - Save with automatic error checking
- `fetchAll()` - Fetch all objects of a type
- `count()` - Count objects with optional predicate
- `createTempDirectory()` - Temporary file system
- `XCTAssertNotNaN()` - Verify no NaN values

## Coverage Goals

**Current Focus**: Phase 1 - Critical Data Integrity (✅ Complete)
- Core Data operations: **50+ tests**
- Tag processing: **25+ tests**
- File operations: **30+ tests**
- Backup/restore: **20+ tests**

**Total**: **125+ tests** protecting critical user data paths

**Phase 2** (Future):
- Service layer tests (Goals, Templates, Export)
- Integration tests (CoreData ↔ File sync)
- UI tests (end-to-end workflows)

## Best Practices

### Writing New Tests
1. Use `TestDataFactory` to create test data
2. Use in-memory Core Data (`PersistenceController(inMemory: true)`)
3. Clean up in `tearDown()`
4. Test both success and error cases
5. Include performance tests for operations on large datasets
6. Verify no crashes with invalid/corrupted data

### Test Naming
- `test<FunctionName>_<Scenario>()` format
- Examples:
  - `testCreateSheet()` - happy path
  - `testCreateSheet_HandlesEmptyTitle()` - edge case
  - `testCreateSheet_PreservesRelationships()` - data integrity

### Assertions
- Use descriptive failure messages
- Test one thing per test method
- Use helper assertions (`XCTAssertNotNaN`, etc.)

## Continuous Integration

### Recommended Setup
Add to GitHub Actions workflow:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: xcodebuild test -scheme Notis -destination 'platform=macOS'
```

### Pre-commit Hook
Run tests before each commit:

```bash
#!/bin/sh
# .git/hooks/pre-commit
xcodebuild test -scheme Notis -destination 'platform=macOS' || exit 1
```

## Maintenance

### When to Update Tests
- ✅ After fixing bugs (add regression test)
- ✅ Before adding features (TDD)
- ✅ When changing data models
- ✅ When refactoring critical code

### Test Health
- Keep tests fast (< 5 minutes total)
- Keep tests independent (no shared state)
- Keep tests deterministic (no random data)
- Update tests when APIs change

## Known Limitations

1. **CloudKit Testing**: BackupService tests don't fully test CloudKit integration (requires live CloudKit connection)
2. **UI Tests**: Not yet implemented (Phase 3)
3. **Migration Tests**: Core Data migrations not yet tested
4. **Search Tests**: FTS5 search indexing not yet tested

## Results Tracking

Run tests and check:
- All tests pass: ✅ Ready to deploy
- Some tests fail: ❌ Fix before deploying
- Tests crash: 🚨 Critical issue, fix immediately

## Questions?

- Check test output for specific failures
- Review test code for expected behavior
- See `TestDataFactory` for available test data
- See `XCTestCase+Extensions` for helper methods
