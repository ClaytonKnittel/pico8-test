pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

DEBUG = true
DEBUG_DISPLAY_DIR_MAP = false

LEFT = 0
RIGHT = 1
UP = 2
DOWN = 3
BTN_Z = 4
BTN_X = 5

TILE_WIDTH = 8

WORLD_WIDTH = 16
WORLD_HEIGHT = 14

Direction = {
  LEFT = 0,
  RIGHT = 1,
  UP = 2,
  DOWN = 3,
}

TileSpriteId = {
  WALL = 0,
  JELLYFISH = 2,
  CURSOR = 4,
  EXIT = 6,
  ENTRANCE = 7,
  ARCHER = 8,
  ARROW = 9,
  PINWHEEL = 13,
  LIGHTNING = 14,
  HUD_BG = 15,
  WIZARD = 32,
  HUD_BORDER = 48,
}

TypeId = {
  EMPTY = 0,
  WALL = 1,
  EXIT = 2,
  ENTRANCE = 3,
  -- A phony tile for enemies to "reserve", prevenging other tiles from being
  -- placed. --clayDawg
  ENEMY_HOLD = 4,
  ARCHER = 5,
  PINWHEEL = 6,
  LIGHTNING = 7,
  JELLYFISH = 8,
  WIZARD = 9,
}

PLACEABLE_TILES = {
  TypeId.WALL,
  TypeId.ARCHER,
  TypeId.PINWHEEL,
  TypeId.LIGHTNING,
}

TILE_TYPE_TO_SPRITE = {
  [TypeId.WALL] = TileSpriteId.WALL,
  [TypeId.ARCHER] = TileSpriteId.ARCHER,
  [TypeId.PINWHEEL] = TileSpriteId.PINWHEEL,
  [TypeId.LIGHTNING] = TileSpriteId.LIGHTNING,
}

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

OPPOSITE_DIR = {
  [Direction.LEFT] = Direction.RIGHT,
  [Direction.RIGHT] = Direction.LEFT,
  [Direction.UP] = Direction.DOWN,
  [Direction.DOWN] = Direction.UP,
}

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

OCCUPIABLE_TILES = {
  [TypeId.EMPTY] = true,
  [TypeId.ENTRANCE] = true,
  [TypeId.EXIT] = true,
  [TypeId.ENEMY_HOLD] = true,
}

function EnemyCanOccupyPos(pos)
  local tile = grid.tile(pos)
  return OCCUPIABLE_TILES[tile]
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

