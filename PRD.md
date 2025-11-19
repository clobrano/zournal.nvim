# Product Requirements Document: zournal.nvim

## 1. Overview

**Product Name:** zournal.nvim
**Version:** 1.0
**Language:** Lua (native Neovim)
**Target Users:** Neovim users who practice journaling and Zettelkasten-style note-taking

### Purpose
zournal.nvim is a Neovim plugin that combines journaling capabilities with Zettelkasten note-taking methodology, enabling users to maintain temporal journals (daily/weekly/monthly) and interconnected knowledge notes with line-level referencing.

## 2. Core Features

### 2.1 Journal Management

#### Daily Journals
- Command: `:ZournalDailyJournal`
- Opens or creates today's daily journal entry
- Default filename: `YYYY-MM-DD.md` (configurable)
- Uses configurable template file

#### Weekly Journals
- Command: `:ZournalWeeklyJournal`
- Opens or creates current week's journal
- Default filename: `YYYY-MM-DD-Wxx.md` (configurable)
- Uses ISO week numbering
- Uses configurable template file

#### Monthly Journals
- Command: `:ZournalMonthlyJournal`
- Opens or creates current month's journal
- Default filename: `YYYY-MM.md` (configurable)
- Uses configurable template file

#### Inbox Notes
- Command: `:ZournalInbox`
- Creates quick capture note for inbox processing
- Prompts user for filename/title
- Stores in configurable directory (default: `Resources/`)
- Uses configurable template file

### 2.2 Zettelkasten System

#### Zettelkasten ID (zid) Structure
- Format: Alternating number/character sequence
- Examples: `1a`, `1b`, `1a3`, `1b3c5a100z`
- Pattern: `number → character → number → character → ...`
- Grows dynamically as needed

#### Relationships
- **Siblings**: Share same parent prefix, different last character
  - Example: `1a` and `1b` are siblings, `1a2` is sibling of `1a3`
- **Parent/Child**: Child ID extends parent ID
  - Example: `1a` is parent of `1a3`, which is parent of `1a3c`
- **Root notes**: Single number (e.g., `1`, `2`, `3`)

#### Storage
- zid stored in YAML frontmatter
- Frontmatter is **optional** - plugin must support files with or without frontmatter
- Default frontmatter includes:
  - `zid`: The Zettelkasten ID
  - `created`: Just the creation date `YYYY-MM-DD`
- Example:
  ```yaml
  ---
  created: 2025-01-16
  zid: 1a3
  ---
  ```

#### Zettelkasten Commands

**Create Child Note**
- Command: `:ZournalNewChild`
- Prompts user for filename/title
- Automatically generates next child zid
- Creates file with frontmatter containing new zid
- Example: From note with zid `1a`, creates `1a1`, `1a2`, etc.
- If executed when some text is selected, it moves the selected text into the new file. The removed text in the original file is replaced with the wiki link (`[[ ... ]]`) of the new file

**Create Sibling Note**
- Command: `:ZournalNewSibling`
- Prompts user for filename/title
- Automatically generates next sibling zid
- Creates file with frontmatter containing new zid
- Example: From note with zid `1a`, creates `1b`, `1c`, etc.
- If executed when some text is selected, it moves the selected text into the new file. The removed text in the original file is replaced with the wiki link (`[[ ... ]]`) of the new file

**Add Parent Relationship**
- Command: `:ZournalAddParent`
- Links current note to an existing parent in the hierarchy
- Implementation details TBD

**Root Note Creation**
- No special command - users create files manually using standard Neovim features
- Users manually assign root zids (1, 2, 3, etc.) in frontmatter

#### Zettelkasten Navigation

**Relationship Telescope Picker**
- Command: `:ZournalRelations` (or similar)
- Shows Telescope picker with:
  - Parent note (if any)
  - All sibling notes
  - All child notes
- Display format for each item:
  - Relationship type label (Parent/Sibling/Child)
  - Filename/title
  - First line preview of content

**Jump to Date**
- Command: `:ZournalJumpToDate`
- Accepts date argument (e.g., `:ZournalJumpToDate 2025-01-15`)
- Opens the journal entry for specified date
- Works for daily, weekly, or monthly journals

**Link Navigation**
- Telescope picker to show all links in current note
- User selects link to follow to target file
- Supports both WikiLinks `[[note]]` and Markdown links `[title](path.md)`

#### Error Handling for Missing zid
- When Zettelkasten commands are used on files without zid in frontmatter:
  - Show helpful error message
  - Explain that zid is required for this operation
  - Do not silently fail

### 2.3 Line-Level Tagging and Referencing

