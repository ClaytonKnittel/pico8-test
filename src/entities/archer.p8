function MakeArcher(pos)
  local archer = {}

  local range = 6
  local fire_rate = 10
  local fire_rate_cooldown = 0
  local frames = 0
  local damage = 1
  local cost = 10

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
