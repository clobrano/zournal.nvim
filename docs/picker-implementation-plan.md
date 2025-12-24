# Picker Abstraction Implementation Plan

## Overview

Detailed task breakdown for implementing the picker abstraction layer to support both Telescope and FzfLua.

## Phase 1: Foundation (Non-Breaking)

**Goal:** Create abstraction layer without breaking existing functionality

**Estimated Time:** 2-3 hours

### Task 1.1: Create Base Picker Module

**File:** `lua/zournal/picker.lua`

```lua
-- Core abstraction that detects and routes to appropriate backend
```

**Deliverables:**
- [x] Backend detection logic
- [x] Configuration parsing
- [x] Unified `show()` interface
- [x] Error handling for missing backends

**Test Cases:**
- Backend auto-detection with only Telescope installed
- Backend auto-detection with only FzfLua installed
- Backend auto-detection with both installed
- Error when neither is installed
- Explicit backend selection via config

### Task 1.2: Implement Telescope Adapter

**File:** `lua/zournal/picker/telescope_adapter.lua`

**Deliverables:**
- [x] Convert unified config to Telescope API calls
- [x] Entry maker transformation
- [x] Preview configuration (file and custom)
- [x] Action handler mapping
- [x] Error handling

**Test Cases:**
- Simple list with no preview
- List with file preview
- List with custom preview
- Selection action triggers correctly
- Multi-selection works

### Task 1.3: Implement FzfLua Adapter

**File:** `lua/zournal/picker/fzflua_adapter.lua`

**Deliverables:**
- [x] Convert unified config to FzfLua API calls
- [x] String transformation for entries
- [x] Display → item mapping
- [x] Preview configuration (file and custom)
- [x] Action handler mapping

**Test Cases:**
- Simple list with no preview
- List with file preview
- List with custom preview
- Selection action triggers correctly
- Multi-selection works

### Task 1.4: Update Configuration

**File:** `lua/zournal/config.lua`

**Changes:**
```lua
-- Add to default config
picker_backend = 'auto',  -- 'auto', 'telescope', or 'fzflua'
```

**Deliverables:**
- [x] Add picker_backend option
- [x] Validation logic
- [x] Documentation in code comments

## Phase 2: Proof of Concept Migration

**Goal:** Migrate one picker to validate design

**Estimated Time:** 1 hour

### Task 2.1: Migrate Links Picker

**Current:** `lua/zournal/telescope/links.lua`
**New:** `lua/zournal/pickers/links.lua`

**Changes:**
1. Replace Telescope API calls with `picker.show()`
2. Convert to unified config format
3. Update command registration
4. Keep backward compatibility

**Before:**
```lua
pickers.new({}, {
  prompt_title = "Links in Current File",
  finder = finders.new_table({ ... }),
  -- ... telescope-specific code
}):find()
```

**After:**
```lua
require('zournal.picker').show({
  title = "Links in Current File",
  items = entries,
  on_select = function(item) ... end,
  preview = {
    type = 'file',
    get_file = function(item) return item.filepath end,
  },
})
```

**Test Plan:**
- Test with Telescope backend
- Test with FzfLua backend
- Verify file preview works
- Verify broken link detection works
- Verify selection opens correct file

### Task 2.2: Update Command Registration

**File:** `plugin/zournal.vim`

**Before:**
```vim
command! ZournalLinks lua require('zournal.telescope.links').pick_links()
```

**After:**
```vim
command! ZournalLinks lua require('zournal.pickers.links').pick_links()
```

**Test:**
- Run `:ZournalLinks` with Telescope
- Run `:ZournalLinks` with FzfLua
- Verify no errors

### Task 2.3: Gather Feedback

**Activities:**
- Create test cases document
- Test with real zournal workspace
- Document any issues found
- Refine abstraction based on findings

## Phase 3: Complete Migration

**Goal:** Migrate remaining pickers

**Estimated Time:** 2-3 hours