#### Tag Format
- Tags are UUIDs (e.g., generated via `uuidgen`)
- Two types of tags:
  - **Original tags**: `{ztag<uuid>}` - created when tagging a line
  - **Reference tags**: `{zref<uuid>}` - copied from original tags to reference them elsewhere
- Example: `This is an important insight {ztaga3f9b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c}`
- NOTE: Uses curly braces `{}` instead of hash `#` to distinguish from standard Neovim tags

#### Tag Concealment
- **Original tags** (`{ztag<uuid>}`):
  - Concealed and displayed as: `📌` (configurable via `tag_symbol`)
  - Indicates the source/original location
- **Reference tags** (`{zref<uuid>}`):
  - Concealed and displayed as: `→` (configurable via `reference_symbol`)
  - Same UUID as original, different prefix and display
  - Arrow symbol indicates this is a reference to a tag elsewhere

#### Line Tagging Commands

**Add Tag to Current Line**
- Command: `:ZournalTagAdd`
- Generates new UUID
- Appends `{ztag<uuid>}` to end of current line
- Tag is automatically concealed as 📌

**Copy Tag Reference**
- Command: `:ZournalTagCopy`
- Extracts UUID from tag on current line (works with both `{ztag}` and `{zref}`)
- Copies `{zref<uuid>}` to clipboard
- Paste in another file to create a reference
- When pasted, reference is concealed as →

**Show Tag References**
- Command: `:ZournalTagReferences`
- Shows all occurrences of the tag UUID on current line
- Displays in Telescope picker with:
  - Original tag listed first
  - All references listed after
  - Format: `[Original/Reference] filename:line - line content`
- Pressing Enter jumps to selected occurrence
- Note: Required because curly-brace format (`{ztag}` vs `{zref}`) is not compatible with Neovim's native tag navigation system

#### Tag Metadata
- **No bidirectional tracking stored in files**
- Only the UUID tag itself is stored
- Reference tracking done via search/grep at runtime

### 2.4 Linking System

#### Supported Link Types
- **WikiLinks**: `[[note-title]]` or `[[note-title.md]]`
- **Markdown links**: `[Display Text](path/to/note.md)`

