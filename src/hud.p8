function DrawHUD()
  local hud_y = WORLD_HEIGHT * TILE_WIDTH

  for x = 0, WORLD_WIDTH - 1 do
    spr(TileSpriteId.HUD_BORDER, x * TILE_WIDTH, hud_y)
  end

  for index, type_id in ipairs(PLACEABLE_TILES) do
    spr(TILE_TYPE_TO_SPRITE[type_id], index * TILE_WIDTH, hud_y + TILE_WIDTH)
  end

  spr(TileSpriteId.CURSOR + 1, selected_tower_index * TILE_WIDTH, hud_y + TILE_WIDTH)
end
