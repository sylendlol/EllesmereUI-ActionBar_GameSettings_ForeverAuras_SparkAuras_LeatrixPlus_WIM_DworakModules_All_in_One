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
- Dworak > Profiles module, tabs Action Bars, Game Settings, ForeverAuras, Spark Forever, Leatrix Plus and Dworak Modules.
- Game Settings tab: save the game's own options (every account / character CVar at its current value, defaults included), load them per category with a preview, Reset Other Settings, exact backup + Undo Last Load, export / import strings to move them to another account, reload offer after loading.
- ForeverAuras tab: every ForeverAuras aura of the account exported in one string and imported in one go on another account (Keep Mine / Replace It / Add as Copy for auras that already exist), then a UI reload.
- Spark Forever tab: the same for Spark Forever auras; a string of either addon can be imported on the other's tab to move auras between them.
- Leatrix Plus tab: every Leatrix Plus setting exported in one string (Reload & Export saves this session's changes first) and imported on another account (replaces all settings via Leatrix' own /ltp nosave, then reloads), Undo Last Import.
- Dworak Modules tab: lists every installed Dworak module with a tick box; the ticked modules' settings (per-EllesmereUI-profile settings from the active profile, plus the module's own saved data) exported in one string and imported in place on another account, then a reload; Undo Last Import.
- `/abp` (`/barprofiles`) with save, load, export, list, report, pending, fill, gs, fa, sf, lp and dm.
