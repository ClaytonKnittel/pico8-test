ENEMY_INFO_MAP = {
  [TypeId.JELLYFISH] = {
    speed = 0.08,
    animation_data = {
      -- Left
      TileSpriteId.JELLYFISH,
      0x1,
      TileSpriteId.JELLYFISH + 1,
      0x1,
      -- Right
      TileSpriteId.JELLYFISH,
      0x0,
      TileSpriteId.JELLYFISH + 1,
      0x0,
      -- Up (Row 1 unique vertical sprites)
      TileSpriteId.JELLYFISH + 16,
      0x0,
      TileSpriteId.JELLYFISH + 17,
      0x0,
      -- Down (Row 1 unique vertical sprites, optionally flipped vertically if desired)
      TileSpriteId.JELLYFISH + 16,
      0x2,
      TileSpriteId.JELLYFISH + 17,
      0x2,
    },
    death_start = TileSpriteId.JELLYFISH + 2,
    death_len = 6,
    gold = 5,
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
    death_start = TileSpriteId.WIZARD + 3,
    death_len = 8,
    gold = 10,
  }
}

DIR_FLIPS = {
  [Direction.LEFT]  = {true,  false},
  [Direction.RIGHT] = {false, false},
  [Direction.UP]    = {false, true},
  [Direction.DOWN]  = {false, true}
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

  local is_dying = false
  local death_timer = 0
  local death_speed = 4
  local saved_flip_x = false
  local saved_flip_y = false

  enemy["health"] = health
  enemy["hitbox_radius"] = hitbox_radius

  enemy_hold_map.occupy(to_tile)

  function enemy.update()
    local result = {
      should_erase = false,
    }

    local prev_from_tile = PosAfter(to_tile, OPPOSITE_DIR[direction])

    -- death animation
    if is_dying then
      death_timer += 1
      if death_timer >= enemy_info.death_len * death_speed then
        result.should_erase = true
      end
      return result
    end

    -- check for death
    if enemy.health <= 0 then
      is_dying = true
      death_timer = 0

      -- gold
      GOLD += enemy_info.gold

      -- release holds
      enemy_hold_map.vacate(prev_from_tile)
      enemy_hold_map.vacate(to_tile)

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
    local pos = corner_pos()

    if is_dying then
      local current_frame = flr(death_timer / death_speed)
      
      -- clamp frame sequence so it rests extra long on the final step
      if current_frame >= enemy_info.death_len then
        current_frame = enemy_info.death_len - 1
      end

      local id = enemy_info.death_start + current_frame
      
      -- JELLYFISH SPECIFIC ROW SHIFT FOR VERTICAL EXPLOSIONS
      if enemy_type == TypeId.JELLYFISH and (direction == Direction.UP or direction == Direction.DOWN) then
        id += 16
      end

      local flip_x = saved_flip_x
      local flip_y = saved_flip_y

      spr(id, TILE_WIDTH * pos.x, TILE_WIDTH * pos.y, 1, 1, flip_x, flip_y)
    else
      local frame_parity = flr(time / 4) % 2
      local animation_offset = 1 + 4 * direction + 2 * frame_parity
      local enemy_animation_map = enemy_info.animation_data
      local id = enemy_animation_map[animation_offset]
      local flips = enemy_animation_map[animation_offset + 1]
      local flip_x = (flips & 0x1) ~= 0
      local flip_y = (flips & 0x2) ~= 0

      if enemy_type == TypeId.WIZARD then
        saved_flip_x = false
        saved_flip_y = false
      else
        saved_flip_x = flip_x
        saved_flip_y = flip_y
      end

      spr(id, TILE_WIDTH * pos.x, TILE_WIDTH * pos.y, 1, 1, flip_x, flip_y)
    end

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