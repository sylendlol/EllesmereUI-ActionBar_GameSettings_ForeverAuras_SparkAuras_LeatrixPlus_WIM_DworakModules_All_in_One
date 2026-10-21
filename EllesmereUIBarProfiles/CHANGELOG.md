# Changelog

## [9.6.1] - 2026-10-21

### Added
- First release: save action bars (slots 1-180), macros and key bindings as named, account-wide layouts and load them on another character.
- Spells are placed from the loading character's spellbook by name and rank (Spell Rank: Highest Known / Same Rank), so a known spell always lands in a rank the character has.
- Confirm popup before loading with the spells this character hasn't learned yet and a class warning.
- Macro matching by name and body, Update Same-Name Macros, macro-button remapping.
- Key binding restore with Clear Other Key Bindings.
- Backup Before Load, Undo Last Load, load report in chat.
- Export / import strings, rename, update and delete layouts.
- Place Unlearned Spells: spells a low level alt hasn't learned yet still go on their buttons (saved rank).
- Fill In When Learned: buttons of spells not learned yet are kept free and filled when the spell is learned (the copy the game pushes onto Action Bar 1 is removed); lower ranks are swapped up until the saved rank; per character, buttons you change are dropped.
- Dworak > Profiles module, tabs Action Bars, Game Settings and ForeverAuras.
- Game Settings tab: save the game's own options (every account / character CVar at its current value, defaults included), load them per category with a preview, Reset Other Settings, exact backup + Undo Last Load, export / import strings to move them to another account, reload offer after loading.
- ForeverAuras tab: every ForeverAuras aura of the account exported in one string and imported in one go on another account (Keep Mine / Replace It / Add as Copy for auras that already exist), then a UI reload.
- `/abp` (`/barprofiles`) with save, load, export, list, report, pending, fill, gs and fa.