#### Link Resolution
- Links resolved by existing Neovim markdown plugins (user's choice)
- Plugin provides Telescope integration for link navigation
- Bidirectional linking managed via software, not stored in files

#### Automatic Link Renaming
- **Trigger**: Automatic on file rename operations
- **Behavior**: When a file is renamed, automatically update all WikiLinks and Markdown links across all journal/note files
- **Scope**: Search entire journal directory for references to old filename
- **Implementation**: Hook into file rename events, find and replace all occurrences

## 3. Configuration

### 3.1 Configurable Settings

```lua
require('zournal').setup({
  -- Root directory for all journals and notes
  root_dir = "~/journal/",

  -- File naming conventions
  daily_format = "%Y-%m-%d.md",
  weekly_format = "%Y-W%V.md",
  monthly_format = "%Y-%m.md",

  -- Template file paths
  templates = {
    daily = "~/.config/nvim/templates/daily.md",
    weekly = "~/.config/nvim/templates/weekly.md",
    monthly = "~/.config/nvim/templates/monthly.md",
    inbox = "~/.config/nvim/templates/inbox.md",
  },

  -- Inbox configuration
  inbox_dir = "Resources/",  -- relative to root_dir

  -- Concealment symbols
  tag_symbol = "📌",          -- Display for original tags
  reference_symbol = "→📌",   -- Display for reference tags
})
```

### 3.2 Non-Configurable Defaults
- Directory structure: Flat (all files in root_dir)
- Week numbering: ISO standard (week starts Monday)
- Keybindings: Not provided by default (user-configured)
- Frontmatter: Optional, plugin supports files with or without

## 4. Technical Architecture

### 4.1 Dependencies
- **Telescope**: Fuzzy finding, note/link pickers
- **Plenary**: Lua utility functions (path handling, async)
- **Treesitter**: Parsing and syntax support (for links, tags)

### 4.2 Plugin Structure
```
zournal.nvim/
├── lua/
│   └── zournal/
│       ├── init.lua           # Main setup and config
│       ├── journal.lua        # Daily/weekly/monthly journal commands
│       ├── zettelkasten.lua   # Zid system, child/sibling/parent logic
│       ├── tags.lua           # Line tagging and UUID management
│       ├── links.lua          # Link parsing and renaming
│       ├── telescope/         # Telescope integrations
│       │   ├── relations.lua  # Zettelkasten relationship picker
│       │   ├── links.lua      # Link navigation picker
│       │   └── references.lua # Tag reference picker
│       └── utils.lua          # Helper functions
├── plugin/
│   └── zournal.vim            # Command definitions
└── README.md
```

### 4.3 File Operations
- All file operations use Plenary for cross-platform compatibility
- Journal files created with templates on first access
- Zettelkasten files created with minimal frontmatter + template content

## 5. User Experience

### 5.1 Typical Workflows

#### Morning Journaling
1. Open Neovim
2. Run `:ZournalDailyJournal`
3. Template loads with prompts/structure
4. User writes journal entry
5. References other notes via WikiLinks `[[note-name]]`
6. Tags important lines with `:ZournalTagLine` for future reference

#### Creating Knowledge Notes
1. Working in existing Zettelkasten note (e.g., `productivity-systems.md` with zid `1a`)
2. Want to add detailed note about specific technique
3. Run `:ZournalNewChild`
4. Enter title: `pomodoro-technique.md`
5. Plugin creates file with zid `1a1` in frontmatter
6. User writes content, linking back to parent with `[[productivity-systems]]`

#### Navigating Note Hierarchy
1. In any Zettelkasten note
2. Run `:ZournalRelations`
3. Telescope shows parent, siblings, and children
4. Select a note to jump to it

#### Referencing Specific Insights
1. Reading through old journal entry
2. Find important insight on line 45
3. Run `:ZournalTagAdd` - line gets UUID tag (concealed as `📌`)
4. Later, in different note, want to reference that insight
5. Navigate back to original line, run `:ZournalTagCopy`
6. Paste in new note - displays as `→` (reference symbol)
7. Can click/follow reference back to original context

### 5.2 Keybindings
- Plugin does NOT provide default keybindings
- Users configure their own mappings in their Neovim config
- Example user configuration:
  ```lua
  vim.keymap.set('n', '<leader>zd', ':ZournalDailyJournal<CR>')
  vim.keymap.set('n', '<leader>zw', ':ZournalWeeklyJournal<CR>')
  vim.keymap.set('n', '<leader>zm', ':ZournalMonthlyJournal<CR>')
  vim.keymap.set('n', '<leader>zi', ':ZournalInbox<CR>')
  vim.keymap.set('n', '<leader>zc', ':ZournalNewChild<CR>')
  vim.keymap.set('n', '<leader>zs', ':ZournalNewSibling<CR>')
  vim.keymap.set('n', '<leader>zR', ':ZournalRelations<CR>')
  vim.keymap.set('n', '<leader>zt', ':ZournalTagAdd<CR>')
  vim.keymap.set('n', '<leader>zy', ':ZournalTagCopy<CR>')
  vim.keymap.set('n', '<leader>zT', ':ZournalTagReferences<CR>')
  ```

## 6. Future Considerations

### Phase 2 Features (Not in v1.0)
- Graph view of linked notes: NO
- Export functionality (PDF, HTML): NO
- Calendar picker for journal navigation
- Advanced Telescope integration for custom queries
- Treesitter-based syntax highlighting for zid frontmatter
- Auto-completion for WikiLinks based on existing notes: NO

### Potential Enhancements
- Support for daily review prompts from templates: NO
- Zettelkasten statistics (note counts, orphaned notes, etc.)
- Integration with other note-taking plugins
- Custom concealment characters per-user preference
- Backup/sync integration: NO

## 7. Success Metrics

### Must Have (v1.0)
- All journal commands functional (daily, weekly, monthly, inbox)
- All Zettelkasten commands functional (child, sibling, parent)
- All tagging commands functional (tag, copy, show references)
- Line tags properly concealed with distinct symbols for originals vs references
- Telescope relationship picker shows parent/sibling/child notes
- Automatic link renaming on file rename
- Configuration options respected
- Plugin works with or without frontmatter

### Quality Standards
- No errors when frontmatter is missing
- Helpful error messages guide users
- Fast performance even with 1000+ notes
- No data loss during file operations
- Proper handling of edge cases (invalid zids, missing files, etc.)

## 8. Open Questions / TBD

1. **ZournalAddParent implementation**: What should this command do exactly? Modify frontmatter? Create backlink? This will prompt for the parent filename, once found the file, if it has the zid, will generate the child zid and add to the current file's frontmatter
2. **Tag reference tracking**: Should `:ZournalShowReferences` use an index file or grep through all files? See my note in ZournalShowReferences section above (tl;dr: we won't implement this function)
3. **Template format**: Should templates support variables (e.g., `{{date}}`, `{{title}}`)? Yes
4. **Link renaming scope**: Should it also update non-journal files, or only files in `root_dir`? YES
5. **Telescope preview**: Should relationship picker show full preview pane or just one-line preview? Full preview
6. **Child/sibling numbering**: Should it skip gaps (e.g., if 1a1 and 1a3 exist, create 1a2 or 1a4)? YES

---

**Document Status:** Draft
**Last Updated:** 2025-01-16
**Next Steps:** Review and finalize open questions, begin implementation planning
