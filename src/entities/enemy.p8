pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
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
      0x0
    }
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
      0x1
    }
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
      should_erase = false
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
    return to_tile - PosScale(delta, (MAX_PROGRESS - progress - 1) / MAX_PROGRESS)
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
    return MakePos(pos.x + 0.5, pos.y + 0.5)
  end

  function enemy.direction()
    return direction
  end

  function enemy.speed()
    return 1 / MAX_PROGRESS
  end

  return enemy
end