function MakeGrid()
  local grid = {}

  local tiles = {}
  local enemy_dir_map, enemy_distance_map

  for y = 0, WORLD_HEIGHT - 1 do
    for x = 0, WORLD_WIDTH - 1 do
      tiles[Index(x, y)] = TypeId.EMPTY
    end
  end

  tiles[PosIndex(START_POS)] = TypeId.ENTRANCE
  tiles[PosIndex(END_POS)] = TypeId.EXIT

  local function BuildEnemyPathMap()
    local queue = {}
    local q_front = 1
    local q_back = 1

    -- Cache math functions we use
    local abs = abs

    -- Layout: pos, direction, distance
    queue[q_front] = PosIndex(END_POS)
    queue[q_front + 1] = Direction.DOWN
    queue[q_front + 2] = 0
    q_back += 3

    -- We use some bit tricks assuming this is the world width
    assert(WORLD_WIDTH == 16)
    local grid_size = WORLD_WIDTH * WORLD_HEIGHT

    local pos_after_map = {
      [Direction.LEFT] = -1,
      [Direction.RIGHT] = 1,
      [Direction.UP] = -WORLD_WIDTH,
      [Direction.DOWN] = WORLD_WIDTH,
    }

    local dir_map = {}
    local distance_map = {}

    while q_front < q_back do
      local pos_index = queue[q_front]
      local dir = queue[q_front + 1]
      local distance = queue[q_front + 2]
      q_front += 3

      if dir_map[pos_index] == nil then
        dir_map[pos_index] = dir
        distance_map[pos_index] = distance

        for dir = 0, 3 do
          local next_pos = pos_index + pos_after_map[dir]
          -- Check that next_pos is in bounds:
          if abs(((next_pos - 1) & 0xf) - ((pos_index - 1) & 0xf)) <= 1
              and next_pos >= 1 and next_pos <= grid_size then
            local tile = tiles[next_pos]
            if OCCUPIABLE_TILES[tile] then
              queue[q_back] = next_pos
              queue[q_back + 1] = OPPOSITE_DIR[dir]
              queue[q_back + 2] = distance + 1
              q_back += 3
            end
          end
        end
      end
    end

    return dir_map, distance_map
  end

  function grid.tile(pos)
    return tiles[PosIndex(pos)]
  end

  local function AllTilesReachableInPathMap(dir_map)
    for tile_index in enemy_hold_map.occupied_tiles() do
      if dir_map[tile_index] == nil then
        return false
      end
    end

    return dir_map[PosIndex(START_POS)] ~= nil
  end

  function grid.try_set_tile(pos, tile)
    local index = PosIndex(pos)
    local prev_tile = tiles[index]
    tiles[index] = tile
    local dir_map, distance_map = BuildEnemyPathMap()
    if AllTilesReachableInPathMap(dir_map) then
      enemy_dir_map = dir_map
      enemy_distance_map = distance_map
      return true
    else
      tiles[index] = prev_tile
      return false
    end
  end

  function grid.place_enemy_hold(pos)
    local index = PosIndex(pos)
    local tile = tiles[index]
    if tile == TypeId.ENTRANCE or tile == TypeId.EXIT then
      return
    end
    assert(tile == TypeId.EMPTY)
    tiles[index] = TypeId.ENEMY_HOLD
  end

  function grid.remove_enemy_hold(pos)
    local index = PosIndex(pos)
    local tile = tiles[index]
    if tile == TypeId.ENTRANCE or tile == TypeId.EXIT then
      return
    end
    assert(tile == TypeId.ENEMY_HOLD)
    tiles[index] = TypeId.EMPTY
  end

  function grid.enemy_dir_at(pos)
    if enemy_dir_map == nil then
      enemy_dir_map, enemy_distance_map = BuildEnemyPathMap()
    end
    return enemy_dir_map[PosIndex(pos)]
  end

  function grid.distance_to_end(pos)
    if enemy_dir_map == nil then
      enemy_dir_map, enemy_distance_map = BuildEnemyPathMap()
    end
    return enemy_distance_map[PosIndex(pos)]
  end

  return grid
end

ARROW_SPEED = 0.25

function MakeArrow(start_pos, target_pos, damage)
  local arrow = {}

  local dt = 0

  local delta = PosSub(target_pos, start_pos)
  local distance = PosMagnitude(delta)
  local delta_dir = PosNormalize(delta)
  local pos = { x = start_pos.x, y = start_pos.y }

  local hit_enemy = false

  arrow["damage"] = damage

  function arrow.update()
    local result = {
      should_erase = false,
    }

    if arrow.hit_enemy or dt > distance then
      result.should_erase = true
      return result
    end

    dt += ARROW_SPEED

    local new_pos = PosAdd(start_pos, PosScale(delta_dir, dt))
    pos.x = new_pos.x
    pos.y = new_pos.y

    return result
  end

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
    local sprite = arrow_sprite(delta_dir)
    spr(sprite.id, TILE_WIDTH * (pos.x - 0.5), TILE_WIDTH * (pos.y - 0.5), 1, 1, sprite.flip_x, sprite.flip_y)
  end

  function arrow.type_id()
    return TypeId.ARROW
  end

  function arrow.pos()
    return pos
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

ENEMY_INFO_MAP = {
  [TypeId.JELLYFISH] = {
    speed = 0.08,
    animation_data = {
      -- Left
      TileSpriteId.JELLYFISH + 16,
      0x1,
      TileSpriteId.JELLYFISH + 17,
      0x1,
      -- Right
      TileSpriteId.JELLYFISH + 16,
      0x0,
      TileSpriteId.JELLYFISH + 17,
      0x0,
      -- Up
      TileSpriteId.JELLYFISH,
      0x2,
      TileSpriteId.JELLYFISH + 1,
      0x2,
      -- Down
      TileSpriteId.JELLYFISH,
      0x0,
      TileSpriteId.JELLYFISH + 1,
      0x0,
    },
  },
  [TypeId.WIZARD] = {
    speed = 0.06,
    animation_data = {
      -- Left
      TileSpriteId.WIZARD + 1,
      0x0,
      TileSpriteId.WIZARD + 2,
      0x0,
      -- Right
      TileSpriteId.WIZARD + 1,
      0x1,
      TileSpriteId.WIZARD + 2,
      0x1,
      -- Up
      TileSpriteId.WIZARD,
      0x0,
      TileSpriteId.WIZARD,
      0x1,
      -- Down
      TileSpriteId.WIZARD,
      0x0,
      TileSpriteId.WIZARD,
      0x1,
    },
  }
}

