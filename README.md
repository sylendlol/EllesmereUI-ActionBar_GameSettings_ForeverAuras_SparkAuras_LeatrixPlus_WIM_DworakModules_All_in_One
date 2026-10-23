# EllesmereUI Profiles (Action Bars, Game Settings, ForeverAuras, Spark Forever, Leatrix+ , WIM, Dworak Modules)

<img width="1362" height="993" alt="image" src="https://github.com/user-attachments/assets/b1569303-df1c-4574-9e5e-9e84593ae480" />
<img width="1375" height="997" alt="image" src="https://github.com/user-attachments/assets/a0fff417-e381-4dd1-8728-1f3dd155833c" />
<img width="1379" height="991" alt="image" src="https://github.com/user-attachments/assets/94adfc7f-4b5e-44eb-bfba-61624ce1c0aa" />
<img width="1369" height="996" alt="image" src="https://github.com/user-attachments/assets/7b9b0a87-b11d-4276-bf35-c803a89cbe3e" />
<img width="1373" height="993" alt="image" src="https://github.com/user-attachments/assets/ea316987-e10e-4b76-b18d-99547716a457" />
<img width="1391" height="1002" alt="image" src="https://github.com/user-attachments/assets/2baffcda-8064-438e-a0c9-4724f5857148" />


Save your setup once and load it on any other character or account: action bars, macros and key bindings, the game's own settings, all your ForeverAuras and Spark Forever auras, your Leatrix Plus and WIM settings, and the settings of the other Dworak modules.
Built as a module for the **Dworak** section of [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui).

Made for **WoW Forever** (Interface 16001) with **EllesmereUI 9.6.1**. The `.toc` also lists the 12.0.x / 12.1 interface numbers.

The module lives under **EllesmereUI → Dworak → Profiles** and has seven tabs at the top of its page:

| Tab | What it moves |
| --- | --- |
| **Action Bars** | What is on your action bars, your macros and your key bindings |
| **Game Settings** | The game's own options (Esc > Options): My Name, Auto Loot, nameplates, camera, soft targeting, chat, ... |
| **ForeverAuras** | Every ForeverAuras aura and group of the account, in one go |
| **Spark Forever** | Every Spark Forever aura and group of the account, in one go |
| **Leatrix Plus** | Every Leatrix Plus setting of the account, in one go |
| **WIM** | WIM (WoW Instant Messenger) settings, filters, aliases and, if you want, conversation history |
| **Dworak Modules** | The settings of the Dworak modules you tick (Ammo Counter, Bag Cleaner, Loot Tracker, ...) |

## Why

**Action bars.** Spells on WoW Forever have ranks, and every rank has its own spell ID. Tools that save a button as a bare spell ID and put it back with `PickupSpell(id)` place a rank the other character may not have, and the button shows up wrong or unusable. Profiles saves every spell with its **name and rank** as well, and places it straight from the loading character's own spellbook, in a rank that character really knows. Spells it hasn't learned yet keep their button free and are put there the moment they are learned.

**Everything else.** Most addons keep their data per WoW account, so every character of an account already shares it, but a second account starts from scratch. Some of them can only import one item at a time (ForeverAuras, Spark Forever), some only save on logout (Leatrix Plus), and the game's own options live on the server, where copying files from the `WTF` folder doesn't stick. Profiles turns each of them into one string you copy on one account and paste on the other.

## Features

### Action Bars
- **Save Current Layout:** all 180 action slots (the ten EllesmereUI bars plus the stance / form pages), every account and character macro, and every key binding (`ACTIONBUTTON1`, `MULTIACTIONBAR1BUTTON1`, `EUI_BAR9_BUTTON1`, ...). EllesmereUI binds its bar keys to these commands, so the keys follow the buttons.
- Layouts are saved for **every character of the account**. Use **Export / Import** strings to move one to another account. Layouts can be renamed, overwritten and deleted.
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

