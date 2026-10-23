if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_Options.lua
--  Dworak > Profiles, "Action Bars" tab: save, pick, load, export,
--  import, rename and delete layouts, and what a load touches. Built with
--  EllesmereUI's own widget factory and popups.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
local DW = EllesmereUIDworak
if not (BP and DW) then return end

local PAGE = "Action Bars"   -- first tab; more profile types get tabs of their own later
local MODULE_KEY = "BarProfiles"

-- Rebuilds the page when it is showing (the layout list and labels are built
-- into it), else drops the cached copy so the next visit builds it fresh.
local function Rebuild()
    local key = EllesmereUI.GetPluginModuleKey and EllesmereUI.GetPluginModuleKey(DW.ID, MODULE_KEY)
    if key and EllesmereUI.GetActiveModule and EllesmereUI:GetActiveModule() == key then
        EllesmereUI:RefreshPage(true)
    elseif key and EllesmereUI.InvalidateModulePageCache then
        EllesmereUI:InvalidateModulePageCache(key)
    end
end
BP.Rebuild = Rebuild

local function DateText(t)
    return t and date("%Y-%m-%d %H:%M", t) or "?"
end

-- "|cffClassName|r" for the dropdown and the info line.
local function Colored(name, L)
    if L and L.backup then return "|cff999999" .. name .. "|r" end
    return BP.ClassHex(L and L.class) .. name .. "|r"
end

local function Who(L)
    local who = (L.char or "?"):match("^([^%-]+)") or L.char or "?"
    return BP.ClassHex(L.class) .. who .. "|r"
        .. " |cff999999(" .. (L.level and ("Lvl " .. L.level .. " ") or "") .. BP.ClassName(L.class) .. ")|r"
end

-------------------------------------------------------------------------------
--  Actions
-------------------------------------------------------------------------------
local function AskSave()
    if InCombatLockdown() then
        BP.Say("layouts can only be saved out of combat.")
        return
    end
    EllesmereUI:ShowInputPopup({
        title = "Save Current Layout",
        message = "Your action bars, macros and key bindings, saved for every character of this account.",
        placeholder = "Layout name...",
        initialText = (UnitName("player") or "Layout") .. " " .. date("%m-%d"),
        maxLetters = 40,
        confirmText = "Save",
        onConfirm = function(text)
            text = strtrim(text or "")
            if text == "" then return end
            local function DoSave()
                local L = BP.Save(text)
                if L then
                    BP.Say(string.format("saved %s%s|r: %d actions, %d macros, %d key bindings.",
                        BP.AccentHex(), text, L.nSlots, L.nMacros, L.nBinds))
                    Rebuild()
                end
            end
            if BP.DB().layouts[text] then
                C_Timer.After(0, function()
                    EllesmereUI:ShowConfirmPopup({
                        title = "Overwrite Layout",
                        message = "A layout called " .. text .. " already exists. Overwrite it with your current bars?",
                        confirmText = "Overwrite",
                        onConfirm = DoSave,
                    })
                end)
            else
                DoSave()
            end
        end,
    })
end

