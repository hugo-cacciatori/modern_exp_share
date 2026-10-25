-- Modern Exp Share (Gen 6+ Party Experience)
-- ---------------------------------------------------------------------------
-- Grants 100% EXP to all active battle participants and 50% EXP to all other
-- non-fainted, non-egg Pokémon in the player's party.
-- Zero configuration, zero save mutations, clean rollback.
-- ---------------------------------------------------------------------------

return function(mod)
  if not (mod and mod.hooks) then return end

  local enabled = true

  local function isAliveNonEgg(mon)
    if not mon then return false end
    if mon.isEgg or (mon.species and (mon.species == "EGG" or mon.species == 253)) then
      return false
    end
    local hp = tonumber(mon.hp) or 0
    return hp > 0
  end

  local function getParty(battle)
    if not battle then return {} end
    if type(battle.playerParty) == "table" then return battle.playerParty end
    if type(battle.party) == "table" then return battle.party end
    if type(battle.playerPartyView) == "function" then
      local ok, res = pcall(battle.playerPartyView, battle)
      if ok and type(res) == "table" then return res end
    end
    if battle.game and battle.game.save and type(battle.game.save.party) == "table" then
      return battle.game.save.party
    end
    return {}
  end

  mod.hooks:wrap("battle.exp_award", function(nextFn, ctx)
    if not enabled or not ctx or type(ctx.applyShare) ~= "function" then
      return nextFn(ctx)
    end

    local battle = ctx.battle
    local aliveParticipants = ctx.alive or {}
    local participantSet = {}

    -- 1. Award 100% (split = 1) to all active participating alive mons
    for _, mon in ipairs(aliveParticipants) do
      if isAliveNonEgg(mon) then
        participantSet[mon] = true
        ctx.applyShare(mon, 1, true)
      end
    end

    -- 2. Award 50% (split = 2) to all other healthy party members
    local party = getParty(battle)
    for pi = 1, 6 do
      local mon = party[pi]
      if mon and not participantSet[mon] and isAliveNonEgg(mon) then
        ctx.applyShare(mon, 2, true)
      end
    end
  end)

  mod.exports = {
    restore = function()
      enabled = false
    end
  }

  if mod.log and mod.log.info then
    mod.log:info("Loaded Modern Exp Share (Gen 6+ party EXP)")
  end
end
