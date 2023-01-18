local Buckets = require 'nvim-apm.buckets'
local M = {}

---@diagnostic disable-next-line: lowercase-global
vim = vim or {} -- make compiler happy

local state = {}

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

  vim.api.nvim_buf_set_lines(state.bufh, 0, 2, false , {
    string.format('t: %s', t_apm),
    string.format('%s: %s', mode, apm),
  })
end

local function key_stroke(key)
  local now = os.time()
  key = vim.fn.keytrans(key)

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

  vim.api.nvim_buf_set_lines(state.bufh, 2, 3, false , {
    state.buckets.recent:keys(),
  })
end

function M.resize()
  if state.active ~= true then
    return
  end

  local conf = {
    style = 'minimal',
    relative = 'win',
    row = 2,
    col = vim.api.nvim_win_get_width(0) - 14,
    width = 14,
    height = 3
  }

  if state.bufh == nil then
    state.bufh = vim.api.nvim_create_buf(false, true)
  end

  if state.win == nil then
    state.win = vim.api.nvim_open_win(state.bufh, false, conf)
  else
    vim.api.nvim_win_set_config(state.win, conf)
  end
end

function M.apm_start()
  if state.active then
    return
  end

  local bucket_options = {
    total = 60,
    interval = 5,
  }

  state.active = true
  M.resize()

  state.buckets = {
    insert = Buckets:new(bucket_options),
    normal = Buckets:new(bucket_options),
    total = Buckets:new(bucket_options),
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

return M
