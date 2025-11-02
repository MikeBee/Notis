# Notis - Remaining Implementation Tasks

## **HIGH PRIORITY - Critical Missing Features**

### 1. **MarkdownTextEditor - Missing Core Features**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Views/MarkdownTextEditor.swift`
- **Typewriter Mode**: Cursor stays centered while typing
- **Focus Mode**: Dim inactive paragraphs 
- **Markdown Syntax Highlighting**: Currently just plain text
- These are core features for a Ulysses-style app

### 2. **Library Essentials - Non-Functional Sections**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Views/LibraryEssentialsSection.swift`
- **"Open Files"**: Hardcoded to show 0 count (lines 65-69)
- **"Inbox"**: Hardcoded to show 0 count (lines 104-106)
- **"My Projects"**: Hardcoded to show 0 count (lines 114-116)
- These appear in the sidebar but don't work

### 3. **Production-Unsafe Error Handling**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Persistence.swift`
- `fatalError()` calls in Persistence.swift that crash the app (lines 73, 88, 98)
- Should be replaced with proper error handling
- Comment: "You should not use this function in a shipping application"

## **MEDIUM PRIORITY - UX Improvements**

### 5. **Hover Effects Placeholders**
**Files:** Multiple files have placeholder hover effects
- `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Views/LibrarySidebar.swift` (line 44)
- `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Views/NavigationBar.swift` (line 114)
- Empty hover handlers with comments indicating need for implementation

### 6. **Dashboard Navigation**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Views/NavigationBar.swift`
- Dashboard types defined but switching between them doesn't work properly (lines 157-161)
- Missing proper navigation between different dashboard views

## **LOW PRIORITY - Polish**

### 7. **Hardcoded Configuration Values**
- Reading speed: 200 words/min (should be user setting)
- Writing speed: 40 words/min (should be user setting)  
- Pages calculation: 250 words/page (should be configurable)

### 8. **Advanced Search Features**
- Current search is basic title/content only
- Missing filters, advanced queries, search history
- No full-text indexing

### 9. **Menu Integration**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/ContentView.swift`
- Uses notifications instead of proper macOS menu integration
- Command palette works but no native menu shortcuts

### 10. **Export Service UI Integration**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Services/ExportService.swift`
- Export service works but needs better UI integration
- Missing progress indicators, better error handling

## **TECHNICAL DEBT**

### 11. **Core Data Model Limitations**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Notis.xcdatamodeld/Notis.xcdatamodel/contents`
- Basic model may need expansion for advanced features
- Missing: Versioning, attachments, tags, advanced metadata

### 12. **Theme System Incomplete**
**File:** `/Volumes/Mini-Ext/mini-external/Development/Notis/Notis/Design/UlyssesDesign.swift`
- Design system is comprehensive but some color values may need refinement
- Missing: Dynamic color adaptation, accessibility support

### 13. **Goal Tracking System**
- Goal progress tracking is implemented but limited
- Missing: Goal templates, historical tracking, achievement system

### 14. **Import/Export Limitations** 
- JSON import/export works but limited format support
- Missing: Multiple markdown files, RTF, DOCX support

## **COMPLETION PRIORITY RECOMMENDATIONS**

1. **Immediate Priority:** Implement typewriter and focus modes in MarkdownTextEditor
2. **Quick Wins:** Implement hover effects and fix library essentials functionality  
3. **Production Ready:** Replace fatalError calls with proper error handling
4. **User Experience:** Add native menu integration
5. **Future Enhancement:** Expand search capabilities and goal tracking system