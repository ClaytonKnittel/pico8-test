pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
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
      should_erase = false
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
      y = pos.y + 0.5
    }
  end

  return pinwheel
end