local function AskLoad(name)
    local L = name and BP.DB().layouts[name]
    if not L then return end
    if InCombatLockdown() then
        BP.Say("layouts can only be loaded out of combat.")
        return
    end
    local parts = {}
    if BP.Get("doBars") then parts[#parts + 1] = "action bars" end
    if BP.Get("doMacros") and (L.nMacros or 0) > 0 then parts[#parts + 1] = (L.nMacros or 0) .. " macros" end
    if BP.Get("doBinds") then parts[#parts + 1] = "key bindings" end
    if #parts == 0 then
        BP.Say("nothing to load: Action Bars, Macros and Key Bindings are all off.")
        return
    end
    local msg = "Load " .. Colored(name, L) .. " on this character?\n" .. table.concat(parts, ", ") .. " will be replaced."

    local _, myClass = UnitClass("player")
    local warn = {}
    if L.class and L.class ~= myClass then
        warn[#warn + 1] = "Saved on a " .. BP.ClassName(L.class) .. "."
    end
    if BP.Get("doBars") then
        local missing = BP.MissingSpells(L)
        if #missing > 0 then
            local shown = {}
            for i = 1, math.min(#missing, 6) do shown[i] = missing[i] end
            local list = table.concat(shown, ", ") .. (#missing > 6 and ", ..." or "")
            if BP.Get("fillLearned") then
                warn[#warn + 1] = #missing .. " spell" .. (#missing > 1 and "s" or "") .. " not learned yet ("
                    .. list .. "): their buttons wait for them and are filled in when you learn them."
            elseif BP.Get("placeUnlearned") then
                warn[#warn + 1] = #missing .. " spell" .. (#missing > 1 and "s" or "") .. " not learned yet ("
                    .. list .. "): placed if the game allows it."
            else
                warn[#warn + 1] = #missing .. " spell" .. (#missing > 1 and "s" or "") .. " not known here: " .. list
            end
        end
    end
    if BP.Get("backup") and not L.backup then
        warn[#warn + 1] = "|cff999999Your current bars are backed up first (" .. BP.BACKUP_PREFIX .. (UnitName("player") or "?") .. ").|r"
    end

    EllesmereUI:ShowConfirmPopup({
        title = "Load Layout",
        message = msg,
        disclaimer = #warn > 0 and table.concat(warn, "\n") or nil,
        confirmText = "Load",
        onConfirm = function()
            BP.Load(name)
            Rebuild()
        end,
    })
end

local function DoExport(name)
    local L = name and BP.DB().layouts[name]
    if not L then return end
    local str = BP.ExportString(L)
    if not str then
        BP.Say("export failed: LibDeflate is missing.")
        return
    end
    EllesmereUI:ShowCopyPopup("Export Layout", name .. " - copy the string below and share it", str)
end

local function AskImport()
    EllesmereUI:ShowImportPopup(function(str)
        local L, err = BP.DecodeString(str)
        if not L then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowInputPopup({
                title = "Name the Layout",
                message = string.format("%d actions, %d macros, %d key bindings.", L.nSlots, L.nMacros, L.nBinds),
                placeholder = "Layout name...",
                initialText = BP.FreeName(L.name),
                maxLetters = 40,
                confirmText = "Save",
                onConfirm = function(text)
                    text = strtrim(text or "")
                    if text == "" then return end
                    text = BP.FreeName(text)
                    L.name = text
                    BP.DB().layouts[text] = L
                    BP.Set("selected", text)
                    BP.Say("imported " .. BP.AccentHex() .. text .. "|r. Pick it and press Load to use it.")
                    Rebuild()
                end,
            })
        end)
    end, "Import Layout", "Paste a Profiles > Action Bars string below")
end

local function AskRename(name)
    if not name then return end
    EllesmereUI:ShowInputPopup({
        title = "Rename Layout",
        placeholder = "New name...",
        initialText = name,
        maxLetters = 40,
        confirmText = "Rename",
        onConfirm = function(text)
            text = strtrim(text or "")
            if text == "" or text == name then return end
            if BP.DB().layouts[text] then
                BP.Say("a layout called " .. text .. " already exists.")
                return
            end
            BP.Rename(name, text)
            Rebuild()
        end,
    })
end

local function AskDelete(name)
    if not name then return end
    EllesmereUI:ShowConfirmPopup({
        title = "Delete Layout",
        message = "Delete " .. Colored(name, BP.DB().layouts[name]) .. "? This can't be undone.",
        confirmText = "Delete",
        onConfirm = function()
            BP.Delete(name)
            Rebuild()
        end,
    })
end

local function AskUpdate(name)
    if not name then return end
    if InCombatLockdown() then
        BP.Say("layouts can only be saved out of combat.")
        return
    end
    EllesmereUI:ShowConfirmPopup({
        title = "Update Layout",
        message = "Overwrite " .. Colored(name, BP.DB().layouts[name]) .. " with the bars, macros and key bindings you have now?",
        confirmText = "Overwrite",
        onConfirm = function()
            local L = BP.Save(name)
            if L then
                BP.Say(string.format("updated %s%s|r: %d actions, %d macros, %d key bindings.",
                    BP.AccentHex(), name, L.nSlots, L.nMacros, L.nBinds))
            end
            Rebuild()
        end,
    })
end

BP.AskSave, BP.AskLoad, BP.AskImport, BP.DoExport = AskSave, AskLoad, AskImport, DoExport

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function BuildPage(pageName, parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local layouts = BP.DB().layouts
    local names = BP.SortedNames()
    local sel = BP.Selected()
    local L = sel and layouts[sel]
    local function none() return BP.Selected() == nil end
    local NONE_TIP = "Save or import a layout first."

    local function Toggle(key, text, tooltip, disabled, disabledTooltip)
        return { type = "toggle", text = text, tooltip = tooltip,
                 disabled = disabled, disabledTooltip = disabledTooltip,
                 getValue = function() return BP.Get(key) and true or false end,
                 setValue = function(v)
                     BP.Set(key, v and true or false)
                     EllesmereUI:RefreshPage()
                 end }
    end

    ---------------------------------------------------------------------------
    --  SAVE
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "SAVE", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Save Current Layout", buttonText = "Save As...",
          tooltip = "Saves what is on your action bars, your macros and your key bindings under a name. "
              .. "Every character of this account can load it.",
          onClick = AskSave },
        { type = "labeledButton", text = "Import String", buttonText = "Paste String...",
          tooltip = "Adds a layout from an export string (from another account or a friend).",
          onClick = AskImport }
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  SAVED LAYOUTS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "SAVED LAYOUTS", y);  y = y - h

    if not L then
        _, h = W:DualRow(parent, y,
            { type = "label", text = "|cff999999No saved layouts yet. Press Save As... above.|r" },
            BLANK()
        );  y = y - h
    else
        local values, order = {}, {}
        for _, n in ipairs(names) do
            values[n] = Colored(n, layouts[n])
            order[#order + 1] = n
        end

        _, h = W:DualRow(parent, y,
            { type = "dropdown", text = "Layout", values = values, order = order, dropdownWidth = 210,
              tooltip = "The layout the buttons below work on. Backups (grey) are made before every load.",
              getValue = function() return BP.Selected() end,
              setValue = function(v)
                  BP.Set("selected", v)
                  Rebuild()
              end },
            { type = "labeledButton", text = "Load Layout", buttonText = "Load",
              tooltip = "Puts this layout on this character, with the Load Options below. "
                  .. "Spells this character hasn't learned yet are listed before loading.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskLoad(BP.Selected()) end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "label", text = "Saved by " .. Who(L) },
            { type = "label", text = string.format("|cff999999%s  ·  %d actions · %d macros · %d keys|r",
                DateText(L.time), L.nSlots or 0, L.nMacros or 0, L.nBinds or 0) }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "labeledButton", text = "Export String", buttonText = "Export",
              tooltip = "A string to copy: import it with Paste String... on another account.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() DoExport(BP.Selected()) end },
            { type = "labeledButton", text = "Update Layout", buttonText = "Overwrite",
              tooltip = "Saves your current bars, macros and key bindings into this layout.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskUpdate(BP.Selected()) end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "labeledButton", text = "Rename Layout", buttonText = "Rename...",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskRename(BP.Selected()) end },
            { type = "labeledButton", text = "Delete Layout", buttonText = "Delete",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskDelete(BP.Selected()) end }
        );  y = y - h
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  LOAD OPTIONS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "LOAD OPTIONS", y);  y = y - h

    local function barsOff() return not BP.Get("doBars") end
    local function macrosOff() return not BP.Get("doMacros") end
    local function bindsOff() return not BP.Get("doBinds") end

    _, h = W:DualRow(parent, y,
        Toggle("doBars", "Action Bars",
            "Puts the saved spells, macros and items on the same buttons (every bar, stance and form pages too)."),
        Toggle("doMacros", "Macros",
            "Creates the layout's macros that this character doesn't have yet (character macros stay character "
            .. "macros while there is room).")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("doBinds", "Key Bindings",
            "Sets the saved keys on the same commands, then saves them to your current binding set "
            .. "(character or account)."),
        { type = "dropdown", text = "Spell Rank",
          values = { highest = "Highest Known", same = "Same Rank" }, order = { "highest", "same" },
          tooltip = "Highest Known: the highest rank of each spell this character knows.\n"
              .. "Same Rank: the saved rank when this character knows it, else the highest it knows "
              .. "(keeps down-ranked spells).",
          disabled = barsOff, disabledTooltip = "Action Bars",
          getValue = function() return BP.Get("rankMode") end,
          setValue = function(v) BP.Set("rankMode", v) end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("clearEmpty", "Clear Other Slots",
            "Buttons that are empty in the layout (or whose spell can't be placed) are emptied. "
            .. "Off: they keep what they have.", barsOff, "Action Bars"),
        Toggle("updateMacros", "Update Same-Name Macros",
            "A macro with the same name but other text is overwritten with the layout's text. "
            .. "Off: a second macro is created.", macrosOff, "Macros")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("clearBinds", "Clear Other Key Bindings",
            "Keys bound to commands the layout leaves unbound are cleared, so the bindings match exactly.",
            bindsOff, "Key Bindings"),
        Toggle("backup", "Backup Before Load",
            "Saves your current bars as \"" .. BP.BACKUP_PREFIX .. "<name>\" before loading, "
            .. "so Undo Last Load can bring them back.")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("placeUnlearned", "Place Unlearned Spells",
            "Tries to put spells this character hasn't learned yet on their buttons, as the saved rank. The game "
            .. "may refuse it; Fill In When Learned then keeps those buttons free until they are learned.",
            barsOff, "Action Bars"),
        Toggle("fillLearned", "Fill In When Learned",
            "Buttons of the last load whose spell isn't learned yet are kept free. When you learn it (trainer, "
            .. "level up) it goes on its own button, and the copy the game drops on Action Bar 1 by itself is "
            .. "removed. Lower ranks are swapped up until the saved rank. Buttons you change yourself are left alone.")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Undo Last Load", buttonText = "Restore Backup",
          tooltip = "Loads this character's backup (made before the last load).",
          disabled = function() return BP.BackupName() == nil end,
          disabledTooltip = "No backup of this character yet: one is made before each load while Backup Before Load is on.", rawTooltip = true,
          onClick = function() local b = BP.BackupName(); if b then AskLoad(b) end end },
        { type = "labeledButton", text = "Last Load Report", buttonText = "Show in Chat",
          tooltip = "What the last load placed, cleared and couldn't place.",
          disabled = function() return BP.lastReport == nil end,
          disabledTooltip = "Nothing loaded yet this session.", rawTooltip = true,
          onClick = function() BP.PrintReport() end }
    );  y = y - h

    return math.abs(y)
end

-------------------------------------------------------------------------------
--  Registration: the "Profiles" row of the "Dworak" section (tabs: Action Bars).
-------------------------------------------------------------------------------
DW.AddModule({
    key         = MODULE_KEY,
    title       = "Profiles",
    order       = 5,
    description = "Saved setups you can load on any character or account: action bars, macros and key bindings; the game's own settings; every ForeverAuras and Spark Forever aura; Leatrix Plus; WIM; the Dworak modules' settings; or all of them in one string.",
    pages       = { PAGE, "Game Settings", "ForeverAuras", "Spark Forever", "Leatrix Plus", "WIM", "Dworak Modules",
                    "All in One" },
    -- Tabs: Action Bars (this file), Game Settings (_GameSettings.lua),
    -- ForeverAuras + Spark Forever (_ForeverAuras.lua, one MakeAuraTab each),
    -- Leatrix Plus (_Leatrix.lua), WIM (_WIM.lua), Dworak Modules (_Dworak.lua),
    -- All in One (_AllInOne.lua: the other tabs in one string).
    buildPage   = function(pageName, parent, yOffset)
        if pageName == "All in One" and BP.AIO then
            return BP.AIO.BuildPage(parent, yOffset)
        end
        if pageName == "Game Settings" and BP.GS then
            return BP.GS.BuildPage(parent, yOffset)
        end
        if pageName == "ForeverAuras" and BP.FA then
            return BP.FA.BuildPage(parent, yOffset)
        end
        if pageName == "Spark Forever" and BP.SF then
            return BP.SF.BuildPage(parent, yOffset)
        end
        if pageName == "Leatrix Plus" and BP.LP then
            return BP.LP.BuildPage(parent, yOffset)
        end
        if pageName == "WIM" and BP.WM then
            return BP.WM.BuildPage(parent, yOffset)
        end
        if pageName == "Dworak Modules" and BP.DM then
            return BP.DM.BuildPage(parent, yOffset)
        end
        return BuildPage(pageName, parent, yOffset)
    end,
})

-- /abp (or /barprofiles): opens the page.
-- /abp save <name> | load <name> | list | export <name> | report
SLASH_EUIBARPROFILES1 = "/barprofiles"
SLASH_EUIBARPROFILES2 = "/abp"
SlashCmdList.EUIBARPROFILES = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "save" and rest ~= "" then
        local L = BP.Save(rest)
        if L then
            BP.Say(string.format("saved %s%s|r: %d actions, %d macros, %d key bindings.",
                BP.AccentHex(), rest, L.nSlots, L.nMacros, L.nBinds))
            Rebuild()
        end
    elseif cmd == "load" and rest ~= "" then
        if BP.DB().layouts[rest] then AskLoad(rest) else BP.Say("no layout called " .. rest .. ".") end
    elseif cmd == "export" and rest ~= "" then
        DoExport(rest)
    elseif cmd == "list" then
        local names = BP.SortedNames()
        if #names == 0 then BP.Say("no saved layouts.") end
        for _, n in ipairs(names) do
            local L = BP.DB().layouts[n]
            BP.Say(Colored(n, L) .. " |cff999999- " .. DateText(L.time) .. ", "
                .. (L.nSlots or 0) .. " actions|r")
        end
    elseif cmd == "gs" or cmd == "settings" then
        DW.Open(MODULE_KEY, "Game Settings")
    elseif cmd == "fa" or cmd == "auras" then
        DW.Open(MODULE_KEY, "ForeverAuras")
    elseif cmd == "sf" or cmd == "spark" then
        DW.Open(MODULE_KEY, "Spark Forever")
    elseif cmd == "lp" or cmd == "leatrix" then
        DW.Open(MODULE_KEY, "Leatrix Plus")
    elseif cmd == "wim" then
        DW.Open(MODULE_KEY, "WIM")
    elseif cmd == "dm" or cmd == "dworak" or cmd == "modules" then
        DW.Open(MODULE_KEY, "Dworak Modules")
    elseif cmd == "aio" or cmd == "all" then
        DW.Open(MODULE_KEY, "All in One")
    elseif cmd == "report" then
        BP.PrintReport()
    elseif cmd == "pending" then
        local n = BP.CountPending()
        BP.Say(n .. " button" .. (n == 1 and "" or "s") .. " waiting for a spell to be learned.")
        for slot, p in pairs(BP.Pending()) do
            BP.Say("  slot " .. slot .. ": " .. tostring(p.n) .. (p.r and (" (" .. p.r .. ")") or "")
                .. " |cff999999now " .. tostring(p.cur) .. "|r")
        end
    elseif cmd == "fill" then
        local n = BP.FillPending()
        if n == 0 then BP.Say("nothing to update.") end
    else
        DW.Open(MODULE_KEY)
    end
end