function IsEnemyType(type_id)
  return ENEMY_INFO_MAP[type_id] ~= nil
end

function MakeEnemy(enemy_type)
  local enemy = {}

  local direction = Direction.DOWN
  local to_tile = START_POS

  local enemy_info = ENEMY_INFO_MAP[enemy_type]
  assert(enemy_info ~= nil)

  assert(enemy_info.speed <= 1)
  local MAX_PROGRESS = 1.0 / enemy_info.speed
  local progress = 0
  local health = 10
  local hitbox_radius = 0.25

  enemy["health"] = health
  enemy["hitbox_radius"] = hitbox_radius

  enemy_hold_map.occupy(to_tile)

  function enemy.update()
    local result = {
      should_erase = false,
    }

    local prev_from_tile = PosAfter(to_tile, OPPOSITE_DIR[direction])

    -- check for death
    if enemy.health <= 0 then
      result.should_erase = true

      -- release holds
      enemy_hold_map.vacate(prev_from_tile)
      enemy_hold_map.vacate(to_tile)

      -- play death animation
      return result
    end

    progress += 1
    if progress < MAX_PROGRESS then
      return result
    end

    progress -= MAX_PROGRESS

    local from_tile = to_tile

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

  local function corner_pos()
    local x = to_tile.x
    local y = to_tile.y
    local delta = DirDelta(direction)
    x -= delta.x * (MAX_PROGRESS - progress - 1) / MAX_PROGRESS
    y -= delta.y * (MAX_PROGRESS - progress - 1) / MAX_PROGRESS
    return { x = x, y = y }
  end

  function enemy.draw()
    local frame_parity = flr(time / 4) % 2
    local animation_offset = 1 + 4 * direction + 2 * frame_parity
    local enemy_animation_map = enemy_info.animation_data
    local id = enemy_animation_map[animation_offset]
    local flips = enemy_animation_map[animation_offset + 1]
    local flip_x = (flips & 0x1) ~= 0
    local flip_y = (flips & 0x2) ~= 0

    local pos = corner_pos()
    spr(id, TILE_WIDTH * pos.x, TILE_WIDTH * pos.y, 1, 1, flip_x, flip_y)
  end

  function enemy.type_id()
    return enemy_type
  end

  function enemy.pos()
    local pos = corner_pos()
    return { x = pos.x + 0.5, y = pos.y + 0.5 }
  end

  function enemy.direction()
    return direction
  end

  function enemy.speed()
    return 1 / MAX_PROGRESS
  end

  return enemy
end

function MakeArcher(pos)
  local archer = {}

  local range = 6
  local fire_rate = 10
  local fire_rate_cooldown = 0
  local frames = 0
  local damage = 1

  function archer.update()
    local result = {
      should_erase = false,
    }
    if grid.tile(pos) ~= TypeId.ARCHER then
      result.should_erase = true
      return result
    end

    frames += 1

    if fire_rate_cooldown == 0 then
      local target_enemy = nil
      local target_enemy_distance = 32
      for entity in entity_map.entities() do
        if IsEnemyType(entity.type_id()) then
          local enemy_pos = entity.pos()
          local enemy_distance = PosMagnitude(PosSub(enemy_pos, archer.pos()))
          if enemy_distance < range then
            if enemy_distance < target_enemy_distance then
              target_enemy_distance = enemy_distance
              target_enemy = entity
            end
          end
        end
      end

      if target_enemy ~= nil then
        local archer_pos = archer.pos()

        local target_pos = target_enemy.pos()
        local enemy_dir = target_enemy.direction()
        local enemy_speed = target_enemy.speed()

        -- Make a guess for where the enemy will be by the time our arrow
        -- would reach them had we aimed straight for them, and aim for there
        -- instead.
        local distance_to_enemy = PosMagnitude(PosSub(target_pos, archer_pos))
        local scale = enemy_speed / ARROW_SPEED * distance_to_enemy
        local to_add = PosScale(DirDelta(enemy_dir), scale)
        target_pos = PosAdd(target_pos, to_add)

        local arrow = MakeArrow(archer_pos, target_pos, damage)
        entity_map.spawn(arrow)

        fire_rate_cooldown = fire_rate
      end
    else
      fire_rate_cooldown -= 1
    end

    return result
  end

  function archer.draw()
    -- pass
  end

  function archer.type_id()
    return TypeId.ARCHER
  end

  function archer.pos()
    return {
      x = pos.x + 0.5,
      y = pos.y + 0.5,
    }
  end

  return archer
