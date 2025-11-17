-- Telescope picker for Zettelkasten relationships
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local zettelkasten = require('zournal.zettelkasten')
local frontmatter = require('zournal.frontmatter')
local utils = require('zournal.utils')

-- Get first line of file content for preview
local function get_first_line(filepath)
  if not utils.file_exists(filepath) then
    return ""
  end

  local content = utils.read_file(filepath)
  if not content then
    return ""
  end

  -- Get first non-empty line
  for line in content:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^%-%-%-") then
      return trimmed
    end
  end

  return ""
end

-- Pick related notes (parent, siblings, children)
function M.pick_relations()
  -- Get current file's zid
  local current_file = vim.api.nvim_buf_get_name(0)
  local zid = frontmatter.get_zid(current_file)

  if not zid then
    vim.notify("Current file does not have a zid in frontmatter", vim.log.levels.ERROR)
    return
  end

  -- Find related notes
  local parent = zettelkasten.get_parent(zid)
  local siblings = zettelkasten.get_siblings(zid)
  local children = zettelkasten.get_children(zid)

  -- Build entries for picker
  local entries = {}

  -- Add parent
  if parent and parent.path then
    local first_line = get_first_line(parent.path)
    table.insert(entries, {
      type = "Parent",
      filename = vim.fn.fnamemodify(parent.path, ":t"),
      filepath = parent.path,
      zid = parent.zid,
      preview = first_line,
    })
  end

  -- Add siblings
  for _, sibling in ipairs(siblings) do
    if sibling.path and sibling.path ~= current_file then
      local first_line = get_first_line(sibling.path)
      table.insert(entries, {
        type = "Sibling",
        filename = vim.fn.fnamemodify(sibling.path, ":t"),
        filepath = sibling.path,
        zid = sibling.zid,
        preview = first_line,
      })
    end
  end

  -- Add children
  for _, child in ipairs(children) do
    if child.path then
      local first_line = get_first_line(child.path)
      table.insert(entries, {
        type = "Child",
        filename = vim.fn.fnamemodify(child.path, ":t"),
        filepath = child.path,
        zid = child.zid,
        preview = first_line,
      })
    end
  end

  -- Check if there are any relations
  if #entries == 0 then
    vim.notify("No related notes found", vim.log.levels.INFO)
    return
  end

  -- Create Telescope picker
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
end

return M
