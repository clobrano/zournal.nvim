-- Telescope adapter for picker abstraction
local M = {}

function M.show(config)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  -- Build previewer based on config
  local previewer = nil
  if config.preview then
    if config.preview.type == 'file' then
      -- Use Telescope's built-in file previewer
      previewer = previewers.vim_buffer_cat.new({})
    elseif config.preview.type == 'custom' then
      -- Use custom buffer previewer
      previewer = previewers.new_buffer_previewer({
        title = config.title .. " Preview",
        define_preview = function(self, entry)
          if entry.value and config.preview.render then
            config.preview.render(entry.value, self.state.bufnr)
          end
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
    if config.preview then
      if config.preview.get_file then
        local file = config.preview.get_file(item)
        if file then
          entry.filename = file
        end
      end
      if config.preview.get_line then
        local line = config.preview.get_line(item)
        if line then
          entry.lnum = line
        end
      end
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
