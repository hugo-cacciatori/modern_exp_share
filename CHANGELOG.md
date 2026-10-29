# Changelog

All notable changes to the Modern Exp Share mod will be documented in this file.

## [0.1.1] - 2026-10-29

### Fixed
- Holding the original Exp. Share no longer halves everyone's share on Gen 2 and Gen 3: battlers get 100% and the rest of the party 50% of the full yield, as without the item. Gen 2 stat experience keeps the game's own Exp. Share halving.
- Gen 3 eggs never receive experience, even without the egg flag.

### Changed
- The logic now ships as a library bundled inside the mod.

## [0.1.0] - 2026-10-25

### Added
- Native Generation 6+ party experience sharing across Gen 1, Gen 2, and Gen 3 via the engine's `battle.exp_award` hook.
- Full 100% experience awarded to all active battle participants without division.
- 50% experience awarded to all conscious, non-egg party members.
- Zero configuration design: always active when loaded with no options menu clutter or hotkeys.
- Complete save file safety: no save mutations, inventory alterations, or option tampering.
- Clean hook restoration and unregistering on mod disable or rollback.
