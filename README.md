# Modern Exp Share Mod

A gameplay mod for Pokémon (Generation 1, 2, and 3) running on the Pokémon Love2D engine.

## Overview
In early Pokémon generations, training a balanced team required repetitive switch-training or single-target Exp. Share held items.

This mod introduces the modern Generation 6+ party experience sharing mechanics across all supported Pokémon games:
- **Battle Participants:** Every Pokémon that actively took part in defeating a foe receives **100%** of the experience yield without dilution.
- **Party Members:** Every other conscious (non-fainted, non-egg) Pokémon in the player's party receives **50%** of the experience yield.
- **Held Exp. Share:** Holding the original Exp. Share item does not reduce anyone's share.
- **Zero Configuration:** Always active when the mod is loaded. No options menu clutter, settings submenus, or hotkeys.
- **Save Integrity:** Operates purely in runtime battle calculations. Does not modify player save data, items, or options. Disabling the mod restores original generation experience behavior immediately.

## Installation
1. Download `modern_exp_share-0.1.0.zip` from the releases page.
2. Place or extract the mod into your `mods/` directory.
3. Start the game. Party-wide experience sharing is active immediately.

## Compatibility
Works across all game releases on engine 0.3.96:
- **Gen 3:** FireRed, LeafGreen, Ruby, Sapphire, Emerald.
- **Gen 1:** Red, Blue, Yellow.
- **Gen 2:** Gold, Silver, Crystal.
