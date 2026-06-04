pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
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
          local enemy_distance = PosMagnitude(enemy_pos - arrow_pos)
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
