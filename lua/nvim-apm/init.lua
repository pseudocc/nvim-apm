local Buckets = require 'nvim-apm.buckets'
local M = {}

---@diagnostic disable-next-line: lowercase-global
vim = vim or {} -- make compiler happy

local state = {}

local style = {
  apm_lines = 1,
  key_lines = 1,
  key_max_lines = 3,
  width = 14,
  height = 2,
}

local function format_apm(apm)
  if apm > 9e3 then
    -- IT'S OVER 9000!
    return '>9k'
  end

  if apm > 1e3 then
    local i, f = math.modf(apm / 1e3)
    f = math.floor(f * 10)
    if f ~= 0 then
      return string.format('%s.%sk', i, f)
    end
    return i .. 'k'
  end

  return tostring(apm)
end

local function tick()
  local mode, apm

  local now = os.time()
  for _, value in pairs(state.buckets or {}) do
    value:truncate(now)
  end

  local t_apm = state.buckets.total:apm(now)
  local result = vim.api.nvim_get_mode()
  if result == nil then
    return
  end

  if result.mode == 'i' then
    mode = 'i'
    apm = state.buckets.insert:apm(now)
  else
    mode = 'n'
    apm = state.buckets.normal:apm(now)
  end

  t_apm = format_apm(t_apm)
  apm = format_apm(apm)

  vim.api.nvim_buf_set_lines(state.bufh, 0, style.apm_lines, false , {
    string.format('t:%4s %s:%4s', t_apm, mode, apm),
  })
end

local function key_stroke(key)
  local now = os.time()
  key = vim.fn.keytrans(key)

  if key == '<Cmd>' or key:find('^<t_') ~= nil then
    return
  end

  state.buckets.total:push(key, now)
  state.buckets.recent:push(key, now)

  local result = vim.api.nvim_get_mode()
  if result == nil then
    return
  end

  if result.mode == 'i' then
    state.buckets.insert:push(key, now)
  else
    state.buckets.normal:push(key, now)
  end

  local keylog = state.buckets.recent:keys()
  local key_lines = math.ceil(#keylog / style.width)
  if key_lines > style.key_max_lines then
    key_lines = style.key_max_lines
    keylog = string.sub(keylog, #keylog - key_lines * style.width + 1)
  end

  local height = style.apm_lines + key_lines
  if height ~= state.win_height then
    if state.win ~= nil then
      vim.api.nvim_win_set_height(state.win, height)
    end
    state.win_height = height
  end

  vim.api.nvim_buf_set_lines(state.bufh,
    style.apm_lines, style.apm_lines + style.key_lines, false, { keylog })
end

function M.resize()
  if state.active ~= true then
    return
  end

  if state.bufh == nil then
    state.bufh = vim.api.nvim_create_buf(false, true)
  end

  local ui_config = {
    style = 'minimal',
    relative = 'editor',
    width = style.width,
    height = style.height,
    anchor = 'NE',
    row = 1,
    col = vim.o.columns - 1,
    focusable = false,
    border = 'rounded',
    noautocmd = true,
  }

  if state.win == nil then
    if state.hide == false then
      state.win = vim.api.nvim_open_win(state.bufh, false, ui_config)
    end
  else
    vim.api.nvim_win_set_config(state.win, ui_config)
  end

  state.win_height = ui_config.height
end

function M.apm_start()
  if state.active then
    M.resize()
    return
  end

  local function create_apm_buckets()
    local bucket_options = {
      total = 180,
      interval = 5,
    }
    return Buckets:new(bucket_options)
  end

  state.active = true
  state.hide = false
  M.resize()

  state.buckets = {
    insert = create_apm_buckets(),
    normal = create_apm_buckets(),
    total = create_apm_buckets(),
    recent = Buckets:new {
      total = 5,
      interval = 1,
    },
  }

  state.timer = vim.loop.new_timer()
  state.timer:start(1000, 1000, vim.schedule_wrap(tick))
  state.ns = vim.api.nvim_create_namespace('apm.nvim')

  vim.on_key(key_stroke, state.ns)
end

function M.apm_stop()
  if state.win ~= nil then
    vim.api.nvim_win_close(state.win, true)
  end

  if state.timer ~= nil then
    state.timer:stop()
  end

  if state.bufh ~= nil then
    vim.cmd(string.format('bdelete! %s', state.bufh))
  end

  state.buckets = nil
  state.bufh = nil
  state.win = nil

  if state.ns ~= nil then
    vim.on_key(nil, state.ns)
  end

  state.active = false
end

function M.win_close(win)
  if state.win == tonumber(win) then
    state.win = nil
  end
end

function M.apm_toggle()
  if state.active ~= true then
    M.apm_start()
    return
  end

  state.hide = not state.hide
  if state.hide == true then
    if state.win ~= nil then
      vim.api.nvim_win_close(state.win, true)
    end
  else
    M.resize()
  end
end

return M