end

function MakePinwheel(pos)
  local pinwheel = {}

  local fire_rate_cooldown = 0
  local frames = 0
  local range = 2.25
  local damage = 1

  -- sprinkler mode
  -- local spin_rate = 150
  -- local fire_rate = 6
  -- local n_direction = 4

  -- tic shooter mode
  local spin_rate = 0
  local n_directions = 12
  local fire_rate = 14

  function pinwheel.update()
    local result = {
      should_erase = false,
    }
    if grid.tile(pos) ~= TypeId.PINWHEEL then
      result.should_erase = true
      return result
    end
    
    frames += 1

    local will_fire = false
    if fire_rate_cooldown == 0 then
      for entity in entity_map.entities() do
        if not will_fire and IsEnemyType(entity.type_id()) then
          local enemy_pos = entity.pos()
          local enemy_distance = PosMagnitude(PosSub(enemy_pos, pinwheel.pos()))
          if enemy_distance < range then
            will_fire = true
          end
        end
      end

      if will_fire then
        for i = 0, n_directions - 1 do
          local angle_offset = i / n_directions
          local spin_angle = (frames % spin_rate) / spin_rate
          local angle = angle_offset - spin_angle

          local pos_x = cos(angle)
          local pos_y = sin(angle)
          
          local offset_pos = { x = range * pos_x, y = range * pos_y }
          local target_pos = PosAdd(pinwheel.pos(), offset_pos)

          local arrow = MakeArrow(pinwheel.pos(), target_pos, damage)
          entity_map.spawn(arrow)
        end
        fire_rate_cooldown = fire_rate
      end
    else
      fire_rate_cooldown -= 1
    end

    return result
  end

  function pinwheel.draw()
    -- pass
  end

  function pinwheel.type_id()
    return TypeId.PINWHEEL
  end

  function pinwheel.pos()
    return {
      x = pos.x + 0.5,
      y = pos.y + 0.5,
    }
  end

  return pinwheel
end

function MakeLightning(pos)
  local lightning = {}

  local range = 10
  local fire_rate = 90
  local fire_rate_cooldown = 0
  local firing_length = 4
  local active_beam_frames = 0
  local frames = 0

  local damage = 2

  local target_pixel_pos = { x = 0, y = 0 }

  function lightning.update()
    local result = {
      should_erase = false,
    }
    if grid.tile(pos) ~= TypeId.LIGHTNING then
      result.should_erase = true
      return result
    end

    frames += 1

    if active_beam_frames > 0 then
      active_beam_frames -= 1
    end

    if fire_rate_cooldown == 0 then
      local target_enemy = nil
      local target_enemy_distance = 999
      for entity in entity_map.entities() do
        if IsEnemyType(entity.type_id()) then
          local enemy_pos = entity.pos()
          local enemy_distance = PosMagnitude(PosSub(enemy_pos, lightning.pos()))
          if enemy_distance < range then
            if enemy_distance < target_enemy_distance then
              target_enemy_distance = enemy_distance
              target_enemy = entity
            end
          end
        end
      end

      if target_enemy != nil then
        target_pixel_pos.x = target_enemy.pos().x * TILE_WIDTH
        target_pixel_pos.y = target_enemy.pos().y * TILE_WIDTH
        active_beam_frames = firing_length
        fire_rate_cooldown = fire_rate
      end
    else
      fire_rate_cooldown -= 1
    end

    return result
  end

  function lightning.draw()
    if active_beam_frames == 0 then
      return
    end
    
    local start_x = (pos.x + 0.5) * TILE_WIDTH
    local start_y = (pos.y + 0.5) * TILE_WIDTH
    
    line(start_x, start_y - 2, target_pixel_pos.x, target_pixel_pos.y, 7)
  end

  function lightning.type_id()
    return TypeId.LIGHTNING
  end

  function lightning.pos()
    return {
      x = pos.x + 0.5,
      y = pos.y + 0.5,
    }
  end

  return lightning
end

