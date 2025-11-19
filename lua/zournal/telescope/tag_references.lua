-- Telescope picker for tag references
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local utils = require('zournal.utils')
local config = require('zournal.config')

-- Extract UUID from a tag (works with both {ztag and {zref)
local function extract_uuid(tag_string)
  -- Pattern: {ztag or {zref followed by UUID and closing }
  return tag_string:match("{z[tr][ea][fg]([0-9a-f%-]+)}")
end

-- Find all occurrences of a UUID across all journal files
-- Returns array of {type, filepath, filename, line_num, line_content}
local function find_all_tag_occurrences(uuid)
  local cfg = config.get()
  local files = utils.find_files_with_pattern(cfg.root_dir, "%.md$")
  local occurrences = {}

  for _, filepath in ipairs(files) do
    local content = utils.read_file(filepath)
    if content then
      local line_num = 1
      for line in content:gmatch("[^\r\n]+") do
        -- Check for both {ztag and {zref with this UUID
        local ztag_match = line:match("{ztag" .. vim.pesc(uuid) .. "}")
        local zref_match = line:match("{zref" .. vim.pesc(uuid) .. "}")

        if ztag_match or zref_match then
          table.insert(occurrences, {
            type = ztag_match and "Original" or "Reference",
            filepath = filepath,
            filename = vim.fn.fnamemodify(filepath, ":t"),
            line_num = line_num,
            line_content = line:match("^%s*(.-)%s*$"), -- Trimmed line
            -- Store modification time for sorting
            mtime = vim.loop.fs_stat(filepath).mtime.sec,
          })
        end
        line_num = line_num + 1
      end
    end
  end

  -- Sort: Original first (by oldest file), then references (by oldest file)
  table.sort(occurrences, function(a, b)
    if a.type ~= b.type then
      return a.type == "Original" -- Original comes before Reference
    end
    return a.mtime < b.mtime -- Then sort by file age (oldest first)
  end)

  return occurrences
end

-- Pick tag references - shows all occurrences of the tag on current line
function M.pick_tag_references()
  -- Get current line content
  local line = vim.api.nvim_get_current_line()

  -- Extract UUID from tag (works with both {ztag and {zref)
  local uuid = extract_uuid(line)

  if not uuid then
    vim.notify("No tag found on current line", vim.log.levels.ERROR)
    return
  end

  -- Find all occurrences of this UUID
  local occurrences = find_all_tag_occurrences(uuid)

  if #occurrences == 0 then
    vim.notify("No occurrences found for tag: " .. uuid, vim.log.levels.INFO)
    return
  end

  -- Create Telescope picker
  pickers.new({}, {
    prompt_title = "Tag References: " .. uuid:sub(1, 16) .. "...",
    finder = finders.new_table({
      results = occurrences,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("[%s] %s:%d - %s",
            entry.type,
            entry.filename,
            entry.line_num,
            entry.line_content),
          ordinal = entry.type .. " " .. entry.filename .. " " .. entry.line_content,
          filename = entry.filepath,
          lnum = entry.line_num,
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
          -- Open file and jump to line
          vim.cmd(string.format("edit +%d %s", selection.lnum, selection.filename))
        end
      end)
      return true
    end,
  }):find()
end

return M
