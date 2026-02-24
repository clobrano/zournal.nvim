-- Telescope picker for backlinks (files that link to the current file)
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local links = require('zournal.links')
local utils = require('zournal.utils')
local config = require('zournal.config')

-- Find all lines in a file that link to the target file
-- Returns: list of {line_num, line, link_text, link_type}
local function find_backlinks_in_file(source_filepath, target_filepath)
  local content = utils.read_file(source_filepath)
  if not content then
    return {}
  end

  local target_basename = vim.fn.fnamemodify(target_filepath, ":t:r") -- name without extension
  local target_filename = vim.fn.fnamemodify(target_filepath, ":t")   -- name with extension

  local results = {}
  local line_num = 0
  local seen_lines = {}

  for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    line_num = line_num + 1

    local matched = false

    -- Check WikiLinks: [[basename]] or [[basename.md]]
    for link_text in line:gmatch("%[%[([^%]]+)%]%]") do
      local link_base = link_text:gsub("%.md$", "")
      if link_base == target_basename or link_text == target_filename then
        if not seen_lines[line_num] then
          seen_lines[line_num] = true
          table.insert(results, {
            line_num = line_num,
            line = line,
            link_text = link_text,
            link_type = "wikilink",
          })
        end
        matched = true
        break
      end
    end

    -- Check Markdown links: [text](path)
    if not matched then
      for text, path in line:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
        local resolved = links.resolve_link(path, source_filepath, "markdown")
        if resolved == target_filepath then
          if not seen_lines[line_num] then
            seen_lines[line_num] = true
            table.insert(results, {
              line_num = line_num,
              line = line,
              link_text = text,
              link_type = "markdown",
            })
          end
          break
        end
      end
    end
  end

  return results
end

-- Resolve the directory to search for backlinks.
-- Uses the workspace root_dir when the current file lives inside it,
-- and falls back to the current file's parent directory otherwise.
local function resolve_search_dir(current_file)
  local conf_val = config.get()
  local root_dir = conf_val.root_dir and vim.fn.expand(conf_val.root_dir) or nil

  -- Use root_dir only when it exists and the current file is inside it
  if root_dir and root_dir ~= "" then
    local Path = require("plenary.path")
    if Path:new(root_dir):is_dir() then
      local abs_current = vim.fn.fnamemodify(current_file, ":p")
      local abs_root = vim.fn.fnamemodify(root_dir, ":p")
      -- Ensure trailing slash for prefix comparison
      if not abs_root:match("/$") then abs_root = abs_root .. "/" end
      if abs_current:sub(1, #abs_root) == abs_root then
        return root_dir
      end
    end
  end

  -- Fallback: parent directory of the current file
  return vim.fn.fnamemodify(current_file, ":h")
end

-- Pick all files that link to the current file
function M.pick_backlinks()
  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local search_dir = resolve_search_dir(current_file)

  -- Find all markdown files recursively under search_dir
  local all_files = utils.find_files_with_pattern(search_dir, "%.md$")

  if #all_files == 0 then
    vim.notify("No markdown files found under: " .. search_dir, vim.log.levels.WARN)
    return
  end

  -- Build entries by scanning all files for links to the current file
  local entries = {}

  for _, filepath in ipairs(all_files) do
    -- Skip the current file itself
    if filepath ~= current_file then
      local file_backlinks = find_backlinks_in_file(filepath, current_file)
      for _, bl in ipairs(file_backlinks) do
        local source_name = vim.fn.fnamemodify(filepath, ":t")
        local trimmed_line = bl.line:match("^%s*(.-)%s*$")
        table.insert(entries, {
          filepath = filepath,
          source_name = source_name,
          line_num = bl.line_num,
          line = trimmed_line,
          link_text = bl.link_text,
          link_type = bl.link_type,
        })
      end
    end
  end

  if #entries == 0 then
    local current_name = vim.fn.fnamemodify(current_file, ":t")
    vim.notify("No backlinks found for " .. current_name, vim.log.levels.INFO)
    return
  end

  local current_name = vim.fn.fnamemodify(current_file, ":t")

  -- Create Telescope picker
  pickers.new({}, {
    prompt_title = "Backlinks → " .. current_name,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        local display = string.format("%s:%d  %s",
          entry.source_name,
          entry.line_num,
          entry.line
        )

        return {
          value = entry,
          display = display,
          ordinal = entry.source_name .. " " .. entry.line,
          filename = entry.filepath,
          lnum = entry.line_num,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.vim_buffer_vimgrep.new({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          utils.open_file_in_buffer(selection.value.filepath)
          -- Jump to the linking line
          vim.api.nvim_win_set_cursor(0, { selection.value.line_num, 0 })
          vim.cmd("normal! zz")
        end
      end)
      return true
    end,
  }):find()
end

return M
