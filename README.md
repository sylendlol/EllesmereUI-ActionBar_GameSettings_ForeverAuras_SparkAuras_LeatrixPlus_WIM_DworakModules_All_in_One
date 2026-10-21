# EllesmereUI Profiles

Save your setup once and load it on any other character or account: action bars, macros, key bindings, the game's own settings and all your ForeverAuras auras.
Built as a module for the **Dworak** section of [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui).

Made for **WoW Forever** (Interface 16001) with **EllesmereUI 9.6.1**. The `.toc` also lists the 12.0.x / 12.1 interface numbers.

The module has three tabs at the top of its page:

| Tab | What it moves |
| --- | --- |
| **Action Bars** | What is on your action bars, your macros and your key bindings |
| **Game Settings** | The game's own options (Esc > Options): My Name, Auto Loot, nameplates, camera, soft targeting, chat, ... |
| **ForeverAuras** | Every ForeverAuras aura and group of the account, in one go |

## Why

Spells on WoW Forever have ranks, and every rank has its own spell ID. Tools that save a button as a bare spell ID and put it back with `PickupSpell(id)` place a rank the other character may not have, and the button shows up wrong or unusable.

Profiles saves every spell with its **name and rank** as well, and places it straight from the loading character's own spellbook, in a rank that character really knows. Spells it hasn't learned yet keep their button free and are put there the moment they are learned.

## Features

### Action Bars
- **Save Current Layout:** all 180 action slots (the ten EllesmereUI bars plus the stance / form pages), every account and character macro, and every key binding (`ACTIONBUTTON1`, `MULTIACTIONBAR1BUTTON1`, `EUI_BAR9_BUTTON1`, ...). EllesmereUI binds its bar keys to these commands, so the keys follow the buttons.
- Layouts are saved for **every character of the account**. Use **Export / Import** strings to move one to another account.
- **Load** shows a confirm popup first: what will be replaced, the spells this character hasn't learned yet, and a warning when the layout was saved on another class.
- **Spell Rank:** *Highest Known* (default) puts the highest rank you know on each button. *Same Rank* keeps the saved rank when you know it (for down-ranked spells), else the highest you know.
- **Fill In When Learned:** a level 1 alt can load a level 60 layout. Buttons whose spell isn't learned yet are kept free. When you learn the spell (trainer, level up), it goes on its own button, and the copy the game drops on Action Bar 1 by itself is removed. Lower ranks are swapped up until the saved rank is reached. Buttons you change yourself are left alone.
- **Macros:** identical macros are reused, a macro with the same name is updated (optional), the rest are created. Buttons always point at the right macro, even when the macro order differs.
- **Key Bindings** are set on the same commands and saved to your current binding set (character or account). *Clear Other Key Bindings* makes them match exactly.
- **Backup Before Load** and **Undo Last Load**.
- A **load report** in chat: placed, already there, cleared, waiting to be learned, not available.

### Game Settings
- The game's options are CVars that the server keeps per account / character, so copying `WTF\Account\...\config-cache.wtf` doesn't stick: the server writes its own copy back at login. This tab reads them in game and sets them with `C_CVar.SetCVar`, and the game saves them to the server itself.
- **Save Game Settings** stores every account and character setting at its current value, defaults included, so a setting left at default on one account is switched back on the other. Internal bookkeeping (tutorial flags, closed info frames, last-opened tabs, ...) is skipped.
- **Load** per category: Names, Nameplates, Loot, Camera & Mouse, Controls & Targeting, Combat & Action Bars, Chat & Social, Interface, and *This PC* (graphics and sound, off by default: every account on the same PC already shares them).
- **Preview Changes** lists every setting a load would change in chat: current value → saved value.
- **Reset Other Settings** (off by default) puts settings the saved set leaves at default back to default.
- **Backup Before Load** keeps the current value of everything a load changes, so **Undo Last Load** puts exactly that back.
- After loading, a reload is offered: some settings only fully apply after one.
- Settings the game refuses are listed. Settings no addon may change are never tried; the report tells you where to set them by hand.

### ForeverAuras
- ForeverAuras keeps its auras per WoW account, so every character of an account already shares them. Its own import takes one aura string at a time. This tab moves **all of them at once**.
- **Export All Auras:** every aura and group in one string.
- **Import Auras:** paste the string on the other account. A confirm popup lists the top-level auras and groups (the ones already there in yellow). The auras are then written into ForeverAuras' saved data and the UI reloads. ForeverAuras' own login does the rest, as for any saved aura: group links are re-checked, duplicate ids fixed, and every aura is updated to the running ForeverAuras version.
- **If An Aura Already Exists:** *Keep Mine* (default), *Replace It*, or *Add as Copy* ("Name (2)", group links rewritten).
- Auras can run their own code: only import strings you made yourself or trust.

## Requirements

- [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui)
- **EllesmereUIDworak**, the host addon that owns the *Dworak* section of the EllesmereUI panel
- Optional: **EllesmereUIActionBars** (the ten EllesmereUI bars), **ForeverAuras** (for the ForeverAuras tab)

