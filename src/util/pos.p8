pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
PosMeta = {}

PosMeta.__add = function(lhs, rhs)
  return setmetatable(
    {
      x = lhs.x + rhs.x,
      y = lhs.y + rhs.y
    },
    PosMeta
  )
end

PosMeta.__sub = function(lhs, rhs)
  return setmetatable(
    {
      x = lhs.x - rhs.x,
      y = lhs.y - rhs.y
    },
    PosMeta
  )
end

function MakePos(x, y)
  return setmetatable(
    {
      x = x,
      y = y
    }, PosMeta
  )
end

function PosIndex(pos)
  return pos.x + pos.y * WORLD_WIDTH + 1
end

function DirDelta(dir)
  local dx = 0
  local dy = 0
  if dir == Direction.LEFT then
    dx = -1
  elseif dir == Direction.RIGHT then
    dx = 1
  elseif dir == Direction.UP then
    dy = -1
  else
    assert(dir == Direction.DOWN)
    dy = 1
  end
  return MakePos(dx, dy)
end

function PosAfter(pos, dir)
  local delta = DirDelta(dir)
  return MakePos(pos.x + delta.x, pos.y + delta.y)
end

function PosEq(p1, p2)
  return p1.x == p2.x and p1.y == p2.y
end

function PosInBounds(pos)
  return pos.x >= 0 and pos.x < WORLD_WIDTH and pos.y >= 0 and pos.y < WORLD_HEIGHT
end

function PosScale(pos, scale)
  return MakePos(pos.x * scale, pos.y * scale)
end

function PosMagnitude(pos)
  return sqrt(pos.x * pos.x + pos.y * pos.y)
end

function PosNormalize(pos)
  return PosScale(pos, 1 / PosMagnitude(pos))
end
