package.path = "./?.lua;./?/init.lua;" .. package.path
love = {
  data = {
    compress = function(_, _, bytes, level) return deflate(bytes, level) end,
    decompress = function(_, _, bytes) return inflate(bytes) end,
  },
  graphics = {
    newQuad = function() return {} end,
    newImage = function() return { getDimensions = function() return 256, 256 end } end,
  },
}
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == "0.3.96", "wrong installed engine")

local fs, overlay = {}, {}
function fs.read(p) return overlay[p] or fs_read(p) end
function fs.getInfo(p) return overlay[p] and { type = "file" } or fs_info(p) end
function fs.getDirectoryItems(p) return fs_list(p) end
function fs.load(p)
  local bytes = fs.read(p)
  return bytes and loadstring(bytes, "@" .. p)
end
function fs.write(p, bytes) overlay[p] = bytes return true end
function fs.createDirectory() return true end
fs.root = "."

local generation = GameVersion.generation()
local Loader = require("src.mods.Loader")
local game = { data = {} }

if generation == 3 then
  local Dataset = require("src.core.game3.dataset")
  Dataset.cacheRootOverride = CACHE_ROOT
  assert(Dataset.hydrate(game), "installed dataset did not hydrate")
else
  local dir = TEST_VERSION .. "/data/generated/"
  for _, name in ipairs({ "constants", "moves", "items", "pokemon", "type_chart" }) do
    local chunk = fs.load(dir .. name .. ".lua")
    if chunk then game.data[name] = chunk() end
  end
end

local loader = Loader.new({ fs = fs, generation = generation })
loader:load(game.data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
local mod = loader.mods.modern_exp_share
assert(mod and mod.state == "loaded", "installed mod did not load for " .. TEST_VERSION)

-- Test battle exp_award hook in installed environment
local mon1 = { species = 25, hp = 50, level = 20 } -- Active battler
local mon2 = { species = 1, hp = 40, level = 18 }  -- Healthy bench
local mon3 = { species = 4, hp = 0, level = 18 }   -- Fainted bench
local mon4 = { species = 7, hp = 20, isEgg = true } -- Egg bench

local party = { mon1, mon2, mon3, mon4 }
local battle = {
  playerParty = party,
  party = party,
}

local awarded = {}
local function mockApplyShare(mon, split, announce)
  awarded[#awarded + 1] = {
    mon = mon,
    split = split,
    announce = announce,
  }
end

local vanillaCalled = false
local function vanillaAward(ctx)
  vanillaCalled = true
end

local ctx = {
  battle = battle,
  alive = { mon1 },
  applyShare = mockApplyShare,
}

loader.hooks:call("battle.exp_award", vanillaAward, ctx)

assert(not vanillaCalled, "vanilla award was not bypassed")
assert(#awarded == 2, "expected exactly 2 mons to receive EXP")
assert(awarded[1].mon == mon1 and awarded[1].split == 1, "active mon1 did not receive 100% EXP (split=1)")
assert(awarded[2].mon == mon2 and awarded[2].split == 2, "bench mon2 did not receive 50% EXP (split=2)")

-- Verify rollback restoration
if mod.exports and mod.exports.restore then
  mod.exports.restore()
  vanillaCalled = false
  awarded = {}
  loader.hooks:call("battle.exp_award", vanillaAward, ctx)
  assert(vanillaCalled, "vanilla award was not called after rollback restore()")
  assert(#awarded == 0, "mod still awarded EXP after rollback restore()")
end

print(string.format("PASS installed %s: Modern Exp Share party distribution and rollback", TEST_VERSION))
