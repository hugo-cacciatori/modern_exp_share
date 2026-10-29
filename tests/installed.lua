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
assert(require("src.core.Version").engine == INSTALLED_ENGINE, "staged engine is not the installed one")

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

-- Real engine award path: a party member holding the vanilla Exp. Share must not
-- tax the modern split (participants 100 %, bench 50 % of the undivided yield).
local function recordGains()
  local gains = {}
  local remove = loader.hooks:wrap("exp.gain", function(next, ctx)
    local amount = next(ctx)
    gains[#gains + 1] = { mon = ctx.mon, amount = amount }
    return amount
  end, 100000, "installed_test")
  return gains, remove
end

local function amountsByMon(gains, party)
  local out, seen = {}, {}
  for _, g in ipairs(gains) do
    for i, m in ipairs(party) do
      if g.mon == m then
        assert(not seen[i], "party slot " .. i .. " was awarded twice")
        seen[i] = true
        out[i] = g.amount
      end
    end
  end
  return out
end

if generation == 3 then
  local State = require("src.core.game3.battle.state")
  local Damage = require("src.core.game3.battle.damage")
  local Experience = require("src.core.game3.battle.experience")
  local HeldItems = require("src.core.game3.battle.held_items")
  local EXP_SHARE
  for id = 1, 400 do
    if HeldItems.effectOf(id) == HeldItems.HOLD.EXP_SHARE then EXP_SHARE = id break end
  end
  assert(EXP_SHARE, "no item with the Exp. Share hold effect")
  local FOE, LEVEL = 16, 10
  local calculated = math.floor(Experience.expYield(FOE) * LEVEL / 7)
  assert(calculated >= 4, "foe yield too small to tell the shares apart")

  local function award(holderItem)
    local function mon(species, item)
      return Damage.ensureStats({ species = species, level = LEVEL, hp = 30, maxHp = 30, exp = 1000, item = item })
    end
    local party = { mon(1), mon(4), mon(7, holderItem), { species = 412, level = 5, hp = 20, maxHp = 20 } }
    local foe = Damage.ensureStats({ species = FOE, level = LEVEL, hp = 0, maxHp = 30, exp = 1000 })
    local st = State.new({ playerParty = party, foeParty = { foe }, foeMon = foe, wild = true })
    local gains, remove = recordGains()
    Experience.awardFoe(st, st.enemy, { trainer = false })
    remove()
    return amountsByMon(gains, party)
  end

  for _, case in ipairs({ { label = "no holder" }, { label = "Exp. Share holder", item = EXP_SHARE } }) do
    local got = award(case.item)
    assert(got[1] == calculated, string.format("%s: participant got %s, want %d", case.label, tostring(got[1]), calculated))
    local half = math.max(1, math.floor(calculated / 2))
    assert(got[2] == half, string.format("%s: bench got %s, want %d", case.label, tostring(got[2]), half))
    assert(got[3] == half, string.format("%s: bench holder got %s, want %d", case.label, tostring(got[3]), half))
    assert(got[4] == nil, case.label .. ": the species-412 egg was awarded EXP")
  end
end

if TEST_VERSION == "crystal" then
  local Gen2Battle = require("src.battle.gen2.Battle")
  local Mon = require("src.battle.gen2.Mon")
  local FOE, LEVEL = "PIDGEY", 10
  local calculated = math.floor(game.data.pokemon[FOE].baseExp * LEVEL / 7)
  assert(calculated >= 4, "foe yield too small to tell the shares apart")

  local function award(holderItem)
    local function mon(species, item)
      local m = assert(Mon.new(game.data, species, LEVEL), "Mon.new failed for " .. species)
      m.item = item
      return m
    end
    local party = { mon("BULBASAUR"), mon("CHARMANDER"), mon("SQUIRTLE", holderItem) }
    local battle = setmetatable({
      party = party, participants = { [1] = true }, data = game.data,
      save = { party = party, player = {} }, emit = function() end,
    }, { __index = Gen2Battle })
    local gains, remove = recordGains()
    battle:awardExperience(mon(FOE))
    remove()
    return amountsByMon(gains, party)
  end

  for _, case in ipairs({ { label = "no holder" }, { label = "EXP_SHARE holder", item = "EXP_SHARE" } }) do
    local got = award(case.item)
    assert(got[1] == calculated, string.format("Gen 2 %s: participant got %s, want %d", case.label, tostring(got[1]), calculated))
    local half = math.max(1, math.floor(calculated / 2))
    assert(got[2] == half, string.format("Gen 2 %s: bench got %s, want %d", case.label, tostring(got[2]), half))
    assert(got[3] == half, string.format("Gen 2 %s: bench holder got %s, want %d", case.label, tostring(got[3]), half))
  end
end

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