function MakeEntityMap()
  entity_map = {}

  local entities = {}
  -- Head of the freelist of IDs
  local next_free_id = nil
  local num_allocated_ids = 0

  local function live_entities()
    -- Cache the global function for faster lookup
    local type = type

    local live_entities = {}
    for id = 0, num_allocated_ids - 1 do
      local entity = entities[id]
      if type(entity) == "table" then
        live_entities[id] = entity
      end
    end
    return pairs(live_entities)
  end

  function entity_map.entities()
    -- Cache the global function for faster lookup
    local type = type

    local live_entities = {}
    for id = 0, num_allocated_ids - 1 do
      local entity = entities[id]
      if type(entity) == "table" then
        add(live_entities, entity)
      end
    end
    return all(live_entities)
  end

  function entity_map.spawn(entity)
    assert(type(entity) == "table")

    if next_free_id ~= nil then
      -- If we have free IDs, use the head of the freelist
      local next_id = entities[next_free_id]
      assert(type(next_id) == "number" or next_id == nil)

      entities[next_free_id] = entity
      next_free_id = next_id
    else
      -- If we have no free IDs, allocate a new ID
      entities[num_allocated_ids] = entity
      num_allocated_ids += 1
    end
  end

  local function erase_id(id)
    -- Insert this ID to the front of the freelist
    entities[id] = next_free_id
    next_free_id = id
  end

  function entity_map.update()
    for i, entity in live_entities() do
      local result = entity.update()
      if result.should_erase then
        erase_id(i)
      end
    end
  end

  function entity_map.draw()
    for _, entity in live_entities() do
      entity.draw()
    end
  end

  function entity_map.num_allocated_ids()
    return num_allocated_ids
  end

  return entity_map
end

function UpdateInput()
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
    cursor_pos.x = min(cursor_pos.x + 1, WORLD_WIDTH - 1)
  end
  if Pressed(UP) then
    cursor_pos.y = max(cursor_pos.y - 1, 0)
  end
  if Pressed(DOWN) then
    cursor_pos.y = min(cursor_pos.y + 1, WORLD_HEIGHT - 1)
  end

  -- Place tower
  if Pressed(BTN_Z) then
    local grid_tile_type = grid.tile(cursor_pos)
    local selected_tower_type = PLACEABLE_TILES[selected_tower_index]
    assert(selected_tower_type ~= nil)

    if grid_tile_type == TypeId.EMPTY then
      local added = grid.try_set_tile(cursor_pos, selected_tower_type)
      if added then
        local tower_pos = {
          x = cursor_pos.x,
          y = cursor_pos.y,
        }
        if selected_tower_type == TypeId.ARCHER then
          entity_map.spawn(MakeArcher(tower_pos))
        elseif selected_tower_type == TypeId.PINWHEEL then
          entity_map.spawn(MakePinwheel(tower_pos))
        elseif selected_tower_type == TypeId.LIGHTNING then 
          entity_map.spawn(MakeLightning(tower_pos))
        end
      end
    elseif grid_tile_type == selected_tower_type then
      assert(grid.try_set_tile(cursor_pos, TypeId.EMPTY))
    end
  end

  -- Scroll to next tower option
  if Pressed(BTN_X) then
    if selected_tower_index == #PLACEABLE_TILES then
      selected_tower_index = 1
    else
      selected_tower_index += 1
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
      if tile == TypeId.WALL then
        id = TileSpriteId.WALL + (x + y) % 2
      elseif tile == TypeId.ENTRANCE then
        id = TileSpriteId.ENTRANCE
      elseif tile == TypeId.EXIT then
        id = TileSpriteId.EXIT
      elseif tile == TypeId.ARCHER then
        id = TileSpriteId.ARCHER
      elseif tile == TypeId.PINWHEEL then
        id = TileSpriteId.PINWHEEL
      elseif tile == TypeId.LIGHTNING then
        id = TileSpriteId.LIGHTNING
      elseif tile == TypeId.ENEMY_HOLD then
        id = 244
      else
        assert(tile == TypeId.EMPTY)
        local dir = grid.enemy_dir_at({ x = x, y = y })
        if dir == Direction.LEFT then
          id = 240
        elseif dir == Direction.RIGHT then
          id = 241
        elseif dir == Direction.UP then
          id = 242
        elseif dir == Direction.DOWN then
          id = 243
        else
          assert(dir == nil)
          goto continue
        end
      end

      if not DEBUG_DISPLAY_DIR_MAP and id >= 240 then
        goto continue
      end

      spr(id, x * TILE_WIDTH, y * TILE_WIDTH)

      ::continue::
    end
  end
end