### Task 3.1: Migrate Relations Picker

**Current:** `lua/zournal/telescope/relations.lua`
**New:** `lua/zournal/pickers/relations.lua`

**Complexity:** Low (similar to links)

**Unique Features:**
- Grouped display ([Parent], [Sibling], [Child])
- First-line preview

**Deliverables:**
- [x] Converted to use picker abstraction
- [x] Tests pass with both backends
- [x] Updated command registration

### Task 3.2: Migrate Tag References Picker

**Current:** `lua/zournal/telescope/tag_references.lua`
**New:** `lua/zournal/pickers/tag_references.lua`

**Complexity:** Medium (has line number jumping)

**Unique Features:**
- Jump to specific line number
- Show line numbers in display
- Preview with line highlighting (via `bat`)

**Special Considerations:**
- FzfLua preview needs `bat` for line highlighting
- Fallback if `bat` not installed

**Deliverables:**
- [x] Converted to use picker abstraction
- [x] Line highlighting works with both backends
- [x] Graceful fallback without `bat`
- [x] Tests pass with both backends

### Task 3.3: Migrate Calendar Picker

**Current:** `lua/zournal/telescope/calendar.lua`
**New:** `lua/zournal/pickers/calendar.lua`

**Complexity:** Medium (custom preview logic)

**Unique Features:**
- Date formatting in display
- Status indicators ([Daily/Weekly/Monthly] or [New])
- Custom preview showing file OR placeholder message
- Search by date or day name

**Custom Preview Challenge:**
```lua
-- Need to support both:
-- 1. File preview (if journal exists)
-- 2. Custom message (if no journal)
```

**Solution:**
```lua
preview = {
  type = 'custom',
  render = function(item, bufnr)
    if item.filename and file_exists(item.filename) then
      -- Show file content
    else
      -- Show "no entry" message
    end
  end,
}
```

**Deliverables:**
- [x] Converted to use picker abstraction
- [x] Custom preview works with both backends
- [x] Date search works
- [x] Tests pass with both backends

### Task 3.4: Update All Command Registrations

**File:** `plugin/zournal.vim`

**Changes:**
```vim
" Before
command! ZournalRelations lua require('zournal.telescope.relations').pick_relations()
command! ZournalLinks lua require('zournal.telescope.links').pick_links()
command! ZournalCalendar lua require('zournal.telescope.calendar').show_calendar()
command! ZournalTagReferences lua require('zournal.telescope.tag_references').pick_tag_references()

" After
command! ZournalRelations lua require('zournal.pickers.relations').pick_relations()
command! ZournalLinks lua require('zournal.pickers.links').pick_links()
command! ZournalCalendar lua require('zournal.pickers.calendar').show_calendar()
command! ZournalTagReferences lua require('zournal.pickers.tag_references').pick_tag_references()
```

## Phase 4: Cleanup and Documentation

**Goal:** Remove old code and update docs

**Estimated Time:** 1 hour

### Task 4.1: Remove Old Telescope Directory

**Actions:**
- Delete `lua/zournal/telescope/` directory
- Verify no other code references it
- Update git history (or keep for reference)

**Deliverables:**
- [x] Old code removed
- [x] No broken imports
- [x] Tests still pass

### Task 4.2: Update README.md

**Sections to Update:**

**Installation section:**
```lua
-- Before
{
  "your-username/zournal.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",  -- Required
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}

-- After
{
  "your-username/zournal.nvim",
  dependencies = {
    -- Choose ONE of these pickers:
    "nvim-telescope/telescope.nvim",  -- Option 1: Telescope
    -- OR
    "ibhagwan/fzf-lua",              -- Option 2: FzfLua

    -- Required:
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}
```

**Configuration section:**
Add picker backend configuration:
```lua
require('zournal').setup({
  picker_backend = 'auto',  -- 'auto', 'telescope', or 'fzflua'
  workspaces = {
    -- ...
  },
})
```

