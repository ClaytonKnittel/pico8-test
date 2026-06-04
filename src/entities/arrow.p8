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
