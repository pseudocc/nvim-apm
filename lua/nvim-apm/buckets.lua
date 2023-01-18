local ListNode = require 'nvim-apm.list'
local Buckets = {}

local function buckets_truncate(buckets, now)
  if buckets.tail == nil then
    return
  end

  local node = buckets.head
  local first = nil
  while node ~= nil do
    local time = node.data.time
    if now - time < buckets.total then
      first = node
      break
    end
    node = node.next
  end

  if first == nil then
    buckets.tail = nil
  end
  buckets.head = first
end

local function buckets_push_key(buckets, key, now)
  local last = buckets.tail
  if last == nil or now - last.data.time > buckets.interval then
    local node = ListNode:new {
      data = {
        time = now,
        keys = {},
      }
    }

    if last ~= nil then
      local _keys = {}
      for _, _key in ipairs(last.data.keys) do
        table.insert(_keys, _key)
      end
      last.data.squash = table.concat(_keys)
      last.data.n_keys = #last.data.keys
      last.data.keys = nil
      last.next = node
    else
      buckets.head = node
    end

    last = node
  end

  local keys = last.data.keys
  table.insert(keys, key)

  buckets.tail = last
end

local function buckets_calc_apm(buckets, now)
  local elapsed = 0
  local node = buckets.head
  if node ~= nil then
    elapsed = now - node.data.time
  end

  local strokes = 0
  while node ~= nil do
    if node.data.keys ~= nil then
      strokes = strokes + #node.data.keys
    else
      strokes = strokes + node.data.n_keys
    end
    node = node.next
  end

  if elapsed == 0 then
    elapsed = buckets.interval
  end

  local apm = strokes / (elapsed / 60)
  return math.floor(apm)
end

local function buckets_dump_keys(buckets)
  local keys = {}
  local node = buckets.head

  while node ~= nil do
    if node.data.squash ~= nil then
      table.insert(keys, node.data.squash)
    else
      local _keys = {}
      for _, _key in ipairs(node.data.keys) do
        table.insert(_keys, _key)
      end
      table.insert(keys, table.concat(_keys))
    end
    node = node.next
  end

  return table.concat(keys)
end

Buckets.prototype = {
  total = 30,
  interval = 10,
  truncate = buckets_truncate,
  push = buckets_push_key,
  keys = buckets_dump_keys,
  apm = buckets_calc_apm,
}

Buckets.metatable = { __index = Buckets.prototype }

function Buckets:new(obj)
  obj = obj or {}
  obj.head = nil
  obj.tail = nil

  setmetatable(obj, self.metatable)
  return obj
end

return Buckets