**Dependencies section:**
Update to show Telescope/FzfLua as alternatives

**Deliverables:**
- [x] README updated with new dependency info
- [x] Configuration examples added
- [x] Migration guide for existing users (if needed)

### Task 4.3: Create Migration Guide (if needed)

**File:** `docs/MIGRATION-v3.md`

**Content:**
- Explain the change
- Show before/after config
- Clarify that existing Telescope users are unaffected
- Show how to switch to FzfLua
- Troubleshooting section

**Deliverables:**
- [x] Migration guide written
- [x] Common issues documented
- [x] Linked from main README

### Task 4.4: Update init.lua

**File:** `lua/zournal/init.lua`

**Before:**
```lua
M.telescope = {
  relations = require('zournal.telescope.relations'),
  links = require('zournal.telescope.links'),
}
```

**After:**
```lua
M.pickers = {
  relations = require('zournal.pickers.relations'),
  links = require('zournal.pickers.links'),
  tag_references = require('zournal.pickers.tag_references'),
  calendar = require('zournal.pickers.calendar'),
}
```

**Considerations:**
- Decide if we need lazy-loading (probably not, picker detection is cheap)
- Keep backward compatibility? (probably not necessary)

**Deliverables:**
- [x] init.lua updated
- [x] Exports are correct
- [x] No breaking changes for documented APIs

## Phase 5: Testing and Polish

**Goal:** Comprehensive testing and bug fixes

**Estimated Time:** 1-2 hours

### Task 5.1: Create Test Suite

**File:** `tests/picker_spec.lua` (if using test framework)

**Test Cases:**

**Backend Detection:**
- [x] Auto-detect Telescope when only it is installed
- [x] Auto-detect FzfLua when only it is installed
- [x] Prefer Telescope when both installed (with 'auto')
- [x] Error when neither installed
- [x] Respect explicit backend config

**Adapter Tests - Telescope:**
- [x] Simple list display
- [x] File preview
- [x] Custom preview
- [x] Selection callback
- [x] Multi-selection
- [x] Line number jump

**Adapter Tests - FzfLua:**
- [x] Simple list display
- [x] File preview
- [x] Custom preview
- [x] Selection callback
- [x] Multi-selection
- [x] Line number jump

**Integration Tests:**
- [x] Relations picker works end-to-end
- [x] Links picker works end-to-end
- [x] Tag references picker works end-to-end
- [x] Calendar picker works end-to-end

### Task 5.2: Manual Testing Checklist

**Environment Setup:**
- [ ] Test with only Telescope installed
- [ ] Test with only FzfLua installed
- [ ] Test with both installed
- [ ] Test with neither installed (should error gracefully)

**Feature Testing:**
- [ ] `:ZournalRelations` - Browse related notes
- [ ] `:ZournalLinks` - Browse links, open files
- [ ] `:ZournalTagReferences` - Find tag occurrences, jump to line
- [ ] `:ZournalCalendar` - Browse dates, create journals
- [ ] All previews render correctly
- [ ] All selections open correct files
- [ ] Line jumps work correctly
- [ ] Fuzzy search works
- [ ] Multi-select works (if used)

**Configuration Testing:**
- [ ] `picker_backend = 'auto'` works
- [ ] `picker_backend = 'telescope'` works (errors if not installed)
- [ ] `picker_backend = 'fzflua'` works (errors if not installed)
- [ ] Invalid backend config shows helpful error

### Task 5.3: Performance Testing

**Benchmarks:**
- [ ] Measure startup time for each picker
- [ ] Test with large datasets (100+ notes)
- [ ] Test with 1000+ notes (stress test)
- [ ] Compare Telescope vs FzfLua performance
- [ ] Document results

**Tool:** Use `vim.loop.hrtime()` for microsecond precision

### Task 5.4: Bug Fixes and Polish

