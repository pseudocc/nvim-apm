local ListNode = {}

ListNode.prototype = {
  data = nil,
  next = nil
}

ListNode.metatable = { __index = ListNode.prototype }

function ListNode:new(obj)
  obj = obj or {}
  setmetatable(obj, self.metatable)
  return obj
end

return ListNode
