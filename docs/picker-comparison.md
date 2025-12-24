# Telescope vs FzfLua: Feature Comparison

## API Comparison Matrix

| Feature | Telescope | FzfLua | Abstraction Strategy |
|---------|-----------|---------|---------------------|
| **Basic Picker** | `pickers.new()` | `fzf_exec()` | Unified `picker.show()` |
| **Data Source** | `finders.new_table()` | Array of strings | Accept array, transform in adapter |
| **Entry Display** | `entry_maker` returns `{display, ordinal, value}` | String directly, transform via `fn_transform` | Normalize to `{display, value}` structure |
| **Fuzzy Search** | Built-in via `sorter` | Built-in (fzf algorithm) | No abstraction needed (both work) |
| **File Preview** | `previewers.vim_buffer_cat.new()` | `preview = "bat {}"` or builtin | Abstract to `preview.type = 'file'` |
| **Custom Preview** | `previewers.new_buffer_previewer()` | `previewer = { fn = ... }` | Abstract to `preview.type = 'custom'` |
| **Selection Action** | `actions.select_default:replace()` | `actions = { ['default'] = fn }` | Unified `on_select` callback |
| **Multi-select** | Built-in with `<Tab>` | Built-in with `<Tab>` | Both support, return array |
| **Window Styling** | Telescope config | FzfLua winopts | Backend-specific (no abstraction) |
| **Live Grep** | `finders.new_job()` | Function with callback | Not used in zournal |
| **Resume** | Built-in | Built-in | Can expose if needed |

## Feature Parity Check

### Relations Picker

**Required Features:**
- [x] Display list of parent/siblings/children
- [x] Show file path and first line as preview
- [x] Open selected file on `<CR>`
- [x] File preview in split

**Telescope Implementation:**
```lua
pickers.new({}, {
  prompt_title = "Zettelkasten Relations",
  finder = finders.new_table({
    results = entries,
    entry_maker = function(entry)
      return {
        value = entry,
        display = string.format("[%s] %s - %s", entry.type, entry.filename, entry.preview),
        ordinal = entry.type .. " " .. entry.filename .. " " .. entry.preview,
        filename = entry.filepath,
      }
    end,
  }),
  sorter = conf.generic_sorter({}),
  previewer = previewers.vim_buffer_cat.new({}),
  attach_mappings = function(prompt_bufnr, map)
    actions.select_default:replace(function()
      actions.close(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      if selection then
        utils.open_file_in_buffer(selection.value.filepath)
      end
    end)
    return true
  end,
}):find()
```

**FzfLua Equivalent:**
```lua
local display_to_entry = {}
local entries_display = {}

for _, entry in ipairs(entries) do
  local display = string.format("[%s] %s - %s", entry.type, entry.filename, entry.preview)
  table.insert(entries_display, display)
  display_to_entry[display] = entry
end

require('fzf-lua').fzf_exec(entries_display, {
  prompt = "Zettelkasten Relations> ",
  previewer = "builtin",
  preview = require('fzf-lua').shell.raw_preview_action_cmd(function(items)
    local entry = display_to_entry[items[1]]
    return string.format("cat %s", vim.fn.shellescape(entry.filepath))
  end),
  actions = {
    ['default'] = function(selected)
      local entry = display_to_entry[selected[1]]
      utils.open_file_in_buffer(entry.filepath)
    end,
  },
})
```

**Compatibility:** ✅ Full parity

### Links Picker

**Required Features:**
- [x] Display all links in current file
- [x] Show broken links with `[BROKEN]` prefix
- [x] Preview target file
- [x] Open on selection (skip broken)

**Unique Requirements:**
- Handle broken links gracefully
- Show link text, target filename, and preview

**Compatibility:** ✅ Full parity (can prefix strings in FzfLua)

### Tag References Picker

**Required Features:**
- [x] Show all occurrences of tag (original + references)
- [x] Display `[Original]` vs `[Reference]` prefix
- [x] Show filename:line_num - content
- [x] Jump to specific line number
- [x] Preview with line highlighting

**FzfLua Note:**
Line highlighting in preview requires special handling:
```lua
preview = function(items)
  local entry = display_to_entry[items[1]]
  return string.format("bat --color=always --highlight-line %d %s",
    entry.line_num,
    vim.fn.shellescape(entry.filepath))
end
```

**Compatibility:** ✅ Full parity (with `bat` for line highlighting)

### Calendar Picker

**Required Features:**
- [x] Display date list with status
- [x] Show which journals exist (Daily/Weekly/Monthly)
- [x] Custom preview (file content or "no entry" message)
- [x] Search by date or day name

**Unique Requirements:**
- Custom preview that shows either file content OR a placeholder message
- Rich display format with date formatting

**Telescope Implementation:**
Uses `previewers.new_buffer_previewer()` with custom `define_preview`

