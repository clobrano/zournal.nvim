# zournal.nvim

A Neovim plugin for journaling with Zettelkasten-style note-taking capabilities.

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
- **Tag Concealment**: Tags are concealed as symbols (📌 by default) for clean reading
- **Copy Tags**: Easily copy tags to reference them elsewhere
- **Neovim Compatible**: UUIDs prefixed with 'z' for Neovim tag compatibility

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

Here's an example configuration with all available options and their defaults:

```lua
require('zournal').setup({
  -- Root directory for all journal files
  root_dir = "~/journal/",

  -- Filename formats for journal types (strftime-like patterns)
  daily_format = "%Y-%m-%d.md",
  weekly_format = "%Y-W%W.md",
  monthly_format = "%Y-%m.md",

  -- Template file paths (leave empty for basic defaults)
  daily_template = "",
  weekly_template = "",
  monthly_template = "",
  inbox_template = "",

  -- Inbox directory (relative to root_dir)
  inbox_dir = "Resources/",

  -- Tag concealment symbols
  tag_symbol = "📌",
  reference_symbol = "→📌",
})
```

### Template Variables

Templates support the following variables:
- `{{date}}` - Current date (YYYY-MM-DD)
- `{{title}}` - Note title (for inbox notes)
- `{{time}}` - Current time (HH:MM:SS)
- `{{year}}` - Current year
- `{{month}}` - Current month
- `{{day}}` - Current day
- `{{week}}` - Current ISO week number

Example template (`daily_template.md`):
```markdown
---
date: {{date}}
---

# {{date}}

## Tasks

## Notes
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
| `:ZournalTagLine` | Tag current line with a UUID |
| `:ZournalCopyTag` | Copy tag from current line to clipboard |

### Navigation Commands

| Command | Description |
|---------|-------------|
| `:ZournalLinks` | Open Telescope picker showing all links in current file |
| `:ZournalFollowLink` | Follow link under cursor |

## Workflows

### Daily Journaling

```vim
" Open today's journal
:ZournalDailyJournal

" Jump to a specific date
:ZournalJumpToDate 2024-01-15
```

### Creating Zettelkasten Notes

1. Create a root note manually with frontmatter:
   ```markdown
   ---
   zid: 1
   created: 2024-01-15
   ---

   # My First Note
   ```

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
" Tag a line
:ZournalTagLine
" Line now has: Some important text #z1234abcd-5678-90ef-ghij-klmnopqrstuv

" Copy the tag
:ZournalCopyTag
" Tag is now in clipboard

" Paste in another file to reference that line
" Neovim's tag navigation works: Ctrl-] on the tag jumps to the original
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
vim.keymap.set('n', '<leader>zt', '<cmd>ZournalTagLine<cr>', { desc = 'Tag Line' })
vim.keymap.set('n', '<leader>zy', '<cmd>ZournalCopyTag<cr>', { desc = 'Copy Tag' })

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

**Solution**: Add YAML frontmatter to your file:
```markdown
---
zid: 1
created: 2024-01-15
---
```

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

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
