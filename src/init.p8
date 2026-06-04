pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function UpdateInput()
  local INITIAL_DELAY = 10
  local REPEAT_DELAY = 4

  local REPEAT_OFFSET = 64

  local buttons = {
    btn(0),
    btn(1),
    btn(2),
    btn(3),
    btn(4),
    btn(5)
  }

  local pressed = {}

  for i, time in ipairs(button_timers) do
    if not buttons[i] then
      button_timers[i] = 0
    elseif time == 0 then
      pressed[i] = true
      button_timers[i] = INITIAL_DELAY + 1
    elseif time == 1 then
      pressed[i] = true
      button_timers[i] += REPEAT_DELAY
    else
      button_timers[i] -= 1
    end
  end

  local left = pressed[LEFT + 1]
  local right = pressed[RIGHT + 1]
  local up = pressed[UP + 1]
  local down = pressed[DOWN + 1]
  local btn_z = pressed[BTN_Z + 1]
  local btn_x = pressed[BTN_X + 1]

  if left then
    cursor_pos.x = max(cursor_pos.x - 1, 0)
  end
  if right then
    cursor_pos.x = min(cursor_pos.x + 1, WORLD_WIDTH - 1)
  end
  if up then
    cursor_pos.y = max(cursor_pos.y - 1, 0)
  end
  if down then
    cursor_pos.y = min(cursor_pos.y + 1, WORLD_HEIGHT - 1)
  end

  -- Place tower
  if btn_z then
    local grid_tile_type = grid.tile(cursor_pos)
    local selected_tower_type = PLACEABLE_TILES[selected_tower_index]
    assert(selected_tower_type ~= nil)

    if grid_tile_type == TypeId.EMPTY then
      local added = grid.try_set_tile(cursor_pos, selected_tower_type)
      if added then
        local tower_pos = {
          x = cursor_pos.x,
          y = cursor_pos.y
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
  if btn_x then
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

function DrawDebugStats()
  if not DEBUG then
    return
  end

  local mem = stat(0) * 100 / 2048
  print("mem%: " .. mem .. "%", 84, 0)
  local cpu = stat(1) * 100
  print("cpu%: " .. cpu .. "%", 84, 8)
  print("ids: " .. entity_map.num_allocated_ids(), 84, 16)
end

function _init()
  if not DEBUG then
    music(0)
  end

  selected_tower_index = 1

  time = 0

  cursor_pos = {
    x = 0,
    y = 0
  }

  button_timers = { 0, 0, 0, 0, 0, 0 }

  grid = MakeGrid()

  enemy_hold_map = MakeEnemyHoldMap()

  entity_map = MakeEntityMap()

  enemy_grid = {}
end

function _update()
  -- moving here for now to avoid prints being cleared
  cls(0)
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
