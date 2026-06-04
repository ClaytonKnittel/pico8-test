function MakeEnemyHoldMap()
  local enemy_hold_map = {}
  local hold_map = {}

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
