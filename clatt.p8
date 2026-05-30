pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

LEFT = 0
RIGHT = 1
UP = 2
DOWN = 3
BTN_Z = 4
BTN_X = 5

TILE_WIDTH = 8

WORLD_WIDTH = 16
WORLD_HEIGHT = 16

local Direction = {
  LEFT = 0,
  RIGHT = 1,
  UP = 2,
  DOWN = 3,
}

local TileId = {
  WALL = 0,
  ENEMY = 2,
  CURSOR = 4,
  EXIT = 6,
  ENTRANCE = 7,
}

local TileType = {
  EMPTY = 0,
  WALL = 1,
  EXIT = 2,
  ENTRANCE = 3,
}

time = 0

cursor_pos = {
  x = 0,
  y = 0,
}

button_timers = { 0, 0, 0, 0, 0, 0 }

START_POS = {
  x = 1,
  y = 0,
}

END_POS = {
  x = WORLD_WIDTH - 1,
  y = WORLD_HEIGHT - 1,
}
OFFSCREEN_END_POS = {
  x = WORLD_WIDTH - 1,
  y = WORLD_HEIGHT,
}

MAX_ENEMIES = 16
enemies = {}

function Index(x, y)
  return x + y * WORLD_WIDTH + 1
end

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
    dx = dx,
    dy = dy,
  }
end

function PosAfter(pos, dir)
  local delta = DirDelta(dir)
  return {
    x = pos.x + delta.dx,
    y = pos.y + delta.dy,
  }
end

function PosEq(p1, p2)
  return p1.x == p2.x and p1.y == p2.y
end

function MakeGrid()
  local grid = {}
  for y = 0, WORLD_HEIGHT - 1 do
    for x = 0, WORLD_WIDTH - 1 do
      grid[Index(x, y)] = TileType.EMPTY
    end
  end

  grid[PosIndex(START_POS)] = TileType.ENTRANCE
  grid[PosIndex(END_POS)] = TileType.EXIT

  return grid
end

grid = MakeGrid()

function MakeEnemy(i)
  local enemy = {
    direction = Direction.DOWN,
    to_tile = START_POS,
  }

  local MAX_PROGRESS = 16
  local progress = 0

  local function update_dir()
    local dx = END_POS.x - enemy.to_tile.x
    local dy = END_POS.y - enemy.to_tile.y
    if abs(dx) > abs(dy) then
      if dx < 0 then
        enemy.direction = Direction.LEFT
      else
        enemy.direction = Direction.RIGHT
      end
    else
      if dy < 0 then
        enemy.direction = Direction.UP
      else
        enemy.direction = Direction.DOWN
      end
    end
  end

  function enemy.update()
    progress += 1
    if progress == MAX_PROGRESS then
      progress = 0

      if PosEq(enemy.to_tile, END_POS) then
        enemy.direction = Direction.DOWN
      elseif PosEq(enemy.to_tile, OFFSCREEN_END_POS) then
        enemies[i] = nil
        return
      else
        update_dir()
      end
      
      enemy.to_tile = PosAfter(enemy.to_tile, enemy.direction)
    end
  end

  function enemy.draw()
    local x = enemy.to_tile.x * TILE_WIDTH
    local y = enemy.to_tile.y * TILE_WIDTH
    local delta = DirDelta(enemy.direction)
    x -= delta.dx * (MAX_PROGRESS - progress - 1) * TILE_WIDTH / MAX_PROGRESS
    y -= delta.dy * (MAX_PROGRESS - progress - 1) * TILE_WIDTH / MAX_PROGRESS

    local id = TileId.ENEMY + (time / 4) % 2
    local flip_x = FALSE
    local flip_y = FALSE
    if enemy.direction == Direction.LEFT then
      id += 16
      flip_x = TRUE
    elseif enemy.direction == Direction.RIGHT then
      id += 16
    elseif enemy.direction == Direction.UP then
      flip_y = TRUE
    end

    spr(id, x, y, 1, 1, flip_x, flip_y)
  end

  return enemy
end

function UpdateCursor()
  local FREQ = 4

  for i, timer in ipairs(button_timers) do
    button_timers[i] = max(button_timers[i] - 1, 0)
  end

  function Pressed(button)
    local pressed = btn(button) and button_timers[button + 1] == 0
    if pressed then
      button_timers[button + 1] = FREQ
    end
    return pressed
  end

  if Pressed(LEFT) then
    cursor_pos.x = max(cursor_pos.x - 1, 0)
  end
  if Pressed(RIGHT) then
    cursor_pos.x = min(cursor_pos.x + 1, 15)
  end
  if Pressed(UP) then
    cursor_pos.y = max(cursor_pos.y - 1, 0)
  end
  if Pressed(DOWN) then
    cursor_pos.y = min(cursor_pos.y + 1, 15)
  end

  if Pressed(BTN_Z) then
    local index = PosIndex(cursor_pos)
    local wall_type = grid[index]
    if wall_type == TileType.EMPTY then
      grid[index] = TileType.WALL
    elseif wall_type == TileType.WALL then
      grid[index] = TileType.EMPTY
    end
  end
end

function DrawCursor()
  local i = (time / 15) % 2
  local x = cursor_pos.x * TILE_WIDTH
  local y = cursor_pos.y * TILE_WIDTH
  spr(TileId.CURSOR + i, x, y)
end

function DrawGrid()
  for y = 0, WORLD_HEIGHT - 1 do
    for x = 0, WORLD_WIDTH - 1 do
      local tile = grid[Index(x, y)]
      local id
      if tile == TileType.WALL then
        id = TileId.WALL + (x + y) % 2
      elseif tile == TileType.ENTRANCE then
        id = TileId.ENTRANCE
      elseif tile == TileType.EXIT then
        id = TileId.EXIT
      else
        assert(tile == TileType.EMPTY)
        goto continue
      end
      spr(id, x * TILE_WIDTH, y * TILE_WIDTH)

      ::continue::
    end
  end
end

function UpdateEnemies()
  for _, enemy in pairs(enemies) do
    enemy.update()
  end

  if time % 100 == 99 then
    for i = 1, MAX_ENEMIES do
      if enemies[i] == nil then
        enemies[i] = MakeEnemy(i)
        break
      end
    end
  end
end

function DrawEnemies()
  for _, enemy in pairs(enemies) do
    enemy.draw()
  end
end

function _update()
  UpdateCursor()
  UpdateEnemies()
  time += 1
end

function _draw()
  cls(0)
  DrawGrid()
  DrawEnemies()
  DrawCursor()
end

__gfx__
00000000000000000000000000000000770770777700007700000000022222200000000000000000000000000000000000000000000000000000000000000000
60606060606060600000000000600600700000077000000700333300022222200000000000000000000000000000000000000000000000000000000000000000
666666666666666600600600006006000000000000000000033bb330022882200000000000000000000000000000000000000000000000000000000000000000
66066086606606600006600000600600700000070000000003bbbb30028888200000000000000000000000000000000000000000000000000000000000000000
60660686660668660160061001600610700000070000000003bbbb30028888200000000000000000000000000000000000000000000000000000000000000000
660660866066086000111100001111000000000000000000033bb330022882200000000000000000000000000000000000000000000000000000000000000000
60668688668668660000000000000000700000077000000703333330002222000000000000000000000000000000000000000000000000000000000000000000
66068088608608800000000000000000770770777700007703333330000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000010000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006061000666610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000601000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000601000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006061000666610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000010000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