### ForeverAuras and Spark Forever
Both are WeakAuras-style addons, and each has its own tab that works the same way. The tab shows how many auras the account has and the addon's version.
- Their own import takes one aura string at a time. These tabs move **all auras and groups at once**.
- **Export All Auras:** every aura and group in one string.
- **Import Auras:** paste the string on the other account. A confirm popup lists the top-level auras and groups (the ones already there in yellow). The auras are then written into the addon's saved data and the UI reloads. The addon's own login does the rest, as for any saved aura: group links are re-checked, duplicate ids fixed, and every aura is updated to the running version.
- **If An Aura Already Exists:** *Keep Mine* (default), *Replace It*, or *Add as Copy* ("Name (2)", group links rewritten).
- A ForeverAuras string can be imported on the Spark Forever tab and the other way round, to move auras from one addon to the other. The confirm popup says so; auras that use something only the other addon has may need fixing.
- A string made with a newer version of the addon than yours shows a warning.

### Leatrix Plus
- Leatrix Plus writes its settings to disk only when the UI reloads or you log out. The tab shows how many settings are saved and the Leatrix Plus version.
- **Export All Settings:** every setting in one string (chat history left out). *Reload & Export* reloads first so this session's changes are included, and shows the string right after the reload; *Export As Saved* uses what was saved at the last reload.
- **Import Settings:** all Leatrix Plus settings are replaced and the UI reloads. It uses Leatrix Plus' own `/ltp nosave`, so Leatrix doesn't write its old settings back over the imported ones.
- **Undo Last Import** puts back the settings you had before.

### WIM
- Tick what goes into the string: **Settings**, **Filters**, **Player Aliases** (on by default) and **Conversation History** (off by default: private, and can be large). WIM's player info cache is never copied.
- **Export WIM** / **Import WIM:** the import replaces the parts the string holds, then reloads the UI.
- **Undo Last Import** puts back what you had before.

### Dworak Modules
- Lists every installed Dworak module (every addon that depends on EllesmereUIDworak) with a tick box, so new modules show up by themselves. **Tick All** / **Untick All**. Hovering a module shows how many saved settings it has.
- **Export Ticked Modules:** the ticked modules' settings in one string. Settings that EllesmereUI keeps per profile come from the active EllesmereUI profile; settings a module keeps in its own saved data (for example Loot Tracker) come along too. Per-character data is left out.
- **Import Settings:** replaces the settings of every module in the string that is enabled here, then reloads the UI. Modules that aren't installed or enabled are listed and skipped. Settings kept per EllesmereUI profile go into the active profile.
- **Undo Last Import** puts back the settings the modules had before.

#### Profiles and EllesmereUI's own export
EllesmereUI's full export already carries everything a module keeps in the EllesmereUI profile. It does **not** carry data a module keeps in its own saved variables. Of the Dworak modules that is **Item Count, Loot Roll Window, Loot Tracker, Talent Calculator, Bag Keyring** and Profiles itself; the Dworak Modules tab covers them.

## Requirements

- [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui)
- **EllesmereUIDworak**, the host addon that owns the *Dworak* section of the EllesmereUI panel
- Optional, each for its own tab: **EllesmereUIActionBars** (the ten EllesmereUI bars), **ForeverAuras**, **Spark Forever**, **Leatrix Plus**, **WIM**. A tab whose addon isn't loaded says so and greys out its buttons.

## Installation

