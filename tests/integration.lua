package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
local Sdk = require("tests.modkit.sdk")
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Logger = require("src.core.Logger")
if Logger.warn then Logger.warn = function() end end

local total = 0
local function check(value, message)
  total = total + 1
  assert(value, message)
end

local PROFILES = {
  { version = "firered", gen = 3 },
  { version = "leafgreen", gen = 3 },
  { version = "ruby", gen = 3 },
  { version = "sapphire", gen = 3 },
  { version = "emerald", gen = 3 },
  { version = "red", gen = 1 },
  { version = "blue", gen = 1 },
  { version = "yellow", gen = 1 },
  { version = "gold", gen = 2 },
  { version = "silver", gen = 2 },
  { version = "crystal", gen = 2 },
}

for _, p in ipairs(PROFILES) do
  GameVersion.set(p.version)
  Runtime.reset()

  local opts = {
    version = p.version,
    generation = p.gen,
    data = (p.gen == 3 and Sdk.gen3Data()) or {},
  }

  local run = Sdk.loadMod(MOD_PATH, opts)
  check(#run.errors == 0, p.version .. ": load error: " .. table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", p.version .. ": mod loaded")

  local loader = run.loader

  -- Set up mock battle & party
  local mon1 = { species = 25, hp = 50, level = 20 } -- Active battler
  local mon2 = { species = 1, hp = 40, level = 18 }  -- Healthy bench mon
  local mon3 = { species = 4, hp = 0, level = 18 }   -- Fainted bench mon
  local mon4 = { species = 7, hp = 20, isEgg = true } -- Egg bench mon
  local mon5 = { species = "EGG", hp = 10 }          -- Gen 2 egg representation
  local mon6 = { species = 16, hp = 30, level = 15 } -- Second healthy bench mon

  local party = { mon1, mon2, mon3, mon4, mon5, mon6 }
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

  -- 1. Execute exp_award with mod active
  loader.hooks:call("battle.exp_award", vanillaAward, ctx)

  check(not vanillaCalled, p.version .. ": vanilla award bypassed when mod active")
  check(#awarded == 3, p.version .. ": exactly 3 mons awarded EXP (1 participant + 2 healthy bench)")

  -- Check participant award: mon1 got split = 1 (100% full EXP)
  check(awarded[1].mon == mon1 and awarded[1].split == 1, p.version .. ": participant mon1 received 100% EXP (split=1)")

  -- Check bench awards: mon2 and mon6 got split = 2 (50% EXP)
  check(awarded[2].mon == mon2 and awarded[2].split == 2, p.version .. ": bench mon2 received 50% EXP (split=2)")
  check(awarded[3].mon == mon6 and awarded[3].split == 2, p.version .. ": bench mon6 received 50% EXP (split=2)")

  -- Fainted mon3 and Eggs mon4/mon5 were never awarded
  for _, record in ipairs(awarded) do
    check(record.mon ~= mon3, p.version .. ": fainted mon3 never awarded EXP")
    check(record.mon ~= mon4, p.version .. ": egg mon4 never awarded EXP")
    check(record.mon ~= mon5, p.version .. ": egg mon5 never awarded EXP")
  end

  -- 2. Test multi-participant scenario: mon1 and mon2 both participated
  awarded = {}
  local ctxMulti = {
    battle = battle,
    alive = { mon1, mon2 },
    applyShare = mockApplyShare,
  }
  loader.hooks:call("battle.exp_award", vanillaAward, ctxMulti)
  check(#awarded == 3, p.version .. ": 2 participants + 1 healthy bench mon6")
  check(awarded[1].mon == mon1 and awarded[1].split == 1, p.version .. ": participant mon1 received 100% EXP")
  check(awarded[2].mon == mon2 and awarded[2].split == 1, p.version .. ": participant mon2 received 100% EXP (undivided)")
  check(awarded[3].mon == mon6 and awarded[3].split == 2, p.version .. ": bench mon6 received 50% EXP")

  -- Gen 3 eggs are species 412 even without an isEgg flag (src/core/game3/pokemon.lua isEgg)
  if p.gen == 3 then
    local egg = { species = 412, hp = 20, level = 5 }
    local eggParty = { mon1, egg }
    awarded = {}
    loader.hooks:call("battle.exp_award", vanillaAward,
      { battle = { playerParty = eggParty, party = eggParty }, alive = { mon1 }, applyShare = mockApplyShare })
    check(#awarded == 1 and awarded[1].mon == mon1, p.version .. ": species-412 egg never awarded EXP")
  end

  -- 3. Test rollback / restore restores vanilla
  if run.mod.exports and run.mod.exports.restore then
    run.mod.exports.restore()
    vanillaCalled = false
    awarded = {}
    loader.hooks:call("battle.exp_award", vanillaAward, ctx)
    check(vanillaCalled, p.version .. ": vanilla award called after rollback restore()")
    check(#awarded == 0, p.version .. ": mod custom distribution inactive after rollback")
  end
end

print(string.format("Integration suite passed: %d assertions across %d profiles", total, #PROFILES))
