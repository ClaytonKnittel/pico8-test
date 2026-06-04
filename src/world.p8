pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
TILE_WIDTH = 8

WORLD_WIDTH = 16
WORLD_HEIGHT = 14

START_POS = MakePos(1, 0)

END_POS = MakePos(WORLD_WIDTH - 1, WORLD_HEIGHT - 1)
OFFSCREEN_END_POS = MakePos(WORLD_WIDTH - 1, WORLD_HEIGHT)