1. Copy the `EllesmereUIBarProfiles` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`. Use your client's own folder if it's different.
2. Make sure `EllesmereUI` and `EllesmereUIDworak` are installed and enabled.
3. Restart the game (a new addon, or a new file in it, is only picked up on a full restart; later updates of existing files need just `/reload`). The module appears under **EllesmereUI → Dworak → Profiles**.

## Quick start

**Copy your bars to an alt**
1. On your main: *Action Bars* tab → **Save As...** → give it a name.
2. On the alt: pick the layout → **Load** → confirm.

**Copy game settings to another account**
1. On the old account: *Game Settings* tab → **Save As...**, then **Export** and copy the string.
2. On the new account: **Paste String...** → pick the imported set → **Load**.

**Copy all ForeverAuras or Spark Forever auras to another account**
1. On the old account: *ForeverAuras* or *Spark Forever* tab → **Export** and copy the string.
2. On the new account: **Paste String...** → **Import & Reload**.

**Copy Leatrix Plus settings to another account**
1. On the old account: *Leatrix Plus* tab → **Export** → **Reload & Export**, then copy the string that appears after the reload.
2. On the new account: **Paste String...** → **Import & Reload**.

**Copy WIM or Dworak module settings to another account**
1. On the old account: *WIM* or *Dworak Modules* tab → tick what you want → **Export** and copy the string.
2. On the new account: **Paste String...** → **Import & Reload**.

Every import shows what it will change first, and every tab has an **Undo Last Import / Undo Last Load**.

## Commands

| Command | What it does |
| --- | --- |
| `/abp` or `/barprofiles` | Opens the Profiles page (Action Bars tab) |
| `/abp gs` | Opens the Game Settings tab |
| `/abp fa` | Opens the ForeverAuras tab |
| `/abp sf` | Opens the Spark Forever tab |
| `/abp lp` | Opens the Leatrix Plus tab |
| `/abp wim` | Opens the WIM tab |
| `/abp dm` | Opens the Dworak Modules tab |
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

### ForeverAuras / Spark Forever

| Option | Default | What it does |
| --- | --- | --- |
| If An Aura Already Exists | Keep Mine | Keep Mine / Replace It / Add as Copy |

### WIM

| Part | Default | What it is |
| --- | --- | --- |
| Settings | on | Windows, skin, fonts, sounds, tabs, popup rules, history options |
| Filters | on | Whisper and chat filters |
| Player Aliases | on | The nicknames you gave players |
| Conversation History | off | Your saved whisper conversations |

### Dworak Modules

| Option | Default | What it does |
| --- | --- | --- |
| One tick box per module | ticked | Which modules go into the export string |

Layouts, setting sets, tick boxes and backups are saved for the whole WoW account in `EllesmereUIBarProfilesDB`, not per EllesmereUI profile.

## How it works

- **Spells** are placed from the spellbook with `C_SpellBook.PickupSpellBookItem` (by spell ID, else by name and rank), with `PickupSpell` only as a last resort.
- **Macros on buttons:** `GetActionInfo` returns a macro's spell rather than its index, so a macro button is picked up and put straight back to read the index from the cursor.
- **New spells:** the game pushes every newly learned spell onto an empty Action Bar 1 slot (`SPELL_PUSHED_TO_ACTIONBAR`). Fill In When Learned moves it to its layout button and clears the pushed copy.
- **Game Settings:** the CVar list comes from `C_Console.GetAllCommands`. `C_CVar.GetCVarInfo` tells account, character and PC settings apart, and which ones are locked, secure or read-only (those are never touched). Each setting is read back after it is set and retried once a second later.
- **Addon data** (auras, Leatrix Plus, WIM, Dworak modules): an import writes into the addon's own saved tables **in place** (same table, new contents), so the running addon and the game save exactly what was imported, then the UI reloads. What is about to be replaced is backed up first for Undo.
- **Strings:** a small serializer of its own (no `loadstring`: imported strings are only ever read as data) and LibDeflate, which ships with EllesmereUI. Prefixes: `!EUIBP1!` (Action Bars), `!EUIGS1!` (Game Settings), `!EUIFA1!` (ForeverAuras), `!EUISF1!` (Spark Forever), `!EUILP1!` (Leatrix Plus), `!EUIWIM1!` (WIM), `!EUIDM1!` (Dworak Modules).
- Loading and saving only run out of combat.
- No EllesmereUI file is modified. The module registers through `EllesmereUIDworak.AddModule`.

## Known limitations

- **Early version.** The Game Settings tab is tested in game. The Action Bars tab, the aura imports and the Leatrix Plus, WIM and Dworak Modules tabs are not fully tested yet. Please report anything odd together with the `/abp report` output.
- The game doesn't let an addon put a spell the character hasn't learned on a button: such buttons stay free until Fill In When Learned can fill them.
- **Sticky Targeting** can't be set by an addon (the game ignores it). After a load the report tells you to tick or untick it by hand in *Esc > Options > Controls*.
- The pet bar is not saved (pet actions belong to the pet).
- Key bindings made with the old "bind a spell / macro / item to a key" method (not a command) are not saved.
- Items you don't carry may not be placeable; they are listed in the report.
- Dworak Modules: Unlock Mode attachments between frames (anchors, width / height matching) don't come along; each module's own position does.
- Auras can run their own code: only import aura strings you made yourself or trust.

## Author

Dworak
