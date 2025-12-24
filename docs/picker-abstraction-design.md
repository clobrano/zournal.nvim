# Picker Abstraction Layer Design

## Executive Summary

This document outlines the design for an abstraction layer that allows zournal.nvim to support both Telescope and FzfLua as picker backends, making Telescope an optional rather than hard dependency.

## Current State Analysis

### Telescope API Usage Patterns

Across all four picker implementations (relations, links, tag_references, calendar), the following Telescope APIs are used:

**Core APIs:**
- `pickers.new(opts, config):find()` - Creates and shows picker
- `finders.new_table({ results, entry_maker })` - Provides data
- `conf.generic_sorter(opts)` - Fuzzy sorting
- `actions.select_default:replace(fn)` - Handle selection
- `actions.close(bufnr)` - Close picker
- `action_state.get_selected_entry()` - Get selection
- `previewers.vim_buffer_cat.new({})` - File preview
- `previewers.new_buffer_previewer({ define_preview })` - Custom preview

**Entry Structure:**
```lua
{
  value = data,           -- Original data
  display = "...",        -- Display string
  ordinal = "...",        -- Search/filter string
  filename = "path.md",   -- For file preview
  lnum = 42,             -- Line number for jump
}
```

### FzfLua API Comparison

FzfLua uses a different but simpler API:

**Core APIs:**
- `fzf_exec(contents, opts)` - Single function for all pickers
- Contents can be: table, string (shell cmd), or function
- Actions defined in `opts.actions = { ['default'] = fn }`
- Preview via `opts.preview` or `opts.fzf_opts['--preview']`
- Transform entries with `opts.fn_transform`

**Key Differences:**
1. **Single function vs multiple components** - FzfLua uses `fzf_exec()` for everything
2. **Entry format** - FzfLua works with plain strings (transformed via `fn_transform`)
3. **Actions** - FzfLua uses table of keybind → function mappings
4. **Preview** - Can use fzf native preview or builtin buffer preview
5. **Selected items** - Actions receive array of selected strings directly

## Proposed Abstraction Layer

### Design Principles

1. **Backend-agnostic interface** - Application code shouldn't know which picker is used
2. **Configuration-driven** - User chooses backend in setup
3. **Feature parity** - Support common features across both backends
4. **Graceful degradation** - Warn about unsupported features rather than fail
5. **No breaking changes** - Existing Telescope users continue to work

### Architecture

```
┌─────────────────────────────────────┐
│  Application Code (relations.lua)   │
│  Uses: picker.show(config)          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Picker Abstraction (picker.lua)    │
│  - Unified interface                │
│  - Backend detection                │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
┌─────────────┐ ┌─────────────┐
│  Telescope  │ │  FzfLua     │
│  Adapter    │ │  Adapter    │
└─────────────┘ └─────────────┘
```

### Unified Interface

**File:** `lua/zournal/picker.lua`

```lua
local M = {}

-- Configuration
M.backend = nil  -- 'telescope' or 'fzflua'
M.available = { telescope = false, fzflua = false }

-- Check available backends
function M.detect_backends()
  M.available.telescope = pcall(require, 'telescope')
  M.available.fzflua = pcall(require, 'fzf-lua')

  -- Auto-select if not configured
  if not M.backend then
    if M.available.telescope then
      M.backend = 'telescope'
    elseif M.available.fzflua then
      M.backend = 'fzflua'
    else
      error('No picker backend available. Install telescope.nvim or fzf-lua')
    end
  end
end

-- Unified picker configuration
function M.show(config)
  --[[
  config = {
    title = "Picker Title",
    items = {
      { display = "...", value = {}, filename = "...", lnum = 1 },
      ...
    },
    -- OR
    items_fn = function(callback) ... end,

    on_select = function(item) ... end,
    preview = {
      type = 'file',  -- or 'buffer' or 'custom'
      get_file = function(item) return item.filename end,
      get_line = function(item) return item.lnum end,
      -- For custom preview:
      render = function(item, bufnr) ... end,
    },
    search_fields = { 'display' },  -- What to search on
  }
  ]]--

  M.detect_backends()

  if M.backend == 'telescope' then
    return require('zournal.picker.telescope_adapter').show(config)
  elseif M.backend == 'fzflua' then
    return require('zournal.picker.fzflua_adapter').show(config)
  end
end

return M
```

### Telescope Adapter

**File:** `lua/zournal/picker/telescope_adapter.lua`

```lua
local M = {}

function M.show(config)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  -- Build previewer based on config
  local previewer
  if config.preview then
    if config.preview.type == 'file' then
      previewer = previewers.vim_buffer_cat.new({})
    elseif config.preview.type == 'custom' then
      previewer = previewers.new_buffer_previewer({
        title = config.title .. " Preview",
        define_preview = function(self, entry)
          config.preview.render(entry.value, self.state.bufnr)
        end,
      })
    end
  end

  -- Build entry maker
  local function entry_maker(item)
    local entry = {
      value = item.value or item,
      display = item.display,
      ordinal = item.display,  -- Default: search on display
    }

    -- Add file/line for preview
    if config.preview and config.preview.get_file then
      entry.filename = config.preview.get_file(item)
    end
    if config.preview and config.preview.get_line then
      entry.lnum = config.preview.get_line(item)
    end

    return entry
  end

  -- Create picker
  pickers.new({}, {
    prompt_title = config.title,
    finder = finders.new_table({
      results = config.items,
      entry_maker = entry_maker,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and config.on_select then
          config.on_select(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
```

