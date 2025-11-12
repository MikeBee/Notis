# Migration Guide: CoreData to Hybrid Storage System

## Overview

This guide covers migrating from the legacy CoreData-only storage system to the new hybrid system that uses markdown files with YAML frontmatter and SQLite indexing for optimal performance and data portability.

## Migration Strategy

The app uses a **safe, gradual migration approach** that preserves all existing data while modernizing the storage system. No data is lost, and users can continue working immediately after the update.

## Pre-Migration Checklist

### ⚠️ **CRITICAL: Backup First**
1. **Export existing data** using Settings > Export Data
2. **Save the backup file** in a secure location
3. **Verify backup integrity** by checking the exported JSON contains all sheets

This backup can restore your entire library if anything goes wrong.

## Migration Process

### Phase 1: Initial Deployment
- Install the new app version
- **All existing sheets remain in CoreData** and work normally
- **New sheets automatically use the file system**
- Users experience no disruption

### Phase 2: Gradual Migration (Automatic)
Migration occurs **only when sheets are edited**:

```
Edit existing sheet → Triggers migration → Creates markdown file → Updates index
```

**What happens during migration:**
1. ✅ Content saved to markdown file with YAML frontmatter
2. ✅ Metadata preserved (title, tags, goals, dates, progress)
3. ✅ Entry added to SQLite search index
4. ✅ File path stored in CoreData
5. ✅ Old content field cleared (saves space)

**Migration triggers:**
- ✅ Editing sheet content
- ✅ Changing sheet title
- ✅ Updating tags or metadata

**Protected from migration:**
- 🚫 Sheets in trash (remain in CoreData)
- 🚫 Empty/whitespace-only sheets (remain in CoreData)
- 🚫 Read-only operations (no migration triggered)

### Phase 3: Monitoring and Verification

Use the **Database Maintenance tool** to:
- Monitor migration progress
- Identify any issues
- Run health checks
- Fix inconsistencies automatically

## Technical Details

### Storage Architecture

**Before Migration:**
```
Sheet.content → CoreData only
```

**After Migration:**
```
Sheet.unifiedContent → {
  if (has markdown file) return file content
  else return CoreData content
}
```

**New Sheets:**
```
Sheet.unifiedContent → Always uses markdown files
```

### File Structure
```
~/Application Support/Notis/
├── Notes/
│   ├── folder1/
│   │   └── my-sheet.md        # Markdown content
│   └── my-root-sheet.md       # Root-level sheets
└── notes_index.db             # SQLite search index
```

### Markdown File Format
```yaml
---
uuid: "ABC123-456-789"
title: "My Sheet Title"
tags: ["tag1", "tag2"]
created: "2024-11-12T10:30:00Z"
modified: "2024-11-12T15:45:00Z"
progress: 0.75
status: "draft"
---

# My Sheet Content

This is the actual markdown content...
```

## Safety Features

### 1. **Fallback Protection**
```swift
// If file migration fails → Falls back to CoreData
// No data is ever lost
```

### 2. **Content Validation**
```swift
// Empty sheets stay in CoreData (no migration)
// Only sheets with actual content migrate
```

### 3. **Trash Protection**
```swift
// Trashed sheets never migrate
// Prevents file system pollution
```

### 4. **Atomic Operations**
```swift
// Old content only cleared AFTER successful file creation
// No data loss during migration
```

## Expected Timeline

| Phase | Duration | User Experience |
|-------|----------|-----------------|
| **Day 1** | Immediate | All sheets work normally (CoreData) |
| **Week 1-2** | Gradual | Frequently edited sheets migrate |
| **Month 1** | Majority | Most active content migrated |
| **Ongoing** | Forever | Mixed storage, seamless experience |

## Monitoring Migration Progress

### Database Health Check
Navigate to Settings > Database Maintenance to:

1. **View migration status**
   - See which sheets have migrated
   - Identify any issues
   - Monitor storage usage

2. **Run health diagnostics**
   - Word count validation
   - Preview synchronization
   - Index consistency

3. **Auto-fix issues**
   - Repair inconsistencies
   - Update metadata
   - Rebuild search index

### Health Check Examples
```
✅ "Sheet 'Meeting Notes' successfully migrated to file storage"
⚠️ "Sheet 'Draft Ideas' has preview mismatch (auto-fixable)"
ℹ️ "Sheet 'Quick Note' is ungrouped (will be placed in Inbox)"
```

## Troubleshooting

### Common Issues

**Issue: "Preview mismatch" errors**
- **Cause:** Inconsistent preview calculation
- **Fix:** Run auto-fix in Database Maintenance
- **Status:** Fixed in latest version

**Issue: "Word count mismatch" errors**
- **Cause:** Different content sources for validation
- **Fix:** Run auto-fix to recalculate from unified content
- **Status:** Fixed in latest version

**Issue: "No group assignment" warnings**
- **Cause:** Sheets in Inbox treated as orphaned
- **Fix:** Auto-assigns to Inbox group (low priority)
- **Status:** Now marked as informational only

**Issue: Statistics showing zero**
- **Cause:** Progress pane reading from empty CoreData field
- **Fix:** Updated to use unified content
- **Status:** Fixed in latest version

### Emergency Procedures

**If migration fails:**
1. **Don't panic** - original data is preserved
2. **Check Database Maintenance** for specific error
3. **Use auto-fix** for most issues
4. **Restore from backup** if needed (JSON import)

**If app becomes unusable:**
1. **Force quit** and restart app
2. **Check file permissions** in Application Support
3. **Run full health check** in Database Maintenance
4. **Contact support** with specific error messages

## Verification Steps

### After Deployment
1. ✅ **Test existing sheets** - verify all are readable
2. ✅ **Edit a few sheets** - confirm migration works
3. ✅ **Create new sheet** - ensure uses file system
4. ✅ **Test search** - works across both storage types
5. ✅ **Run health check** - identify any issues
6. ✅ **Verify backup** - export function still works

### Weekly Checks
1. **Monitor health report** for new issues
2. **Check migration progress** (how many migrated)
3. **Verify search index** is up to date
4. **Test performance** - should improve over time

## Benefits After Migration

### Immediate Benefits
- 🚀 **Faster search** via SQLite FTS5 indexing
- 📁 **File-based storage** for better organization
- 🔍 **External tool integration** (grep, editors, etc.)
- 💾 **Reduced app size** (content moved to files)

### Long-term Benefits
- 📱 **Better sync** between devices
- 🔄 **Improved backup/restore** options
- 🛠️ **Advanced search** capabilities
- 📊 **Analytics and reporting** features

## Technical Support

### Log Files
Migration events are logged with these prefixes:
- `✓` Successful operations
- `❌` Errors requiring attention
- `⊘` Skipped operations (normal)
- `ℹ️` Informational messages

### Debug Information
Include this in support requests:
1. Database Maintenance report
2. Migration timeline (when started)
3. Specific error messages
4. Number of sheets affected

### Contact
For migration issues or questions:
- Use Database Maintenance auto-fix first
- Check this README for common solutions
- Provide specific error messages when reporting issues

---

## File Structure Reference

This migration creates a modern, portable file structure while maintaining full backward compatibility with existing CoreData storage.

**Remember: This is a gradual, safe migration. Your data is protected throughout the process.**