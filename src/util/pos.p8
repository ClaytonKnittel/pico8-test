function PosIndex(pos)
  return Index(pos.x, pos.y)
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
  return {
    x = dx,
    y = dy,
  }
end

function PosAfter(pos, dir)
  local delta = DirDelta(dir)
  return {
    x = pos.x + delta.x,
    y = pos.y + delta.y,
  }
end

function PosEq(p1, p2)
  return p1.x == p2.x and p1.y == p2.y
end

function PosInBounds(pos)
  return pos.x >= 0 and pos.x < WORLD_WIDTH and pos.y >= 0 and pos.y < WORLD_HEIGHT
end

function PosAdd(pos1, pos2)
  return {
    x = pos1.x + pos2.x,
    y = pos1.y + pos2.y,
  }
end

function PosSub(pos1, pos2)
  return {
    x = pos1.x - pos2.x,
    y = pos1.y - pos2.y,
  }
end

function PosScale(pos, scale)
  return {
    x = pos.x * scale,
    y = pos.y * scale,
  }
end

function PosMagnitude(pos)
  return sqrt(pos.x * pos.x + pos.y * pos.y)
end

function PosNormalize(pos)
  return PosScale(pos, 1 / PosMagnitude(pos))
end
