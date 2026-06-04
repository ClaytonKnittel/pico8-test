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