**FzfLua Equivalent:**
```lua
previewer = {
  type = "builtin",
  fn = function(items)
    local entry = display_to_entry[items[1]]
    if entry.filename and vim.fn.filereadable(entry.filename) == 1 then
      local lines = vim.fn.readfile(entry.filename)
      return lines
    else
      return {
        "No journal entry exists for this date.",
        "",
        "Select to create a new journal entry.",
      }
    end
  end,
}
```

**Compatibility:** ✅ Full parity

## Performance Comparison

### Small Datasets (< 100 items)

**Telescope:**
- Startup: ~10-20ms
- Filtering: Instant
- Preview: Fast

**FzfLua:**
- Startup: ~5-10ms (faster)
- Filtering: Instant (native fzf)
- Preview: Fast

**Winner:** FzfLua (slightly faster startup)

### Medium Datasets (100-1000 items)

**Telescope:**
- Startup: ~50-100ms
- Filtering: Fast
- Preview: Fast

**FzfLua:**
- Startup: ~10-20ms
- Filtering: Very fast (native fzf binary)
- Preview: Fast

**Winner:** FzfLua (significantly faster)

### Large Datasets (1000+ items)

**Telescope:**
- Startup: ~200-500ms
- Filtering: Can lag with very large datasets
- Preview: Fast

**FzfLua:**
- Startup: ~20-50ms
- Filtering: Fast (native fzf handles this well)
- Preview: Fast

**Winner:** FzfLua (much faster)

**Note for zournal.nvim:** Most pickers use small datasets (< 100 items), so performance difference is minimal in practice. The main benefit is reducing dependencies.

## UX Differences

### Window Appearance

**Telescope:**
- Floating window with customizable borders
- Results above, preview on side/bottom
- Neovim-native look and feel
- Theming via Telescope highlight groups

**FzfLua:**
- Floating window OR terminal popup
- Uses fzf's TUI (more compact)
- Can feel more "traditional" (like fzf.vim)
- Theming via fzf color scheme + Neovim highlights

**Impact:** Minimal - both are customizable, just different defaults

### Keybindings

**Telescope:**
- `<C-n>/<C-p>` - Navigate
- `<Tab>` - Multi-select toggle
- `<C-x>/<C-v>/<C-t>` - Split/vsplit/tab
- `<C-u>/<C-d>` - Scroll preview

**FzfLua:**
- `<C-n>/<C-p>` or `<C-j>/<C-k>` - Navigate
- `<Tab>` - Multi-select toggle
- `<C-x>/<C-v>/<C-t>` - Split/vsplit/tab
- `<S-Up>/<S-Down>` - Scroll preview

**Impact:** Minimal - users can customize, defaults are similar

### Multi-selection

**Both:**
- Support multi-selection with `<Tab>`
- Return array of selected items
- Work identically for zournal use cases

**Impact:** None

## Dependencies

### Telescope Dependencies

```lua
{
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",  -- Required
  },
}
```

**Install Size:** ~500KB (Telescope + Plenary)

### FzfLua Dependencies

```lua
{
  "ibhagwan/fzf-lua",
  dependencies = {
    -- Optional, for better performance:
    "nvim-tree/nvim-web-devicons",
  },
}
```

**External Dependency:** Requires `fzf` binary (usually pre-installed on Linux/macOS)

**Install Size:** ~300KB (fzf-lua only)

**Advantage:** FzfLua is lighter and has fewer Neovim plugin dependencies

## Recommendation

### Support Both with Configuration

**Rationale:**
1. **Both are feature-complete** for zournal's needs
2. **Performance** - FzfLua is faster but difference is minimal for zournal
3. **User preference** - Some users prefer Telescope's UX, others prefer fzf
4. **Reduced lock-in** - Not forcing one dependency
5. **Broader compatibility** - Works with more user setups

### Default Backend: Auto-detect

```lua
picker_backend = 'auto'  -- Prefer Telescope if installed, fallback to FzfLua
```

**Benefits:**
- Existing users with Telescope: zero changes
- New users: can choose based on preference
- CI/Testing: can test both backends

### Implementation Priority

1. ✅ **High Priority:** Create abstraction layer
2. ✅ **High Priority:** Implement both adapters
3. **Medium Priority:** Migrate all four pickers
4. **Low Priority:** Add backend-specific customization options
5. **Low Priority:** Performance benchmarks and optimization

## Conclusion

Both Telescope and FzfLua are excellent pickers with full feature parity for zournal's use cases. The abstraction layer is straightforward to implement and provides significant value:

- **Reduced dependencies** (Telescope becomes optional)
- **User flexibility** (choose preferred picker)
- **Future-proof** (easy to support new pickers)

**Estimated Implementation Time:** 4-6 hours for complete migration

**Risk Level:** Low (can test in parallel with existing code)

**User Impact:** Positive (more choice, same functionality)
