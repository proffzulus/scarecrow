-- Priority Queue implementation
-- Adapted from https://gist.github.com/LukeMS/89dc587abd786f92d60886f4977b1953
-- Simplified for scarecrow fuel management

local math_floor = math.floor

local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

setmetatable(
  PriorityQueue,
  {
    __call = function (self, data)
      if not data then data = {} end
      setmetatable(data, self)
      if not data.heap then
        data:initialize()
      end
      return data
    end
  }
)

function PriorityQueue:initialize()
  self.heap = {}
  self.current_size = 0
end

function PriorityQueue:empty()
  return self.current_size == 0
end

function PriorityQueue:size()
  return self.current_size
end

function PriorityQueue:swim()
  -- Swim up on the tree and fix the order heap property
  local heap = self.heap
  local floor = math_floor
  local i = self.current_size

  while floor(i / 2) > 0 do
    local half = floor(i / 2)
    if heap[i][2] < heap[half][2] then
      heap[i], heap[half] = heap[half], heap[i]
    end
    i = half
  end
end

function PriorityQueue:put(v, p)
  -- Put an item on the queue
  -- v: the item to be stored
  -- p: the priority of the item (number)
  self.heap[self.current_size + 1] = {v, p}
  self.current_size = self.current_size + 1
  self:swim()
end

function PriorityQueue:sink()
  -- Sink down on the tree and fix the order heap property
  local size = self.current_size
  local heap = self.heap
  local i = 1

  while (i * 2) <= size do
    local mc = self:min_child(i)
    if heap[i][2] > heap[mc][2] then
      heap[i], heap[mc] = heap[mc], heap[i]
    end
    i = mc
  end
end

function PriorityQueue:min_child(i)
  if (i * 2) + 1 > self.current_size then
    return i * 2
  else
    if self.heap[i * 2][2] < self.heap[i * 2 + 1][2] then
      return i * 2
    else
      return i * 2 + 1
    end
  end
end

function PriorityQueue:pop()
  -- Remove and return the top priority item
  local heap = self.heap
  local retval = heap[1][1]
  heap[1] = heap[self.current_size]
  heap[self.current_size] = nil
  self.current_size = self.current_size - 1
  self:sink()
  return retval
end

function PriorityQueue:peek()
  -- Return the top priority item without removing it
  if self.current_size == 0 then
    return nil
  end
  return self.heap[1][1]
end

return PriorityQueue
