local ListNode = require 'list'
local Buckets = {}

local function buckets_truncate(buckets, now)
  if buckets.tail == nil then
    return
  end

  local node = buckets.head
  local new_head = nil
  while node ~= nil do
    local time = node.data.time
    if now - time < buckets.total then
      new_head = node
      break
    end
    node = node.next
  end

  if new_head == nil then
    buckets.tail = nil
  end
  buckets.head = new_head
end

local function buckets_push_key(buckets, key, now)
  local last = buckets.last
  if now - last.data.time > buckets.interval then
    local node = ListNode:new {
      data = {
        time = now,
        keys = {},
      }
    }

    local _keys = {}
    for _, _key in ipairs(last.data.keys) do
      table.insert(_keys, _key)
    end
    last.data.squash = table.concat(_keys)
    last.data.n_keys = #last.data.keys
    last.data.keys = nil

    last.next = node
    last = node
  end

  local keys = last.data.keys
  table.insert(keys, key)

  buckets.last = last
end

local function buckets_calc_apm(buckets, now)
  local elapsed = buckets.interval -- sentinel
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

  return strokes / (elapsed / 6e4)
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
  total = 30 * 1e3,
  interval = 10 * 1e3,
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

