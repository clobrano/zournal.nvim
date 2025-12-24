-- Picker abstraction layer
-- Supports both Telescope and FzfLua backends
local M = {}

-- Configuration
M.backend = nil  -- Will be set to 'telescope' or 'fzflua'
M.available = {
  telescope = false,
  fzflua = false,
}

-- Detect available picker backends
function M.detect_backends()
  -- Check if Telescope is available
  local has_telescope, _ = pcall(require, 'telescope')
  M.available.telescope = has_telescope

  -- Check if FzfLua is available
  local has_fzflua, _ = pcall(require, 'fzf-lua')
  M.available.fzflua = has_fzflua

  return M.available
end

-- Set the backend based on configuration
-- @param backend string: 'auto', 'telescope', or 'fzflua'
function M.set_backend(backend)
  M.detect_backends()

  if not backend or backend == 'auto' then
    -- Auto-detect: prefer Telescope for backward compatibility
    if M.available.telescope then
      M.backend = 'telescope'
    elseif M.available.fzflua then
      M.backend = 'fzflua'
    else
      error('No picker backend available. Please install telescope.nvim or fzf-lua')
    end
  elseif backend == 'telescope' then
    if not M.available.telescope then
      error('Telescope backend requested but telescope.nvim is not installed')
    end
    M.backend = 'telescope'
  elseif backend == 'fzflua' then
    if not M.available.fzflua then
      error('FzfLua backend requested but fzf-lua is not installed')
    end
    M.backend = 'fzflua'
  else
    error('Invalid picker backend: ' .. tostring(backend) .. '. Must be "auto", "telescope", or "fzflua"')
  end
end

-- Show a picker using the configured backend
-- @param config table: Unified picker configuration
--   {
--     title = "Picker Title",
--     items = { {display = "...", value = {}, ...}, ... },
--     on_select = function(item) ... end,
--     preview = {
--       type = 'file' | 'custom' | nil,
--       get_file = function(item) return filepath end,  -- for type='file'
--       get_line = function(item) return line_num end,  -- optional, for type='file'
--       render = function(item, bufnr) ... end,         -- for type='custom'
--     },
--   }
function M.show(config)
  -- Validate config
  if not config then
    error('Picker config is required')
  end
  if not config.title then
    error('Picker config must have a title')
  end
  if not config.items then
    error('Picker config must have items')
  end

  -- Ensure backend is set
  if not M.backend then
    local zournal_config = require('zournal.config')
    local cfg = zournal_config.get()
    local backend = cfg and cfg.picker_backend or 'auto'
    M.set_backend(backend)
  end

  -- Route to appropriate adapter
  if M.backend == 'telescope' then
    return require('zournal.picker.telescope_adapter').show(config)
  elseif M.backend == 'fzflua' then
    return require('zournal.picker.fzflua_adapter').show(config)
  else
    error('No picker backend configured')
  end
end

-- Get current backend name
function M.get_backend()
  return M.backend
end

-- Check if a specific backend is available
function M.is_available(backend_name)
  M.detect_backends()
  return M.available[backend_name] or false
end

return M
