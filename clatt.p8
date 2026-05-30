pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

DEBUG = false

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
  -- A phony tile for enemies to "reserve", prevenging other tiles from being
  -- placed.
  ENEMY_HOLD = 4,
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

function OppositeDir(dir)
  if dir == Direction.LEFT then
    return Direction.RIGHT
  elseif dir == Direction.RIGHT then
    return Direction.LEFT
  elseif dir == Direction.UP then
    return Direction.DOWN
  else
    assert(dir == Direction.DOWN)
    return Direction.UP
  end
end

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

function PosInBounds(pos)
  return pos.x >= 0 and pos.x < WORLD_WIDTH and pos.y >= 0 and pos.y < WORLD_HEIGHT
end

function EnemyCanOccupyPos(pos)
  local tile = grid.tile(pos)
  return tile == TileType.EMPTY
      or tile == TileType.ENTRANCE
      or tile == TileType.EXIT
      or tile == TileType.ENEMY_HOLD
end

function MakeQueue()
  local queue = {}

  local front = 0
  local back = 0

  function queue.pop()
    assert(front <= back)
    if front == back then
      return nil
    else
      result = queue[front]
      queue[front] = nil
      front += 1
      return result
    end
  end

  function queue.push(item)
    queue[back] = item
    back += 1
  end

  return queue
end

function MakeGrid()
  local grid = {}

  local tiles = {}
  local enemy_path_map = nil

  for y = 0, WORLD_HEIGHT - 1 do
    for x = 0, WORLD_WIDTH - 1 do
      tiles[Index(x, y)] = TileType.EMPTY
    end
  end

  tiles[PosIndex(START_POS)] = TileType.ENTRANCE
  tiles[PosIndex(END_POS)] = TileType.EXIT

  local function BuildEnemyPathMap()
    local queue = MakeQueue()
    queue.push({
      pos = END_POS,
      dir = Direction.DOWN,
    })
    local path_map = {}

    while true do
      local item = queue.pop()
      if item == nil then
        break
      end

      local index = PosIndex(item.pos)

      if path_map[index] == nil then
        path_map[index] = item.dir

        for _, dir in pairs(Direction) do
          local next_pos = PosAfter(item.pos, dir)
          if PosInBounds(next_pos) and EnemyCanOccupyPos(next_pos) then
            queue.push({
              pos = next_pos,
              dir = OppositeDir(dir),
            })
          end
        end
      end
    end

    return path_map
  end

  function grid.tile(pos)
    return tiles[PosIndex(pos)]
  end

  local function AllTilesReachableInPathMap(path_map)
    for tile_index in enemy_hold_map.occupied_tiles() do
      if path_map[tile_index] == nil then
        return false
      end
    end

    if path_map[PosIndex(START_POS)] == nil then
      return false
    end

    return true
  end

  function grid.try_set_tile(pos, tile)
    local index = PosIndex(pos)
    local prev_tile = tiles[index]
    tiles[index] = tile
    local new_enemy_path_map = BuildEnemyPathMap()
    if AllTilesReachableInPathMap(new_enemy_path_map) then
      enemy_path_map = new_enemy_path_map
    else
      tiles[index] = prev_tile
    end
  end

  function grid.place_enemy_hold(pos)
    local index = PosIndex(pos)
    local tile = tiles[index]
    if tile == TileType.ENTRANCE or tile == TileType.EXIT then
      return
    end
    assert(tile == TileType.EMPTY)
    tiles[index] = TileType.ENEMY_HOLD
  end

  function grid.remove_enemy_hold(pos)
    local index = PosIndex(pos)
    local tile = tiles[index]
    if tile == TileType.ENTRANCE or tile == TileType.EXIT then
      return
    end
    assert(tile == TileType.ENEMY_HOLD)
    tiles[index] = TileType.EMPTY
  end

  function grid.enemy_dir_at(pos)
    if enemy_path_map == nil then
      enemy_path_map = BuildEnemyPathMap()
    end
    return enemy_path_map[PosIndex(pos)]
  end

  return grid
end

grid = MakeGrid()

