# zournal.nvim

A Neovim plugin for journaling with Zettelkasten-style note-taking capabilities.

> **⚠️ BREAKING CHANGE (v0.3.0)**: Tag format has changed from `#ztag<uuid>` / `#zref<uuid>` to `{ztag<uuid>}` / `{zref<uuid>}`. Using curly braces instead of hash to avoid confusion with standard tags. See [Migration](#migration) for details.

## Features

### Journal Management
- **Daily Journals**: Create date-based daily entries with customizable templates
- **Weekly Journals**: Create weekly entries using ISO week numbering
- **Monthly Journals**: Create monthly entries for broader planning
- **Inbox Notes**: Quick capture notes stored in a configurable directory
- **Jump to Date**: Navigate to any date's journal entry

### Zettelkasten System
- **Hierarchical IDs**: Notes use alternating number/character zids (e.g., `1a`, `1b3c5`)
- **Relationship Navigation**: Create child notes, sibling notes, and parent relationships
- **Gap Filling**: Automatically fills gaps in sequences (prefers `1a2` if `1a1` and `1a3` exist)
- **Extract and Link**: Select text in visual mode to extract it into a new child/sibling note with automatic WikiLink replacement
- **Telescope Integration**: Browse parent, siblings, and children with full preview

### Line Tagging
- **UUID Tags**: Tag lines with unique UUIDs for precise referencing
- **Tag Concealment**: Tags are completely hidden (concealed) with sign column indicators
- **Sign Column**: Shows "Z" in sign column for both original and reference tags
- **Virtual Text**: Optionally display original line content next to reference tags
- **Copy Tags**: Easily copy tags as references to use in other files
- **Distinct Format**: Uses `{}` braces (not `#`) to distinguish from standard Neovim tags

### Link System
- **WikiLinks**: Support for `[[note-title]]` style links
- **Markdown Links**: Support for `[title](path.md)` style links
- **Link Resolution**: Automatically resolves links to files in your journal
- **Link Following**: Navigate to linked notes with `:ZournalFollowLink`
- **Automatic Renaming**: When you rename a file, all links are updated automatically
- **Telescope Link Picker**: Browse all links in current file with preview
- **Broken Link Detection**: Clearly marks broken links in Telescope picker

## Installation

### lazy.nvim

```lua
{
  "your-username/zournal.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require('zournal').setup({
      -- Configuration options (see Configuration section)
    })
  end,
}
```

### packer.nvim

```lua
use {
  'your-username/zournal.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('zournal').setup({
      -- Configuration options
    })
  end
}
```

### vim-plug

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'your-username/zournal.nvim'

" In your init.vim or init.lua:
lua << EOF
require('zournal').setup({
  -- Configuration options
})
EOF
```

## Configuration

### BREAKING CHANGE (Multi-Workspace Support)

**Version 2.0 introduces multi-workspace support and requires configuration changes.**

#### Migration Guide

If you're upgrading from version 1.x, you need to update your configuration:

**Old configuration (1.x):**
```lua
require('zournal').setup({
  root_dir = "~/notes/",
  journal_dir = "Journal/",
  -- ... other options
})
```

**New configuration (2.0+):**
```lua
require('zournal').setup({
  workspaces = {
    personal = {
      root_dir = "~/notes/",
      journal_dir = "Journal/",
      -- ... other options
    },
  },
})
```

The new version **requires** a `workspaces` table. Each workspace is a named configuration that can have its own settings.

### Multi-Workspace Configuration

Here's an example with multiple workspaces:

```lua
require('zournal').setup({
  workspaces = {
    personal = {
      root_dir = "~/notes/",
      journal_dir = "Journal/",
      daily_format = "%Y-%m-%d.md",
      weekly_format = "%Y-W%W.md",
      monthly_format = "%Y-%m.md",
      inbox_dir = "Resources/",
      tag_symbol = "📌",
      reference_symbol = "→📌",
    },
    work = {
      root_dir = "~/work-notes/",
      journal_dir = "work-journal/",
      daily_format = "%Y-%m-%d.md",
      weekly_format = "%Y-W%W.md",
      monthly_format = "%Y-%m.md",
      inbox_dir = "Inbox/",
      tag_symbol = "📌",
      reference_symbol = "→📌",
    },
  },
})
```

### Workspace Options

Each workspace supports the following options:

| Option | Default | Description |
|--------|---------|-------------|
| `root_dir` | **required** | Root directory for Zettelkasten notes |
| `journal_dir` | `"Journal/"` | Directory for daily/weekly/monthly journals (absolute or relative to `root_dir`) |
| `daily_format` | `"%Y-%m-%d.md"` | Filename format for daily journals (strftime pattern) |
| `weekly_format` | `"%Y-W%W.md"` | Filename format for weekly journals (strftime pattern) |
| `monthly_format` | `"%Y-%m.md"` | Filename format for monthly journals (strftime pattern) |
| `daily_template` | `""` | Path to daily journal template file |
| `weekly_template` | `""` | Path to weekly journal template file |
| `monthly_template` | `""` | Path to monthly journal template file |
| `inbox_template` | `""` | Path to inbox note template file |
| `inbox_dir` | `"Resources/"` | Directory for inbox notes (relative to `root_dir`) |
| `tag_sign` | `"Z"` | Sign column indicator for tags |
| `reference_sign` | `"Z"` | Sign column indicator for reference tags |
| `virtual_text_enabled` | `false` | Enable virtual text showing original tag content for references |
| `virtual_text_format` | `'→ "%s"'` | Format string for virtual text (`%s` = original line content) |
| `tag_cache_ttl` | `300` | Tag cache time-to-live in seconds (5 minutes) |
| `week_numbering_system` | `"iso8601"` | Week numbering system: `"iso8601"` (week containing first Thursday) or `"gregorian"` (week containing Jan 1) |

### Week Numbering Systems

zournal.nvim supports two different week numbering systems:

**ISO 8601 (default)**:
- Week 1 is the week containing the first Thursday of the year
- Weeks start on Monday
- Standard international format (`%V` in strftime)
- Used in most European countries, international business

**Gregorian**:
- Week 1 is the week containing January 1st
- Weeks start on Monday
- Some calendars (particularly Italian calendars) may show week numbers using this system

To change the week numbering system, add it to your workspace configuration:

```lua
require('zournal').setup({
  workspaces = {
    personal = {
      root_dir = "~/notes/",
      week_numbering_system = "gregorian",  -- or "iso8601" (default)
      -- ... other options
    },
  },
})
```

### Workspace Auto-Detection

zournal.nvim automatically detects which workspace to use based on:

1. **Current file path** (when you open a `.md` file)
2. **Current working directory** (when you change directories)
3. **Manual selection** (using `:ZournalSelectWorkspace`)

The plugin uses the **longest matching path** when multiple workspaces could match.

**Example:**
- Workspace `personal` has `root_dir = "~/notes/"`
- Workspace `work` has `root_dir = "~/notes/work/"`
- Opening `~/notes/work/project.md` → selects `work` (more specific match)
- Opening `~/notes/personal.md` → selects `personal`

### Directory Structure

With the default configuration, your files will be organized as:

```
~/notes/                    # root_dir - Zettelkasten notes
├── My First Note.md
├── Another Note.md
├── Journal/                # journal_dir - Daily/weekly/monthly journals
│   ├── 2024-01-15.md
│   ├── 2024-01-15-W03.md
│   └── 2024-01.md
└── Resources/              # inbox_dir - Quick capture notes
    └── Quick Idea.md
```

**Note**:
- `journal_dir` can be absolute (e.g., `~/journals/`) or relative to `root_dir`
- `inbox_dir` is always relative to `root_dir`
- Zettelkasten notes are stored directly in `root_dir`

### Template Variables

Templates support the following variables:
- `{{date}}` - Current date (YYYY-MM-DD)
- `{{title}}` - Note title (for inbox notes)
- `{{time}}` - Current time (HH:MM:SS)
- `{{year}}` - Current year
- `{{month}}` - Current month
- `{{day}}` - Current day
- `{{week}}` - Current ISO week number

**Note**: Journal notes (daily/weekly/monthly/inbox) do NOT have frontmatter by default.

Example template (`daily_template.md`):
```markdown
# Daily Journal - {{date}}

## Tasks

## Notes
```

Example Zettelkasten note (manually created root note):
```markdown
# My Note Title

---
zid: 1
created: {{date}}
---

Content here...
```

## Commands

### Journal Commands

| Command | Description |
|---------|-------------|
| `:ZournalDailyJournal` | Create or open today's daily journal |
| `:ZournalWeeklyJournal` | Create or open this week's journal |
| `:ZournalMonthlyJournal` | Create or open this month's journal |
| `:ZournalInbox` | Create a new inbox note (prompts for title) |
| `:ZournalJumpToDate [date]` | Jump to a specific date's journal |

### Zettelkasten Commands

| Command | Description |
|---------|-------------|
| `:ZournalNewChild` | Create a child note of current note |
| `:ZournalNewSibling` | Create a sibling note of current note |
| `:ZournalAddParent` | Add a parent relationship to current note |
| `:ZournalRelations` | Open Telescope picker showing parent/siblings/children |

**Note**: `ZournalNewChild` and `ZournalNewSibling` support visual mode! Select text and run the command to extract it into the new note with automatic WikiLink replacement.

### Tagging Commands

| Command | Description |
|---------|-------------|
| `:ZournalTagAdd` | Add a tag (`{ztag<uuid>}`) to current line |
| `:ZournalTagCopy` | Copy tag from current line as reference (`{zref<uuid>}`) to clipboard |
| `:ZournalTagReferences` | Show all occurrences of tag on current line (original + references) |
| `:ZournalTagFollow` | Jump from reference tag to original tag location |
| `:ZournalVirtualTextShow` | Show virtual text in current buffer for all references |
| `:ZournalVirtualTextShowAll` | Show virtual text across ALL loaded buffers |
| `:ZournalVirtualTextClear` | Clear virtual text from current buffer |
| `:ZournalVirtualTextToggle` | Toggle virtual text on/off for current buffer |
| `:ZournalCacheClear` | Clear the tag cache |
| `:ZournalCachePreload` | Preload cache by scanning all files |
| `:ZournalCacheStats` | Show cache statistics (hits, misses, entries) |

### Navigation Commands

| Command | Description |
|---------|-------------|
| `:ZournalLinks` | Open Telescope picker showing all links in current file |
| `:ZournalFollowLink` | Follow link under cursor |

### Workspace Commands

| Command | Description |
|---------|-------------|
| `:ZournalSelectWorkspace <name>` | Manually switch to specified workspace |
| `:ZournalListWorkspaces` | List all configured workspaces |
| `:ZournalCurrentWorkspace` | Show current workspace information |

## Workflows

### Using Multiple Workspaces

```vim
" List all configured workspaces
:ZournalListWorkspaces

" Check current workspace
:ZournalCurrentWorkspace

" Manually switch workspace
:ZournalSelectWorkspace work

" Workspaces auto-switch when you:
" - Open a .md file in a workspace directory
" - Change directory (:cd) to a workspace directory
```

### Daily Journaling

```vim
" Open today's journal
:ZournalDailyJournal

" Jump to a specific date
:ZournalJumpToDate 2024-01-15
```

### Creating Zettelkasten Notes

1. Create a root note manually with frontmatter after the title:
   ```markdown
   # My First Note

   ---
   zid: 1
   created: 2024-01-15
   ---

   Content goes here...
   ```

   **Note**: Zettelkasten notes have frontmatter AFTER the title. Journal notes have NO frontmatter.

2. Create child notes:
   ```vim
   " From note with zid: 1
   :ZournalNewChild
   " Creates note with zid: 1a
   ```

3. Create sibling notes:
   ```vim
   " From note with zid: 1a
   :ZournalNewSibling
   " Creates note with zid: 1b
   ```

4. Extract text to new note:
   ```vim
   " Select text in visual mode
   v
   " Run command to create child note
   :ZournalNewChild
   " Selected text moves to new note, replaced with [[new-note-title]]
   ```

### Navigating Relationships

```vim
" Show all related notes (parent, siblings, children)
:ZournalRelations

" Navigate through the Telescope picker
" Press Enter to open selected note
```

### Tagging and Referencing Lines

```vim
" Add a tag to current line
:ZournalTagAdd
" Line now has: Some important text {ztag1234abcd-5678-90ef-ghij-klmnopqrstuv}
" Tag is completely concealed (invisible), sign column shows "Z"

" Copy the tag as a reference
:ZournalTagCopy
" Clipboard now has: {zref1234abcd-5678-90ef-ghij-klmnopqrstuv}

" Paste in another file to reference that line
" Reference tag is also concealed, sign column shows "Z"

" Jump to original tag from reference (cursor on reference line)
:ZournalTagFollow
" Opens file with original tag and jumps to that line

" Show original content for reference tags (virtual text)
:ZournalVirtualTextShow
" Reference line now displays: → "Some important text" (virtual text at end of line)

" Show virtual text across ALL loaded buffers (uses cache)
:ZournalVirtualTextShowAll

" Check cache performance
:ZournalCacheStats
" Shows: {entries = 42, cache_hits = 127, cache_misses = 15}

" Show all occurrences of this tag
:ZournalTagReferences
" Opens Telescope picker showing:
" - [Original] file.md:42 - Line content
" - [Reference] other.md:15 - Line content
" - [Reference] another.md:8 - Line content
```

### Link Navigation

```vim
" Show all links in current file
:ZournalLinks

" Follow link under cursor
:ZournalFollowLink

" Or use it in a keymap:
" nnoremap gf <cmd>ZournalFollowLink<cr>
```

## Recommended Keybindings

zournal.nvim doesn't set default keybindings. Here are some recommended mappings:

```lua
-- Journal
vim.keymap.set('n', '<leader>jd', '<cmd>ZournalDailyJournal<cr>', { desc = 'Daily Journal' })
vim.keymap.set('n', '<leader>jw', '<cmd>ZournalWeeklyJournal<cr>', { desc = 'Weekly Journal' })
vim.keymap.set('n', '<leader>jm', '<cmd>ZournalMonthlyJournal<cr>', { desc = 'Monthly Journal' })
vim.keymap.set('n', '<leader>ji', '<cmd>ZournalInbox<cr>', { desc = 'Inbox Note' })

-- Zettelkasten
vim.keymap.set('n', '<leader>zc', '<cmd>ZournalNewChild<cr>', { desc = 'New Child Note' })
vim.keymap.set('v', '<leader>zc', '<cmd>ZournalNewChild<cr>', { desc = 'Extract to Child Note' })
vim.keymap.set('n', '<leader>zs', '<cmd>ZournalNewSibling<cr>', { desc = 'New Sibling Note' })
vim.keymap.set('v', '<leader>zs', '<cmd>ZournalNewSibling<cr>', { desc = 'Extract to Sibling Note' })
vim.keymap.set('n', '<leader>zp', '<cmd>ZournalAddParent<cr>', { desc = 'Add Parent' })
vim.keymap.set('n', '<leader>zr', '<cmd>ZournalRelations<cr>', { desc = 'Relations' })

-- Tagging
vim.keymap.set('n', '<leader>zt', '<cmd>ZournalTagAdd<cr>', { desc = 'Add Tag' })
vim.keymap.set('n', '<leader>zy', '<cmd>ZournalTagCopy<cr>', { desc = 'Copy Tag Reference' })
vim.keymap.set('n', '<leader>zT', '<cmd>ZournalTagReferences<cr>', { desc = 'Tag References' })
vim.keymap.set('n', '<leader>zf', '<cmd>ZournalTagFollow<cr>', { desc = 'Follow Tag to Original' })

-- Navigation
vim.keymap.set('n', '<leader>zl', '<cmd>ZournalLinks<cr>', { desc = 'Links' })
vim.keymap.set('n', 'gf', '<cmd>ZournalFollowLink<cr>', { desc = 'Follow Link' })
```

## Understanding Zettelkasten IDs

zournal.nvim uses a hierarchical ID system:

- **Root notes**: Single numbers (`1`, `2`, `3`)
- **First-level children**: Root + letter (`1a`, `1b`, `2a`)
- **Second-level children**: First-level + number (`1a1`, `1a2`, `2a1`)
- **Third-level children**: Second-level + letter (`1a1a`, `1a2b`)
- Pattern continues: number → letter → number → letter...

**Relationships**:
- `1a` is a child of `1`
- `1a` and `1b` are siblings (same parent `1`)
- `1a1` and `1a2` are siblings (same parent `1a`)
- `1a1` is a child of `1a`, which is a child of `1`

**Gap Filling**:
If you have `1a1` and `1a3`, creating a new sibling will create `1a2` (fills the gap) before creating `1a4`.

## Troubleshooting

### "Current file does not have a zid in frontmatter"

This error appears when you try to use Zettelkasten commands (NewChild, NewSibling, Relations) on a file without a zid.

**Solution**: Add YAML frontmatter to your file AFTER the title:
```markdown
# My Note Title

---
zid: 1
created: 2024-01-15
---

Content here...
```

**Important**: Frontmatter must come AFTER the first header (title) in Zettelkasten notes. Journal notes should NOT have frontmatter at all.

### Links not resolving

- Check that linked files exist in your `root_dir`
- WikiLinks search for filenames (with or without `.md` extension)
- Markdown links use relative paths from the current file

### Tags not concealing

- Ensure `conceallevel` is set: `:set conceallevel=2`
- Concealment only applies to markdown files in your journal directory
- Check that the file path starts with your configured `root_dir`

### "uuidgen command not available"

The tagging system requires the `uuidgen` command.

**Linux/macOS**: Usually pre-installed
**Windows**: Install `util-linux` or use WSL

## Dependencies

- [Telescope](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder and picker UI
- [Plenary](https://github.com/nvim-lua/plenary.nvim) - Lua utility functions
- [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Syntax parsing

## Migration

### Migrating from v0.2.x to v0.3.0

The tag format has changed from hash-based to curly-brace-based to avoid confusion with standard Neovim tags:

**Changes:**
- Tag format: `#ztag<uuid>` → `{ztag<uuid>}` (original)
- Tag format: `#zref<uuid>` → `{zref<uuid>}` (reference)

**Migration:**

Old tags (`#ztag`/`#zref`) will not be concealed in v0.3.0. To migrate existing tags:

```bash
# Update all tags to new format (run from your journal directory)
find . -name "*.md" -type f -exec sed -i 's/#ztag\([0-9a-f-]\+\)/{ztag\1}/g; s/#zref\([0-9a-f-]\+\)/{zref\1}/g' {} +
```

### Migrating from v0.1.x to v0.2.0

If upgrading from v0.1.x, first migrate to v0.2.0 format, then to v0.3.0:

```bash
# Step 1: v0.1.x to v0.2.0 (if needed)
find . -name "*.md" -type f -exec sed -i 's/#z\([0-9a-f-]\+\)/#ztag\1/g' {} +

# Step 2: v0.2.0 to v0.3.0
find . -name "*.md" -type f -exec sed -i 's/#ztag\([0-9a-f-]\+\)/{ztag\1}/g; s/#zref\([0-9a-f-]\+\)/{zref\1}/g' {} +
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