## Installation

1. Copy the `EllesmereUIBarProfiles` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`. Use your client's own folder if it's different.
2. Make sure `EllesmereUI` and `EllesmereUIDworak` are installed and enabled.
3. Log in or `/reload`. The module appears under **EllesmereUI → Dworak → Profiles**.

## Quick start

**Copy your bars to an alt**
1. On your main: *Action Bars* tab → **Save As...** → give it a name.
2. On the alt: pick the layout → **Load** → confirm.

**Copy game settings to another account**
1. On the old account: *Game Settings* tab → **Save As...**, then **Export** and copy the string.
2. On the new account: **Paste String...** → pick the imported set → **Load**.

**Copy all ForeverAuras auras to another account**
1. On the old account: *ForeverAuras* tab → **Export** and copy the string.
2. On the new account: **Paste String...** → **Import & Reload**.

## Commands

| Command | What it does |
| --- | --- |
| `/abp` or `/barprofiles` | Opens the Profiles page (Action Bars tab) |
| `/abp gs` | Opens the Game Settings tab |
| `/abp fa` | Opens the ForeverAuras tab |
| `/abp save <name>` | Saves the current action bar layout |
| `/abp load <name>` | Loads a layout (with the confirm popup) |
| `/abp export <name>` | Shows a layout's export string |
| `/abp list` | Lists the saved layouts |
| `/abp report` | Prints the last load report |
| `/abp pending` | Lists the buttons waiting for a spell to be learned |
| `/abp fill` | Runs Fill In When Learned now |

## Settings

### Action Bars → Load Options

| Option | Default | What it does |
| --- | --- | --- |
| Action Bars | on | Places the saved buttons |
| Macros | on | Creates / updates the layout's macros |
| Key Bindings | on | Sets the saved keys |
| Spell Rank | Highest Known | Which rank of a spell goes on the button |
| Clear Other Slots | on | Empties buttons that are empty in the layout |
| Update Same-Name Macros | on | Overwrites a macro with the same name but other text |
| Clear Other Key Bindings | off | Unbinds keys on commands the layout leaves unbound |
| Backup Before Load | on | Saves `Backup: <name>` first |
| Place Unlearned Spells | on | Tries to put not-yet-learned spells on their buttons right away (the game usually refuses) |
| Fill In When Learned | on | Keeps those buttons free and fills them when the spell is learned |

### Game Settings → Load Options

| Option | Default | What it does |
| --- | --- | --- |
| Category toggles | all on, *This PC* off | Which settings a load touches |
| Reset Other Settings | off | Settings the set leaves at default go back to default |
| Backup Before Load | on | Saves the current value of everything the load changes |

### ForeverAuras

| Option | Default | What it does |
| --- | --- | --- |
| If An Aura Already Exists | Keep Mine | Keep Mine / Replace It / Add as Copy |

Layouts, setting sets and options are saved for the whole WoW account in `EllesmereUIBarProfilesDB`, not per EllesmereUI profile.

## How it works

- **Spells** are placed from the spellbook with `C_SpellBook.PickupSpellBookItem` (by spell ID, else by name and rank), with `PickupSpell` only as a last resort.
- **Macros on buttons:** `GetActionInfo` returns a macro's spell rather than its index, so a macro button is picked up and put straight back to read the index from the cursor.
- **New spells:** the game pushes every newly learned spell onto an empty Action Bar 1 slot (`SPELL_PUSHED_TO_ACTIONBAR`). Fill In When Learned moves it to its layout button and clears the pushed copy.
- **Strings:** a small serializer of its own (no `loadstring`: imported strings are only ever read as data) and LibDeflate, which ships with EllesmereUI. Prefixes: `!EUIBP1!` (Action Bars), `!EUIGS1!` (Game Settings), `!EUIFA1!` (ForeverAuras).
- **Game Settings:** the CVar list comes from `C_Console.GetAllCommands`. `C_CVar.GetCVarInfo` tells account, character and PC settings apart, and which ones are locked, secure or read-only (those are never touched). Each setting is read back after it is set and retried once a second later.
- Loading and saving only run out of combat.
- No EllesmereUI file is modified. The module registers through `EllesmereUIDworak.AddModule`.

## Known limitations

- **Early version.** The Game Settings tab is tested in game. Please report anything odd together with the `/abp report` output.
- The game doesn't let an addon put a spell the character hasn't learned on a button: such buttons stay free until Fill In When Learned can fill them.
- **Sticky Targeting** can't be set by an addon (the game ignores it). After a load the report tells you to tick or untick it by hand in *Esc > Options > Controls*.
- The pet bar is not saved (pet actions belong to the pet).
- Key bindings made with the old "bind a spell / macro / item to a key" method (not a command) are not saved.
- Items you don't carry may not be placeable; they are listed in the report.
- ForeverAuras: a string made with a newer ForeverAuras than yours shows a warning; update ForeverAuras first.

## Author

Dworak