function MakeEnemyHoldMap()
  local enemy_hold_map = {}

  local hold_map = {}

  function enemy_hold_map.occupied()
    return hold_map[index] ~= nil
  end

  function enemy_hold_map.occupied_tiles()
    return pairs(hold_map)
  end

  function enemy_hold_map.occupy(pos)
    if not PosInBounds(pos) then
      return
    end

    local index = PosIndex(pos)
    if hold_map[index] == nil then
      hold_map[index] = 1
      grid.place_enemy_hold(pos)
    else
      hold_map[index] += 1
    end
  end

  function enemy_hold_map.vacate(pos)
    if not PosInBounds(pos) then
      return
    end

    local index = PosIndex(pos)
    if hold_map[index] == 1 then
      hold_map[index] = nil
      grid.remove_enemy_hold(pos)
    else
      hold_map[index] -= 1
    end
  end

  return enemy_hold_map
end

enemy_hold_map = MakeEnemyHoldMap()

function MakeEnemy(i)
  local enemy = {
    direction = Direction.DOWN,
    to_tile = START_POS,
  }

  local MAX_PROGRESS = 16
  local progress = 0

  enemy_hold_map.occupy(enemy.to_tile)

  function enemy.update()
    local result = {
      should_erase = false,
    }

    progress += 1
    if progress ~= MAX_PROGRESS then
      return result
    end

    progress = 0

    local from_tile = enemy.to_tile
    local prev_from_tile = PosAfter(from_tile, OppositeDir(enemy.direction))

    if PosEq(from_tile, END_POS) then
      enemy.direction = Direction.DOWN
    elseif PosEq(from_tile, OFFSCREEN_END_POS) then
      result.should_erase = true
      return result
    else
      local dir = grid.enemy_dir_at(from_tile)
      assert(dir ~= nil)
      enemy.direction = dir
    end

    enemy.to_tile = PosAfter(from_tile, enemy.direction)

    enemy_hold_map.vacate(prev_from_tile)
    enemy_hold_map.occupy(enemy.to_tile)

    return result
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

function MakeEnemyMap()
  enemy_map = {}
  
  local MAX_ENEMIES = 16
  local enemies = {}

  function enemy_map.try_spawn_at_entrance()
    for i = 1, MAX_ENEMIES do
      if enemies[i] == nil then
        enemies[i] = MakeEnemy(i)
        return true
      end
    end
    return false
  end

  function enemy_map.update()
    for i, enemy in pairs(enemies) do
      local result = enemy.update()
      if result.should_erase then
        enemies[i] = nil
      end
    end
  end

  function enemy_map.draw()
    for _, enemy in pairs(enemies) do
      enemy.draw()
    end
  end

  return enemy_map
end

enemy_map = MakeEnemyMap()

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
    local wall_type = grid.tile(cursor_pos)
    if wall_type == TileType.EMPTY then
      grid.try_set_tile(cursor_pos, TileType.WALL)
    elseif wall_type == TileType.WALL then
      grid.try_set_tile(cursor_pos, TileType.EMPTY)
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
      local tile = grid.tile({ x = x, y = y })
      local id
      if tile == TileType.WALL then
        id = TileId.WALL + (x + y) % 2
      elseif tile == TileType.ENTRANCE then
        id = TileId.ENTRANCE
      elseif tile == TileType.EXIT then
        id = TileId.EXIT
      elseif tile == TileType.ENEMY_HOLD then
        id = 36
      else
        assert(tile == TileType.EMPTY)
        local dir = grid.enemy_dir_at({ x = x, y = y })
        if dir == Direction.LEFT then
          id = 32
        elseif dir == Direction.RIGHT then
          id = 33
        elseif dir == Direction.UP then
          id = 34
        elseif dir == Direction.DOWN then
          id = 35
        else
          assert(dir == nil)
          goto continue
        end

        -- goto continue
      end

      if not DEBUG and id >= 32 then
        goto continue
      end

      spr(id, x * TILE_WIDTH, y * TILE_WIDTH)

      ::continue::
    end
  end
end

function UpdateEnemies()
  enemy_map.update()

  if time % 100 == 99 then
    enemy_map.try_spawn_at_entrance()
  end
end

function DrawEnemies()
  enemy_map.draw()
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006660000060060000666000006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006006000060060000600600006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006660000060060000600600006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006060000060060000600600006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666600006006000006660000666000006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
