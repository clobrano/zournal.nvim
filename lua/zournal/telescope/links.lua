-- Telescope picker for link navigation
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local links = require('zournal.links')
local utils = require('zournal.utils')

-- Get first line of file content for preview
local function get_first_line(filepath)
  if not utils.file_exists(filepath) then
    return "[File not found]"
  end

  local content = utils.read_file(filepath)
  if not content then
    return "[Cannot read file]"
  end

  -- Get first non-empty line
  for line in content:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^%-%-%-") then
      return trimmed
    end
  end

  return "[Empty file]"
end

-- Pick links from current file
function M.pick_links()
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Read current file content
  local content = utils.read_file(current_file)
  if not content then
    vim.notify("Could not read current file", vim.log.levels.ERROR)
    return
  end

  -- Find all links in the file
  local all_links = links.find_all_links(content)

  if #all_links == 0 then
    vim.notify("No links found in current file", vim.log.levels.INFO)
    return
  end

  -- Build entries for picker
  local entries = {}

  for _, link in ipairs(all_links) do
    local link_text = link.text
    local link_path = nil

    if link.type == "wikilink" then
      link_path = links.resolve_link(link_text, current_file, "wikilink")
    elseif link.type == "markdown" then
      link_path = links.resolve_link(link.path, current_file, "markdown")
    end

    local target_filename = link_path and vim.fn.fnamemodify(link_path, ":t") or "[Unknown]"
    local first_line = link_path and get_first_line(link_path) or "[Broken link]"
    local is_broken = not link_path or not utils.file_exists(link_path)

    local display_text = link.type == "markdown" and link.text or link_text

    table.insert(entries, {
      link_text = display_text,
      target_filename = target_filename,
      filepath = link_path,
      preview = first_line,
      broken = is_broken,
      type = link.type,
    })
  end

  -- Create Telescope picker
  pickers.new({}, {
    prompt_title = "Links in Current File",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        local display_prefix = entry.broken and "[BROKEN] " or ""
        local display = string.format("%s%s → %s - %s",
          display_prefix,
          entry.link_text,
          entry.target_filename,
          entry.preview
        )

        return {
          value = entry,
          display = display,
          ordinal = entry.link_text .. " " .. entry.target_filename .. " " .. entry.preview,
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
        if selection and selection.value.filepath and not selection.value.broken then
          utils.open_file_in_buffer(selection.value.filepath)
        elseif selection and selection.value.broken then
          vim.notify("Cannot open broken link: " .. selection.value.link_text, vim.log.levels.WARN)
        end
      end)
      return true
    end,
  }):find()
end

return M