**Activities:**
- Fix any bugs found during testing
- Improve error messages
- Add helpful warnings
- Optimize performance if needed
- Code cleanup and formatting

## Phase 6: Release

**Goal:** Prepare for release and user rollout

**Estimated Time:** 30 minutes

### Task 6.1: Update Changelog

**File:** `CHANGELOG.md`

**Content:**
```markdown
## [3.0.0] - 2025-XX-XX

### Changed
- **BREAKING (soft):** Telescope is now an optional dependency
- Pickers now support both Telescope and FzfLua backends
- Add `picker_backend` configuration option

### Added
- FzfLua support as alternative picker backend
- Picker abstraction layer for future extensibility
- Auto-detection of available picker backends

### Migration
- Existing users: No changes required (Telescope still works)
- New users: Can choose Telescope or FzfLua
- See docs/picker-configuration.md for details
```

### Task 6.2: Version Bump

**File:** Update version in relevant files (if applicable)

### Task 6.3: Create Release PR/Commit

**Commit Message:**
```
feat: add picker abstraction layer with FzfLua support

- Make Telescope optional dependency
- Add FzfLua as alternative picker backend
- Implement picker abstraction layer
- Migrate all four pickers (relations, links, tag_references, calendar)
- Add configuration: picker_backend = 'auto' | 'telescope' | 'fzflua'
- Update documentation and README

BREAKING CHANGE: Telescope is no longer a hard dependency.
Users can now choose between Telescope or FzfLua as picker backend.
Existing Telescope users are unaffected (auto-detected).
```

### Task 6.4: User Communication

**Actions:**
- Update README
- Post in discussions (if using GitHub Discussions)
- Update any related issues
- Announce in relevant communities (if applicable)

## Risk Assessment

### High Risk Items
None - migration is backward compatible

### Medium Risk Items
1. **Custom preview rendering** - Different between backends
   - Mitigation: Extensive testing, fallbacks
2. **User configuration** - May need to update
   - Mitigation: Auto-detection by default

### Low Risk Items
1. **Performance differences** - FzfLua may behave differently
   - Mitigation: Document differences
2. **Missing external tools** - `bat` for line highlighting
   - Mitigation: Graceful fallback

## Success Criteria

- [x] All four pickers work with Telescope backend
- [x] All four pickers work with FzfLua backend
- [x] Zero breaking changes for existing Telescope users
- [x] Configuration is simple and intuitive
- [x] Error messages are helpful
- [x] Documentation is complete and accurate
- [x] Tests pass for both backends

## Timeline Estimate

| Phase | Estimated Time | Dependencies |
|-------|----------------|--------------|
| Phase 1: Foundation | 2-3 hours | None |
| Phase 2: Proof of Concept | 1 hour | Phase 1 |
| Phase 3: Complete Migration | 2-3 hours | Phase 2 |
| Phase 4: Cleanup & Docs | 1 hour | Phase 3 |
| Phase 5: Testing | 1-2 hours | Phase 4 |
| Phase 6: Release | 30 min | Phase 5 |
| **Total** | **7-10 hours** | - |

## Rollback Plan

If issues are discovered post-release:

1. **Option 1:** Quick fix and patch release
2. **Option 2:** Revert to Telescope-only temporarily
3. **Option 3:** Disable FzfLua backend, mark as experimental

**Rollback Command:**
```bash
git revert <commit-hash>
git push origin main --force-with-lease
```

## Future Enhancements

Post-release improvements (not in scope for initial implementation):

1. **More picker backends** - mini.pick, fzy, etc.
2. **Backend-specific options** - Allow customization per backend
3. **Performance optimizations** - Lazy loading, caching
4. **Additional preview types** - Image preview, syntax highlighting
5. **Custom themes** - Per-backend theming support

## Notes

- Keep PRD.md and other docs updated throughout
- Consider creating video demo of both backends
- Tag issue tracker items with `picker-abstraction` label
- Consider feature flag for gradual rollout if desired
