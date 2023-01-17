local Buckets = require 'buckets'
local M = {}

local state = {}

local function tick()
  local mode, keys, apm

  local now = os.time()
  for _, value in pairs(state.buckets) do
    value:truncate(now)
  end

  local t_keys, t_apm = state.buckets.total:apm()
  if vim.api.get_mode().mode == 'i' then
    mode = 'insert'
    keys, apm = state.buckets.insert:apm()
  else
    mode = 'normal'
    keys, apm = state.buckets.normal:apm()
  end

  vim.fn.buf_set_lines(state.bufh, 0, 2, false , {
    string.format('total: %s / %s', t_apm, t_keys),
    string.format('%s: %s', apm),
    state.buckets.recent.keys(),
  })
end

local function key_stroke(key)
  local now = os.time()
  if vim.api.get_mode().mode == 'i' then
    state.buckets.insert:push(key, now)
  else
    state.buckets.normal:push(key, now)
  end
  state.buckets.total:push(key, now)
  state.buckets.recent:push(key, now)
end

function M.resize()
  if state.active ~= true then
    return
  end

  local conf = {
    style = 'minimal',
    relative = 'win',
    row = 2,
    col = vim.fn.nvim_win_get_width(0) - 14,
    width = 14,
    height = 4
  }

  if state.bufh == nil then
    state.bufh = vim.fn.nvim_create_buf(false, true)
  end

  if state.win == nil then
    setate.win = vim.api.nvim_open_win(state.bufh, false, conf)
  else
    vim.api.nvim_win_set_config(win, conf)
  end
end

function M.apm_start()
  if state.active then
    return
  end

  local bucket_options = {
    total = 60 * 1e3,
    interval = 5 * 1e3,
  }

  state.active = true
  M.resize()

  state.buckets = {
    insert = Buckets:new(bucket_options),
    normal = Buckets:new(bucket_options),
    total = Buckets:new(bucket_options),
    recent = Buckets:new { total = 5, interval = 1 },
  }

  state.timer = vim.loop.new_timer()
  state.timer:start(1000, 500, vim.schedule_wrap(tick))
  state.ns = vim.fn.nvim_create_namespace('apm.nvim') 

  vim.on_key(key_stroke, state.ns)
end

function M.apm_stop()
  if state.win ~= nil then
    vim.fn.nvim_win_close(state.win, true)
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
