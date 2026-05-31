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

Direction = {
  LEFT = 0,
  RIGHT = 1,
  UP = 2,
  DOWN = 3,
}

TileSpriteId = {
  WALL = 0,
  ENEMY = 2,
  CURSOR = 4,
  EXIT = 6,
  ENTRANCE = 7,
  ARCHER = 8,
  ARROW = 9,
}

TileType = {
  EMPTY = 0,
  WALL = 1,
  EXIT = 2,
  ENTRANCE = 3,
  -- A phony tile for enemies to "reserve", prevenging other tiles from being
  -- placed. --clayDawg
  ENEMY_HOLD = 4,
  ARCHER = 5,
}

selected_tower = TileType.WALL

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
      distance = 0,
    })
    local path_map = {}

    while true do
      local item = queue.pop()
      if item == nil then
        break
      end

      local index = PosIndex(item.pos)

      if path_map[index] == nil then
        path_map[index] = {
          dir = item.dir,
          distance = item.distance,
        }

        for _, dir in pairs(Direction) do
          local next_pos = PosAfter(item.pos, dir)
          if PosInBounds(next_pos) and EnemyCanOccupyPos(next_pos) then
            queue.push({
              pos = next_pos,
              dir = OppositeDir(dir),
              distance = item.distance + 1,
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
    path_info = enemy_path_map[PosIndex(pos)]
    if path_info == nil then
      return nil
    end
    return path_info.dir
  end

  function grid.distance_to_end(pos)
    if enemy_path_map == nil then
      enemy_path_map = BuildEnemyPathMap()
    end
    path_info = enemy_path_map[PosIndex(pos)]
    if path_info == nil then
      return nil
    end
    return path_info.distance
  end

  return grid
end

grid = MakeGrid()

function MakeArrow(start_pos, target_pos)
  local arrow = {}

  local dt = 0

  local delta = PosSub(target_pos, start_pos)
  local distance = PosMagnitude(delta)
  local delta_dir = PosNormalize(delta)

  function arrow.update()
    local result = {
      should_erase = false,
    }

    if dt > distance then
      result.should_erase = true
      return result
    end

    dt += 1
    return result
  end

  -- Not local since it does not capture anything
  function arrow_sprite(dir)
    local flip_x = false
    local flip_y = false
    local dx = dir.x
    local dy = dir.y
    if dx < 0 then
      dx = -dx
      flip_x = true
    end
    if dy < 0 then
      dy = -dy
      flip_y = true
    end

    local id
    if dy < 0.256 * dx then
      id = TileSpriteId.ARROW
    elseif dy < 0.666 * dx then
      id = TileSpriteId.ARROW + 1
    elseif dx < 0.256 * dy then
      id = TileSpriteId.ARROW + 3
    else
      id = TileSpriteId.ARROW + 2
    end

    return {
      id = id,
      flip_x = flip_x,
      flip_y = flip_y,
    }
  end

  function arrow.draw()
    local pos = PosAdd(start_pos, PosScale(delta_dir, dt))
    local sprite = arrow_sprite(delta_dir)
    spr(sprite.id, pos.x, pos.y, 1, 1, sprite.flip_x, sprite.flip_y)
  end

  return arrow
end

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

function MakeEnemy()
  local enemy = {}

  local direction = Direction.DOWN
  local to_tile = START_POS

  local MAX_PROGRESS = 16
  local progress = 0

  enemy_hold_map.occupy(to_tile)

  function enemy.update()
    local result = {
      should_erase = false,
    }

    progress += 1
    if progress ~= MAX_PROGRESS then
      return result
    end

    progress = 0

    local from_tile = to_tile
    local prev_from_tile = PosAfter(from_tile, OppositeDir(direction))

    if PosEq(from_tile, END_POS) then
      direction = Direction.DOWN
    elseif PosEq(from_tile, OFFSCREEN_END_POS) then
      result.should_erase = true
      return result
    else
      local dir = grid.enemy_dir_at(from_tile)
      assert(dir ~= nil)
      direction = dir
    end

    to_tile = PosAfter(from_tile, direction)

    enemy_hold_map.vacate(prev_from_tile)
    enemy_hold_map.occupy(to_tile)

    return result
  end

  function enemy.draw()
    local x = to_tile.x * TILE_WIDTH
    local y = to_tile.y * TILE_WIDTH
    local delta = DirDelta(direction)
    x -= delta.dx * (MAX_PROGRESS - progress - 1) * TILE_WIDTH / MAX_PROGRESS
    y -= delta.dy * (MAX_PROGRESS - progress - 1) * TILE_WIDTH / MAX_PROGRESS

    local id = TileSpriteId.ENEMY + (time / 4) % 2
    local flip_x = false
    local flip_y = false
    if direction == Direction.LEFT then
      id += 16
      flip_x = true
    elseif direction == Direction.RIGHT then
      id += 16
    elseif direction == Direction.UP then
      flip_y = true
    end

    spr(id, x, y, 1, 1, flip_x, flip_y)
  end

  return enemy
end

function MakeEntityMap()
  entity_map = {}
  
  local MAX_ENTITIES = 16
  local entities = {}

  function entity_map.try_spawn(make_entity)
    for i = 1, MAX_ENTITIES do
      if entities[i] == nil then
        entities[i] = make_entity()
        return true
      end
    end
    return false
  end

  function entity_map.update()
    for i, entity in pairs(entities) do
      local result = entity.update()
      if result.should_erase then
        entities[i] = nil
      end
    end
  end

  function entity_map.draw()
    for _, entity in pairs(entities) do
      entity.draw()
    end
  end

  return entity_map
end

entity_map = MakeEntityMap()

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

  -- Place tower
  if Pressed(BTN_Z) then
    local grid_tile_type = grid.tile(cursor_pos)
    local selected_tower_type = selected_tower

    if grid_tile_type == TileType.EMPTY then
      grid.try_set_tile(cursor_pos, selected_tower_type)
    elseif grid_tile_type == selected_tower_type then
      grid.try_set_tile(cursor_pos, TileType.EMPTY)
    end
  end

  -- Scroll to next tower option
  if Pressed(BTN_X) then
    if selected_tower == TileType.WALL then
      selected_tower = TileType.ARCHER
    else
      assert(selected_tower == TileType.ARCHER)
      selected_tower = TileType.WALL
    end
  end 
end

function DrawCursor()
  local i = (time / 15) % 2
  local x = cursor_pos.x * TILE_WIDTH
  local y = cursor_pos.y * TILE_WIDTH
  spr(TileSpriteId.CURSOR + i, x, y)
end

function DrawGrid()
  for y = 0, WORLD_HEIGHT - 1 do
    for x = 0, WORLD_WIDTH - 1 do
      local tile = grid.tile({ x = x, y = y })
      local id
      if tile == TileType.WALL then
        id = TileSpriteId.WALL + (x + y) % 2
      elseif tile == TileType.ENTRANCE then
        id = TileSpriteId.ENTRANCE
      elseif tile == TileType.EXIT then
        id = TileSpriteId.EXIT
      elseif tile == TileType.ARCHER then
        id = TileSpriteId.ARCHER
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

function UpdateEntities()
  entity_map.update()

  if time % 100 == 99 then
    entity_map.try_spawn(MakeEnemy)
  end
end

function DrawEntities()
  entity_map.draw()
end

function _update()
  UpdateCursor()
  UpdateEntities()
  -- UpdateTowers()
  time += 1
end

function _draw()
  cls(0)
  DrawGrid()
  DrawEntities()
  DrawCursor()
end

function Initialize()
  music(0)
end

Initialize()

__gfx__
00000000000000000000000000000000770770777700007700000000022222200000000000000000000000000000000000000000000000000000000000000000
60606060606060600000000000600600700000077000000700333300022222200000000000000000000000000000000000000000000000000000000000000000
666666666666666600600600006006000000000000000000033bb330022882200505005000000000000000000004000000004000000000000000000000000000
66066086606606600006600000600600700000070000000003bbbb30028888200555555000000000004000000000400000004000000000000000000000000000
60660686660668660160061001600610700000070000000003bbbb30028888200044440000444500000440000000400000004000000000000000000000000000
660660866066086000111100001111000000000000000000033bb330022882200042240000000000000005000000050000005000000000000000000000000000
60668688668668660000000000000000700000077000000703333330002222000449944000000000000000000000000000000000000000000000000000000000
66068088608608800000000000000000770770777700007703333330000000000449944000000000000000000000000000000000000000000000000000000000
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
__sfx__
011000001d1501d1501d1501d1552115523155241552914029140291402914029145000002510029140000002d130000002b14029140291402914029140291450000000000000000000000000000000000000000
011000000c6000000000000000000c655000000000000000000000000000000000000c655000000000000000000000000000000000000c65500000000000000000000000000c6450c6450c605000000c65500000
01100000150501505015050150500000015055130551105011050110501105011055000000000011050000000c0500c0500c0500c0500c0550c0000c050000001105011050110501105011055000000000000000
01100000187501875018750187501870518755167551575015750157501575015750157550c000157501800013750137501375013750137551800013755180001575015750157501575015755000000000000000
011000002115021150211500010021150221502415026150261502615026150241002415024150241500010029150291502915029150291502915029150291550000000000000000000000000000000000000000
011000001805018050180501805509000180501605015050150501505015055000001305013050130550000011050110501105011050110501105011050110550000000000110500c05011050000001105000000
011000001d7501d7501d7501d750000001d750187501d7501d7501d7501d755000001c7501c7501c7550000021750217502175021750217502175021750217550000000000217501f75021750180002175000000
01100000150501505015050150500000015050130501105011050110501105011050110500000011050000000e050000000e0500a0500a0500a0500a0500a05500000000000a0500e0500c050000000c05000000
01100000187501875018750187500000018755167551575015750157501575015750157500000015750000001175000000167501a7501a7501a7501a7501a75500000000001a7501d7501c750180001c75000000
0110000007050070500705007050070500000007050000000c0500c0500c0500c0000c0500c0500c0500000011050110501105011050110501105011050110550000000000110500c05011050000001105000000
011000001a7501a7501a7501a7501a750000001a750000001f7501f7501f750180002275022750227500000021750217502175021750217502175021750217550000000000217501f7501d750180001d75000000
__music__
01 00010203
00 04010506
00 00010708
02 0401090a

