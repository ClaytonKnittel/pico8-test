pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function DrawHUD()
  local hud_border_y = WORLD_HEIGHT * TILE_WIDTH
  local hud_data_y = hud_border_y + 4

  -- border
  -- for x = 0, WORLD_WIDTH - 1 do
  --   spr(TileSpriteId.HUD_BORDER, x * TILE_WIDTH, hud_border_y)
  -- end
  rectfill(0, hud_border_y, 128, 128, 1)
  
  -- selection
  selection_x = 4
  for index, type_id in ipairs(PLACEABLE_TILES) do
    spr(TILE_TYPE_TO_SPRITE[type_id], selection_x + (index-1) * (TILE_WIDTH+2), hud_data_y)
  end

  spr(TileSpriteId.CURSOR + 1, selection_x + (selected_tower_index-1) * (TILE_WIDTH+2), hud_data_y)

  -- data
  data_x = 83
  spr(TileSpriteId.GOLD, data_x, hud_data_y)
  print(GOLD, data_x+9, hud_data_y+2, 7)

  spr(TileSpriteId.HEART, data_x + 23, hud_data_y)
  print(HEALTH, data_x+10 + 23, hud_data_y+2, 7)
  
end
