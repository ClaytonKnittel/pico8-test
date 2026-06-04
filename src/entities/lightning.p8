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
