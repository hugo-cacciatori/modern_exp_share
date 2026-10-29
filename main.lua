-- Modern Exp Share (Gen 6+ Party Experience)
-- ---------------------------------------------------------------------------
-- Grants 100% EXP to all active battle participants and 50% EXP to all other
-- non-fainted, non-egg Pokémon in the player's party.
-- Zero configuration, zero save mutations, clean rollback.
-- ---------------------------------------------------------------------------
-- The logic lives in the bundled `experience` lib (lib/experience/); this file only wires it.
return function(mod)
  local use = assert(load(assert(mod:read("lib/init.lua"), "missing lib/init.lua"), "@lib/init.lua"))(mod)
  use("experience").install(mod)
end
