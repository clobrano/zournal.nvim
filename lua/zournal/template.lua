-- Template loading and variable substitution
local M = {}

local utils = require("zournal.utils")

-- ============================================================================
-- Default Templates (5.4)
-- ============================================================================

--- Default template for daily journal
--- Note: Journal notes do NOT have frontmatter
local DEFAULT_DAILY_TEMPLATE = [[# Daily Journal - {{date}}

## Notes

]]

--- Default template for weekly journal
--- Note: Journal notes do NOT have frontmatter
local DEFAULT_WEEKLY_TEMPLATE = [[# Weekly Journal - Week {{week}} ({{date}})

## Goals

## Accomplishments

## Notes

]]

--- Default template for monthly journal
--- Note: Journal notes do NOT have frontmatter
local DEFAULT_MONTHLY_TEMPLATE = [[# Monthly Journal - {{month}} {{year}}

## Overview

## Goals

## Highlights

]]

--- Default template for inbox notes
--- Note: Journal notes do NOT have frontmatter
local DEFAULT_INBOX_TEMPLATE = [[# {{title}}

]]

-- ============================================================================
-- Template Loading (5.1)
-- ============================================================================

--- Load template from file
---@param template_path string Path to template file
---@return string|nil content Template content or nil if not found
function M.load_template(template_path)
  if not template_path or template_path == "" then
    return nil
  end

  -- Try to read template file
  local content = utils.read_file(template_path)
  return content
end

-- ============================================================================
-- Variable Substitution (5.2)
-- ============================================================================

--- Substitute variables in template content
---@param template_content string Template with {{variable}} placeholders
---@param variables table Key-value pairs for substitution
---@return string content Template with substituted values
function M.substitute_variables(template_content, variables)
  if not template_content then
    return ""
  end

  variables = variables or {}

  -- Replace each {{variable}} with its value
  local result = template_content
  for key, value in pairs(variables) do
    local pattern = "{{" .. key .. "}}"
    -- Escape special characters in the pattern
    pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    result = result:gsub(pattern, tostring(value))
  end

  return result
end

-- ============================================================================
-- Template Application (5.3)
-- ============================================================================

--- Apply template with variable substitution
---@param template_path string Path to template file
---@param variables table Variables for substitution
---@param default_template string|nil Default template if file not found
---@return string content Final template content
function M.apply_template(template_path, variables, default_template)
  variables = variables or {}

  -- Add common date/time variables if not provided
  if not variables.date then
    variables.date = utils.format_date("%Y-%m-%d")
  end
  if not variables.time then
    variables.time = utils.format_date("%H:%M:%S")
  end
  if not variables.year then
    variables.year = utils.format_date("%Y")
  end
  if not variables.month then
    variables.month = utils.format_date("%B")
  end
  if not variables.day then
    variables.day = utils.format_date("%d")
  end
  if not variables.week then
    variables.week = tostring(utils.get_iso_week())
  end
  if not variables.day_of_week_short then
    variables.day_of_week_short = utils.format_date("%a")
  end
  if not variables.day_of_week_long then
    variables.day_of_week_long = utils.format_date("%A")
  end

  -- Load template
  local template_content = M.load_template(template_path)

  -- Use default template if file not found
  if not template_content then
    template_content = default_template or ""
  end

  -- Substitute variables
  return M.substitute_variables(template_content, variables)
end

--- Apply daily journal template
---@param template_path string|nil Custom template path
---@param variables table|nil Additional variables
---@return string content
function M.apply_daily_template(template_path, variables)
  return M.apply_template(template_path, variables, DEFAULT_DAILY_TEMPLATE)
end

--- Apply weekly journal template
---@param template_path string|nil Custom template path
---@param variables table|nil Additional variables
---@return string content
function M.apply_weekly_template(template_path, variables)
  return M.apply_template(template_path, variables, DEFAULT_WEEKLY_TEMPLATE)
end

--- Apply monthly journal template
---@param template_path string|nil Custom template path
---@param variables table|nil Additional variables
---@return string content
function M.apply_monthly_template(template_path, variables)
  return M.apply_template(template_path, variables, DEFAULT_MONTHLY_TEMPLATE)
end

--- Apply inbox note template
---@param template_path string|nil Custom template path
---@param variables table|nil Additional variables (must include 'title')
---@return string content
function M.apply_inbox_template(template_path, variables)
  variables = variables or {}
  if not variables.title then
    variables.title = "Untitled"
  end
  return M.apply_template(template_path, variables, DEFAULT_INBOX_TEMPLATE)
end

return M
