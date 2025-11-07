# 🏷️ Tag System Implementation for Notis

## Overview

This implementation adds a comprehensive Bear-style tag system to Notis with nested hierarchies, tag search, and tag-based filtering. The system provides both manual and inline tagging capabilities.

## ✨ Features Implemented

### 1. Core Tag System
- **Nested Tag Hierarchies**: Using `/` syntax (e.g., `#research/ai/ethics`)
- **Auto-Creation**: Parent tags are automatically created when typing nested paths
- **Tag Colors**: 8 predefined colors for visual organization
- **Tag Renaming & Merging**: Full tag management capabilities
- **Many-to-Many Relationships**: Sheets can have multiple tags, tags can be on multiple sheets

### 2. Tag Navigation & Browsing
- **Tag Tree View**: Collapsible hierarchy in the Library sidebar
- **Tab-Based Interface**: Switch between Groups and Tags in the Library
- **Tag Counts**: Show number of sheets per tag (including subtags)
- **Breadcrumb Navigation**: Clear hierarchy visualization

### 3. Tag Search & Filtering
- **Search-as-you-type**: Instant tag and note filtering
- **Boolean Operations**: AND, OR, NOT combinations for multiple tags
- **Smart Suggestions**: Related tags based on content and usage
- **Tag Intersection**: Combine multiple tags for precise filtering

### 4. Note Association & Organization
- **Inline Tagging**: Type `#tag` anywhere in text for automatic indexing
- **Tag Editor**: Dedicated interface at bottom of editor for tag management
- **Quick Tag Input**: Support for hierarchical tag creation via keyboard
- **Backlink Preview**: (Prepared for future implementation)

### 5. User Interface Integration
- **Dual View Modes**: Tag view and traditional folder view
- **Tag Chips**: Visual tag representation with color coding
- **Empty States**: Helpful messaging when no tags or sheets found
- **Keyboard Shortcuts**: Fast tag operations via keyboard

## 🗂️ File Structure

### New Files Created:
```
Notis/Services/
├── TagService.swift           # Core tag management logic

Notis/Views/
├── TagTreeView.swift          # Tag hierarchy browser
├── TagEditorView.swift        # Tag input and management UI
```

### Modified Files:
```
Notis/
├── Notis.xcdatamodeld/Notis.xcdatamodel/contents  # Added Tag & SheetTag entities
├── ContentView.swift                               # Added tag keyboard shortcuts
├── Views/
│   ├── LibrarySidebar.swift                       # Added tag/group tabs
│   ├── SheetListView.swift                        # Added tag filtering support
│   └── EditorView.swift                           # Integrated tag editor
└── Extensions/
    └── NotificationName+Extensions.swift          # Added tag notifications
```

## 📊 Data Model Changes

### New Core Data Entities:

#### Tag Entity
```swift
- id: UUID
- name: String           // Tag display name
- path: String           // Full hierarchical path (e.g., "research/ai/ethics")
- color: String          // Color identifier
- sortOrder: Int32       // Manual ordering within parent
- createdAt: Date
- modifiedAt: Date
- parent: Tag?           // Parent tag for hierarchy
- children: [Tag]        // Child tags
- sheetTags: [SheetTag]  // Associated sheets via junction table
```

#### SheetTag Entity (Junction Table)
```swift
- id: UUID
- createdAt: Date
- sheet: Sheet           // Reference to sheet
- tag: Tag               // Reference to tag
```

### Modified Entities:
- **Sheet**: Added `tags` relationship to `[SheetTag]`

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘T` | Focus tag input field |
| `⌘⇧F` | Switch to tag filtering mode |
| `⌘⇧T` | Show template selection (unchanged) |

## 🎯 Usage Examples

### Creating Tags
1. **Inline**: Type `#research/ai` anywhere in note content
2. **Tag Editor**: Use the tag input at bottom of editor
3. **Manual**: Click "+" in Tags tab of Library sidebar

### Organizing with Hierarchies
- `#projects/work/meeting-notes`
- `#research/ai/machine-learning`
- `#personal/health/exercise`

### Filtering and Search
1. Switch to "Tags" tab in Library sidebar
2. Click tags to select them for filtering
3. Use AND/OR/NOT operations for complex queries
4. Search within tag names for quick discovery

## 🔧 Technical Implementation Details

### Tag Service Architecture
- **Singleton Pattern**: `TagService.shared` for global access
- **ObservableObject**: Reactive UI updates via `@Published` properties
- **Core Data Integration**: Efficient queries and relationship management

### Performance Considerations
- **Lazy Loading**: Tag trees loaded on demand
- **Indexed Search**: Core Data predicates for fast tag lookup
- **Debounced Input**: Search-as-you-type with proper debouncing
- **Memory Efficient**: Uses `Set<Tag>` for O(1) selection operations

### CloudKit Sync Support
- All new entities marked as `syncable="YES"`
- Automatic conflict resolution for tag hierarchies
- Merge-friendly tag path system for cross-device sync

## 🚀 Future Enhancements

### Phase 2 Features (Not Implemented Yet)
1. **Backlink Previews**: Hover tooltips showing tagged notes
2. **Tag Analytics**: Usage statistics and insights
3. **Smart Tag Suggestions**: AI-powered tag recommendations
4. **Tag Templates**: Pre-defined tag sets for projects
5. **Cross-App Linking**: URL scheme for tag navigation
6. **Tag Aliases**: Alternative names for same concepts
7. **Tag Import/Export**: JSON-based tag system backup

### Advanced Features
- **Tag Graphs**: Visual relationship mapping
- **Saved Searches**: Persistent tag filter combinations
- **Tag Automation**: Rules for auto-tagging based on content
- **Tag Inheritance**: Automatic parent tag application

## 🐛 Known Limitations

1. **Migration**: First launch after implementation requires Core Data migration
2. **Performance**: Large tag hierarchies (>1000 tags) may experience slowdown
3. **Sync Conflicts**: Complex tag renaming across devices may need manual resolution
4. **Search Scope**: Tag search currently covers name/path only, not content

## 🔧 Troubleshooting

### Common Issues:
1. **Tags not appearing**: Check Core Data migration completed successfully
2. **Sync issues**: Verify CloudKit entitlements include new entities
3. **Performance**: Consider flattening deep tag hierarchies (>5 levels)
4. **Missing features**: Some advanced features planned for future releases

### Debug Tips:
- Enable Core Data debugging: `-com.apple.CoreData.SQLDebug 1`
- Check tag service state: `TagService.shared.selectedTags`
- Verify relationships: Use Core Data debugger in Xcode

## 📝 Implementation Notes

This tag system was designed to be:
- **Non-destructive**: Doesn't interfere with existing group-based organization
- **Progressive**: Users can adopt tags gradually alongside existing workflows
- **Bear-inspired**: Familiar UX for users coming from Bear or similar apps
- **Extensible**: Architecture supports advanced features without breaking changes

The implementation provides a solid foundation for Bear-style note organization while maintaining Notis's existing functionality and design language.