function UpdateEntities()
  -- clear enemy grid
  enemy_grid = {}

  entity_map.update()

  -- update enemy spatial grid
  for entity in entity_map.entities() do
    if IsEnemyType(entity.type_id()) then
      local e_pos = entity.pos()
      -- Hash them based on the integer grid cell they are currently floating over
      local grid_idx = Index(flr(e_pos.x), flr(e_pos.y))
      
      if enemy_grid[grid_idx] == nil then
        enemy_grid[grid_idx] = {}
      end
      add(enemy_grid[grid_idx], entity)
    end
  end

  -- arrow collision
  for entity in entity_map.entities() do
    if entity.type_id() == TypeId.ARROW then
      local arrow = entity
      local arrow_pos = arrow.pos()
      local arrow_idx = Index(flr(arrow_pos.x), flr(arrow_pos.y))
      local enemies_under_fire = enemy_grid[arrow_idx]
      if enemies_under_fire ~= nil then
        for enemy in all(enemies_under_fire) do
          local enemy_pos = enemy.pos()
          local enemy_distance = PosMagnitude(PosSub(enemy_pos, arrow_pos))
          if enemy_distance < enemy.hitbox_radius then
            enemy.health -= arrow.damage
            arrow.hit_enemy = true
            -- hit animation?
          end
        end
      end
    end
  end

  -- spawn new waves
  if time % 100 == 99 then
    local enemy_id
    if flr(time / 100) % 2 == 0 then
      enemy_id = TypeId.JELLYFISH
    else
      enemy_id = TypeId.WIZARD
    end
    entity_map.spawn(MakeEnemy(enemy_id))
  end

end

function DrawEntities()
  entity_map.draw()
end

function DrawHUD()
  local hud_y = WORLD_HEIGHT * TILE_WIDTH

  for x = 0, WORLD_WIDTH - 1 do
    spr(TileSpriteId.HUD_BORDER, x * TILE_WIDTH, hud_y)
  end

  for index, type_id in ipairs(PLACEABLE_TILES) do
    spr(TILE_TYPE_TO_SPRITE[type_id], index * TILE_WIDTH, hud_y + TILE_WIDTH)
  end

  spr(TileSpriteId.CURSOR + 1, selected_tower_index * TILE_WIDTH, hud_y + TILE_WIDTH)
end

function DrawDebugStats()
  if not DEBUG then
    return
  end

  local mem = stat(0) * 100 / 2048
  print("mem%: "..mem.."%", 84, 0)
  local cpu = stat(1) * 100
  print("cpu%: "..cpu.."%", 84, 8)
  print("ids: "..entity_map.num_allocated_ids(), 84, 16)
end

function _init()
  if not DEBUG then
    music(0)
  end

  selected_tower_index = 1

  time = 0

  cursor_pos = {
    x = 0,
    y = 0,
  }

  button_timers = { 0, 0, 0, 0, 0, 0 }

  grid = MakeGrid()

  enemy_hold_map = MakeEnemyHoldMap()

  entity_map = MakeEntityMap()

  enemy_grid = {}
end

function _update()
  cls(0) -- moving here for now to avoid prints being cleared
  UpdateInput()
  UpdateEntities()
  time += 1
end

function _draw()
  -- cls(0)
  DrawGrid()
  DrawEntities()
  DrawCursor()
  DrawHUD()
  DrawDebugStats()
end

__gfx__
77777776777777760000000000000000770770777700007700000000022222200000000000000000000000000000000000000000000600000076660011111111
76666666766666660000000000600600700000077000000700333300022222200000000000000000000000000000000000000000070220700766a66011111111
766666667666666d00600600006006000000000000000000033bb330022882200505005000000000000000000004000000004000002ee200066aa66011111111
766666667666666d0006600000600600700000070000000003bbbb3002888820055555500000000000400000000040000000400002e2ee26066a66d011111111
766666667666666d0160061001600610700000070000000003bbbb3002888820004444000044460000044000000040000000400062ee2e2000666d0011111111
7666666d7666666d00111100001111000000000000000000033bb330022882200042240000000000000006000000060000006000002ee2000006d00011111111
7666666d7666666d0000000000000000700000077000000703333330002222000449944000000000000000000000000000000000070220700006d00011111111
66dddddd66dddddd0000000000000000770770777700007703333330000000000449944000000000000000000000000000000000000060000055550011111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000010000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006061000666610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000601000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000601000000010000000a0ed000000ed000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006061000666610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000010000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00022000000220000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00222200002222000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00399000000990000009900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00322300003223000032230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00022300000223000032200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00099000000990000009900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00099900000990000009990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
25252525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00200020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006660000060060000666000006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006006000060060000600600006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006660000060060000600600006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000006060000060060000600600006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666600006006000006660000666000006006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

