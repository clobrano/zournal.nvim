-- FzfLua adapter for picker abstraction
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
  local fzf_config = {
    prompt = config.title .. "> ",
    actions = {
      ['default'] = function(selected)
        if selected and selected[1] and config.on_select then
          local item = entry_map[selected[1]]
          if item then
            config.on_select(item.value or item)
          end
        end
      end,
    },
  }

  -- Configure preview
  if config.preview then
    if config.preview.type == 'file' then
      -- File preview
      fzf_config.previewer = "builtin"

      -- Use bat for syntax highlighting if available, fallback to cat
      local has_bat = vim.fn.executable('bat') == 1

      fzf_config.preview = require('fzf-lua').shell.raw_preview_action_cmd(function(items)
        if not items or not items[1] then
          return nil
        end

        local item = entry_map[items[1]]
        if not item then
          return nil
        end

        local file = config.preview.get_file and config.preview.get_file(item)
        if not file then
          return nil
        end

        -- Get line number if available
        local line_num = config.preview.get_line and config.preview.get_line(item)

        if has_bat and line_num then
          -- Use bat with line highlighting
          return string.format("bat --color=always --highlight-line %d %s",
            line_num,
            vim.fn.shellescape(file))
        elseif has_bat then
          -- Use bat without line highlighting
          return string.format("bat --color=always %s", vim.fn.shellescape(file))
        else
          -- Fallback to cat
          return string.format("cat %s", vim.fn.shellescape(file))
        end
      end)

    elseif config.preview.type == 'custom' then
      -- Custom preview using builtin buffer
      fzf_config.previewer = {
        type = "builtin",
        fn = function(items)
          if not items or not items[1] then
            return {}
          end

          local item = entry_map[items[1]]
          if not item or not config.preview.render then
            return {}
          end

          -- Create temporary buffer for preview content
          local bufnr = vim.api.nvim_create_buf(false, true)

          -- Render preview to buffer
          config.preview.render(item, bufnr)

          -- Get buffer lines
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

          -- Clean up temporary buffer
          vim.api.nvim_buf_delete(bufnr, { force = true })

          return lines
        end,
      }
    end
  end

  -- Show picker
  fzf.fzf_exec(fzf_entries, fzf_config)
end

return M
