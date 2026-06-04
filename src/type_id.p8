TypeId = {
  EMPTY = 0,
  WALL = 1,
  EXIT = 2,
  ENTRANCE = 3,
  -- A phony tile for enemies to "reserve", prevenging other tiles from being
  -- placed. --clayDawg
  ENEMY_HOLD = 4,
  ARCHER = 5,
  PINWHEEL = 6,
  LIGHTNING = 7,
  JELLYFISH = 8,
  WIZARD = 9,
}

PLACEABLE_TILES = {
  TypeId.WALL,
  TypeId.ARCHER,
  TypeId.PINWHEEL,
  TypeId.LIGHTNING,
}

TILE_TYPE_TO_SPRITE = {
  [TypeId.WALL] = TileSpriteId.WALL,
  [TypeId.ARCHER] = TileSpriteId.ARCHER,
  [TypeId.PINWHEEL] = TileSpriteId.PINWHEEL,
  [TypeId.LIGHTNING] = TileSpriteId.LIGHTNING,
}

OCCUPIABLE_TILES = {
  [TypeId.EMPTY] = true,
  [TypeId.ENTRANCE] = true,
  [TypeId.EXIT] = true,
  [TypeId.ENEMY_HOLD] = true,
}