### FzfLua Adapter

**File:** `lua/zournal/picker/fzflua_adapter.lua`

```lua
local M = {}

function M.show(config)
  local fzf = require('fzf-lua')

  -- Transform items to strings for fzf
  local fzf_entries = {}
  local entry_map = {}  -- Map display string → original item

  for i, item in ipairs(config.items) do
    local display = item.display
    fzf_entries[i] = display
    entry_map[display] = item
  end

  -- Build preview configuration
  local preview_config = {}
  if config.preview then
    if config.preview.type == 'file' then
      preview_config.previewer = "builtin"
      preview_config.preview = function(items)
        local item = entry_map[items[1]]
        if item and config.preview.get_file then
          local file = config.preview.get_file(item)
          local line = config.preview.get_line and config.preview.get_line(item) or 1
          return string.format("bat --color=always --highlight-line %d %s", line, file)
        end
        return nil
      end
    elseif config.preview.type == 'custom' then
      preview_config.previewer = {
        type = "builtin",
        fn = function(items)
          local item = entry_map[items[1]]
          if item and config.preview.render then
            -- Create preview buffer content
            local lines = {}
            local bufnr = vim.api.nvim_create_buf(false, true)
            config.preview.render(item, bufnr)
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            vim.api.nvim_buf_delete(bufnr, { force = true })
            return lines
          end
          return {}
        end,
      }
    end
  end

  -- Show picker
  fzf.fzf_exec(fzf_entries, vim.tbl_extend("force", {
    prompt = config.title .. "> ",
    actions = {
      ['default'] = function(selected)
        if selected and selected[1] and config.on_select then
          local item = entry_map[selected[1]]
          config.on_select(item.value or item)
        end
      end,
    },
  }, preview_config))
end

return M
```

## Migration Path

### Phase 1: Create Abstraction Layer (Non-Breaking)

1. Add `lua/zournal/picker.lua` (unified interface)
2. Add `lua/zournal/picker/telescope_adapter.lua`
3. Add `lua/zournal/picker/fzflua_adapter.lua`
4. Keep existing telescope integration files unchanged
5. Add configuration option: `picker_backend = 'telescope'` (default)

### Phase 2: Migrate One Feature (Proof of Concept)

1. Convert `lua/zournal/telescope/links.lua` to use new abstraction
2. Rename to `lua/zournal/pickers/links.lua`
3. Test with both backends
4. Gather feedback

### Phase 3: Migrate Remaining Features

1. Convert `relations.lua`
2. Convert `tag_references.lua`
3. Convert `calendar.lua`
4. Update documentation

### Phase 4: Cleanup

1. Remove old `lua/zournal/telescope/` directory
2. Update README dependencies section
3. Mark Telescope as optional dependency
4. Update installation instructions

## Configuration Changes

### Current Configuration

```lua
require('zournal').setup({
  workspaces = { ... },
})
```

### New Configuration

```lua
require('zournal').setup({
  picker_backend = 'telescope',  -- or 'fzflua' or 'auto'
  workspaces = { ... },
})
```

**Backend selection logic:**
- `'telescope'` - Use Telescope (error if not available)
- `'fzflua'` - Use FzfLua (error if not available)
- `'auto'` (default) - Auto-detect (prefer Telescope for compatibility)

## Testing Strategy

1. **Unit tests** - Test each adapter independently
2. **Integration tests** - Test with real data
3. **Feature parity matrix** - Ensure all features work with both backends
4. **User acceptance** - Beta test with FzfLua users

## Benefits

1. **Reduced dependencies** - Users can choose their preferred picker
2. **Better performance** - FzfLua is often faster for large datasets
3. **User flexibility** - Works with existing workflows
4. **Future-proof** - Easy to add more picker backends

## Limitations

### FzfLua Limitations

1. **Preview customization** - Less flexible than Telescope's builtin preview
2. **Multi-selection** - Different UX than Telescope
3. **Theming** - Uses fzf's built-in theming rather than Neovim highlights

### Solutions

- Document differences in behavior
- Provide sensible defaults for both backends
- Allow backend-specific configuration overrides

## References

- [Telescope Documentation](https://github.com/nvim-telescope/telescope.nvim)
- [FzfLua Documentation](https://github.com/ibhagwan/fzf-lua)
- [FzfLua Advanced API](https://github.com/ibhagwan/fzf-lua/wiki/Advanced)
- [FzfLua Options](https://github.com/ibhagwan/fzf-lua/blob/main/OPTIONS.md)

## Next Steps

1. Review and approve this design document
2. Create implementation plan with task breakdown
3. Set up test environment with both pickers installed
4. Implement Phase 1 (abstraction layer)
5. Implement Phase 2 (proof of concept with links picker)
6. Iterate based on feedback
