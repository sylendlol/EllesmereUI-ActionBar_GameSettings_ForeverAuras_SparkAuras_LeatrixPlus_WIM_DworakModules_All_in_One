if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_Dworak.lua
--  Dworak > Profiles, "Dworak Modules" tab: the settings of the Dworak
--  modules (Ammo Counter, Bag Cleaner, Food Timer, Loot Tracker, ...) you
--  tick, in one string, and that string put on another account in one go.
--
--  The modules are found at run time: every installed addon that depends on
--  EllesmereUIDworak (required or optional), Profiles itself left out, plus
--  the EXTRA add-ons (Durability Tip, Gold Names: own SV only). Its
--  settings can live in two places, both are taken:
--    lite: EllesmereUIDB.profiles[<active EUI profile>].addons[<folder>]
--          (EllesmereUI.Lite.NewDB: per EllesmereUI profile)
--    sv:   the addon's own SavedVariable <folder>DB, when it keeps data there
--          (Lite empties it; e.g. Loot Tracker keeps its settings there)
--  Per-character SavedVariables are character data and are left out.
--
--  Import replaces those tables IN PLACE (same table, new contents), so the
--  live addon and EllesmereUI's logout handler save the imported settings,
--  then the UI reloads. The tables being replaced are kept (dmBackup) for
--  Undo Last Import. Lite settings go into the ACTIVE EllesmereUI profile.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

local DM = {}
BP.DM = DM

DM.PAGE          = "Dworak Modules"
DM.EXPORT_PREFIX = "!EUIDM1!"
local SELF = "EllesmereUIBarProfiles"
local HOST = "EllesmereUIDworak"

local function Copy(v, depth)
    if type(v) ~= "table" then return v end
    depth = depth or 0
    if depth > 40 then return {} end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x, depth + 1) end
    return t
end

local function Replace(dst, src)
    wipe(dst)
    for k, v in pairs(src) do dst[k] = Copy(v) end
end

local function CountKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

local AddOns = C_AddOns or {}
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return select(2, unpack(r))
end

local function IsLoaded(name)
    local l = Call(AddOns.IsAddOnLoaded, name)
    if l == nil then l = Call(_G.IsAddOnLoaded, name) end
    return l and true or false
end

-- "|cff0cd29fEllesmereUI|r Ammo Counter" -> "Ammo Counter"
local function CleanTitle(title, name)
    local t = tostring(title or name or "?")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    t = t:gsub("^%s*EllesmereUI%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then t = name end
    return t
end

local function DependsOnHost(i)
    for _, fn in ipairs({ AddOns.GetAddOnDependencies, _G.GetAddOnDependencies,
                          AddOns.GetAddOnOptionalDependencies, _G.GetAddOnOptionalDependencies }) do
        local deps = { Call(fn, i) }
        for _, d in ipairs(deps) do
            if d == HOST then return true end
        end
    end
    return false
end

-- Add-ons from this project that are not in the Dworak section but keep their
-- settings in their own <folder>DB, which EllesmereUI's full export doesn't
-- carry. Listed with the modules so they can travel too.
local EXTRA = {
    EllesmereUI_DurabilityTip = true,   -- EllesmereUI_DurabilityTipDB
    EllesmereUI_GoldNames     = true,   -- EllesmereUI_GoldNamesDB
}
DM.EXTRA = EXTRA

-- Every installed Dworak module (+ EXTRA): { name, title, loaded }, sorted by title.
function DM.Modules()
    local list = {}
    local num = Call(AddOns.GetNumAddOns) or Call(_G.GetNumAddOns) or 0
    for i = 1, num do
        local name, title = Call(AddOns.GetAddOnInfo, i)
        if not name then name, title = Call(_G.GetAddOnInfo, i) end
        if name and name ~= SELF and name ~= HOST and (EXTRA[name] or DependsOnHost(i)) then
            list[#list + 1] = { name = name, title = CleanTitle(title, name), loaded = IsLoaded(name) }
        end
    end
    table.sort(list, function(a, b) return a.title:lower() < b.title:lower() end)
    return list
end

local function ActiveProfile()
    local db = _G.EllesmereUIDB
    local p = db and db.activeProfile or "Default"
    return p
end

-- The live tables of one module: lite (may be nil), sv (may be nil).
local function Tables(name, create)
    local lite
    local db = _G.EllesmereUIDB
    if type(db) == "table" then
        local prof = type(db.profiles) == "table" and db.profiles[ActiveProfile()]
        if create and type(db.profiles) ~= "table" then db.profiles = {} end
        if create and type(prof) ~= "table" then
            prof = {}
            db.profiles[ActiveProfile()] = prof
        end
        if type(prof) == "table" then
            if create and type(prof.addons) ~= "table" then prof.addons = {} end
            local addons = prof.addons
            if type(addons) == "table" then
                if create and type(addons[name]) ~= "table" then addons[name] = {} end
                lite = type(addons[name]) == "table" and addons[name] or nil
            end
        end
    end
    local sv = _G[name .. "DB"]
    if type(sv) ~= "table" then sv = nil end
    return lite, sv
end

-- A copy of one module's settings: { lite = {...}?, sv = {...}? } and a count.
function DM.Snapshot(name)
    local lite, sv = Tables(name)
    local out, n = {}, 0
    if lite and next(lite) then
        out.lite = Copy(lite)
        n = n + CountKeys(lite)
    end
    if sv and next(sv) then
        out.sv = Copy(sv)
        n = n + CountKeys(sv)
    end
    if not out.lite and not out.sv then return nil, 0 end
    return out, n
end

-------------------------------------------------------------------------------
--  Selection (opt dmSel[name], default ticked)
-------------------------------------------------------------------------------
function DM.Selected(name)
    local sel = BP.Get("dmSel")
    if type(sel) ~= "table" or sel[name] == nil then return true end
    return sel[name] and true or false
end

function DM.SetSelected(name, v)
    local sel = BP.Get("dmSel")
    if type(sel) ~= "table" then
        sel = {}
        BP.Set("dmSel", sel)
    end
    sel[name] = v and true or false
end

-------------------------------------------------------------------------------
--  Export / decode / apply
-------------------------------------------------------------------------------
-- The export data (also used by All in One): payload, titles, setting count.
function DM.Payload()
    local mods, titles, total = {}, {}, 0
    for _, m in ipairs(DM.Modules()) do
        if DM.Selected(m.name) then
            local snap, n = DM.Snapshot(m.name)
            if snap then
                snap.title = m.title
                mods[m.name] = snap
                titles[#titles + 1] = m.title
                total = total + n
            end
        end
    end
    if #titles == 0 then return nil, "none of the ticked modules has settings to export" end
    return { v = 1, char = BP.CharKey(), time = time(), mods = mods }, titles, total
end

function DM.ExportString()
    local payload, titles, total = DM.Payload()
    if not payload then return nil, titles end
    local str = BP.Pack(DM.EXPORT_PREFIX, payload)
    if not str then return nil, "LibDeflate is missing" end
    return str, titles, total
end

function DM.DecodeString(str)
    local raw, err = BP.Unpack(DM.EXPORT_PREFIX, str)
    if not raw then
        if err == "wrong kind of string" then err = "this is not a Profiles > Dworak Modules string" end
        return nil, err
    end
    return DM.FromRaw(raw)
end

function DM.FromRaw(raw)
    if type(raw) ~= "table" or type(raw.mods) ~= "table" then return nil, "the string is damaged (data)" end
    local mods, count = {}, 0
    for name, m in pairs(raw.mods) do
        if type(name) == "string" and name:find("^[%w_%-]+$") and type(m) == "table"
                and (type(m.lite) == "table" or type(m.sv) == "table") then
            mods[name] = {
                title = type(m.title) == "string" and m.title:sub(1, 48) or name,
                lite = type(m.lite) == "table" and m.lite or nil,
                sv = type(m.sv) == "table" and m.sv or nil,
            }
            count = count + 1
        end
    end
    if count == 0 then return nil, "the string holds no module settings" end
    return { mods = mods, count = count, char = type(raw.char) == "string" and raw.char or nil,
             time = type(raw.time) == "number" and raw.time or nil }
end

-- Puts the given modules' settings in place. Returns the titles applied and
-- the titles skipped (module not installed / not loaded here).
function DM.Apply(mods, backup)
    local applied, skipped, saved = {}, {}, {}
    for name, m in pairs(mods) do
        if IsLoaded(name) then
            if backup then saved[name] = { title = m.title, (DM.Snapshot(name)) } end
            local lite, sv = Tables(name, m.lite ~= nil)
            if m.lite and lite then Replace(lite, m.lite) end
            if m.sv then
                if sv then Replace(sv, m.sv) else _G[name .. "DB"] = Copy(m.sv) end
            end
            applied[#applied + 1] = m.title or name
        else
            skipped[#skipped + 1] = m.title or name
        end
    end
    if backup then
        -- Undo puts back exactly the modules this import touched.
        local B = { time = time(), mods = {} }
        for name, s in pairs(saved) do
            local snap = s[1] or {}
            -- A table the import filled that was empty before goes back to empty.
            B.mods[name] = { title = s.title, lite = snap.lite or {},
                             sv = snap.sv or (mods[name].sv and {} or nil) }
        end
        BP.Set("dmBackup", B)
    end
    table.sort(applied)
    table.sort(skipped)
    return applied, skipped
end

-------------------------------------------------------------------------------
--  Page actions
-------------------------------------------------------------------------------
local function DoExport()
    local str, titles, total = DM.ExportString()
    if not str then
        BP.Say("|cffff4040export failed:|r " .. tostring(titles))
        return
    end
    EllesmereUI:ShowCopyPopup("Export Dworak Modules",
        string.format("%d modules (%s) - copy the string and paste it on the other account", #titles,
            table.concat(titles, ", ")), str)
end

local function AskImport()
    EllesmereUI:ShowImportPopup(function(str)
        local P, err = DM.DecodeString(str)
        if not P then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        local here, missing = {}, {}
        for name, m in pairs(P.mods) do
            if IsLoaded(name) then here[#here + 1] = m.title else missing[#missing + 1] = m.title end
        end
        table.sort(here)
        table.sort(missing)
        if #here == 0 then
            BP.Say("none of the modules in the string is installed and enabled here: " .. table.concat(missing, ", "))
            return
        end
        local who = P.char and (P.char:match("^([^%-]+)") or P.char) or "?"
        local warn = "|cff999999Their current settings are kept for Undo Last Import. Settings stored per "
            .. "EllesmereUI profile go into the active one (" .. tostring(ActiveProfile()) .. ").|r"
        if #missing > 0 then
            warn = "|cffffd040Not installed / enabled here, skipped: " .. table.concat(missing, ", ") .. "|r\n" .. warn
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowConfirmPopup({
                title = "Import Dworak Modules",
                message = string.format("Settings from %s%s for:\n%s\nThey replace these modules' settings, then the "
                    .. "UI reloads.", who, P.time and (" (" .. date("%Y-%m-%d", P.time) .. ")") or "",
                    table.concat(here, ", ")),
                disclaimer = warn,
                confirmText = "Import & Reload",
                reload = true,
                onConfirm = function() DM.Apply(P.mods, true) end,
            })
        end)
    end, "Import Dworak Modules", "Paste a Profiles > Dworak Modules string below")
end

local function AskUndo()
    local B = BP.Get("dmBackup")
    if type(B) ~= "table" or type(B.mods) ~= "table" then return end
    local titles = {}
    for name, m in pairs(B.mods) do titles[#titles + 1] = m.title or name end
    table.sort(titles)
    EllesmereUI:ShowConfirmPopup({
        title = "Undo Last Import",
        message = "Put back the settings these modules had before the last import (" .. (B.time and
            date("%Y-%m-%d %H:%M", B.time) or "?") .. ")?\n" .. table.concat(titles, ", ") .. "\nThe UI reloads.",
        confirmText = "Restore & Reload",
        reload = true,
        onConfirm = function()
            DM.Apply(B.mods, false)
            BP.Set("dmBackup", nil)
        end,
    })
end

DM.DoExport, DM.AskImport, DM.AskUndo = DoExport, AskImport, AskUndo

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
function DM.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local mods = DM.Modules()

    _, h = W:SectionHeader(parent, "DWORAK MODULES", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = "|cff999999Tick the modules whose settings go into the export string. Settings kept "
              .. "per EllesmereUI profile come from the active one (" .. tostring(ActiveProfile()) .. ").|r" }
    );  y = y - h

    local function ModToggle(m)
        if not m then return BLANK() end
        local _, n = DM.Snapshot(m.name)
        return { type = "toggle", text = m.title,
                 tooltip = (m.loaded and (n > 0 and (n .. " saved settings.") or "Nothing saved yet (all defaults)."))
                     or "Not enabled: nothing to export, and an import skips it.",
                 disabled = function() return not m.loaded end,
                 disabledTooltip = "Not enabled on this character.", rawTooltip = true,
                 getValue = function() return DM.Selected(m.name) end,
                 setValue = function(v) DM.SetSelected(m.name, v) end }
    end
    if #mods == 0 then
        _, h = W:DualRow(parent, y, { type = "label", text = "|cffff4040No Dworak modules found.|r" });  y = y - h
    end
    for i = 1, #mods, 2 do
        _, h = W:DualRow(parent, y, ModToggle(mods[i]), ModToggle(mods[i + 1]));  y = y - h
    end

    _, h = W:DualRow(parent, y,
        { type = "button", text = "Tick All", width = 160,
          onClick = function()
              for _, m in ipairs(DM.Modules()) do DM.SetSelected(m.name, true) end
              EllesmereUI:RefreshPage()
          end },
        { type = "button", text = "Untick All", width = 160,
          onClick = function()
              for _, m in ipairs(DM.Modules()) do DM.SetSelected(m.name, false) end
              EllesmereUI:RefreshPage()
          end }
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h
    _, h = W:SectionHeader(parent, "EXPORT / IMPORT", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Export Ticked Modules", buttonText = "Export",
          tooltip = "The settings of the ticked modules in one string. Paste it on the other account with "
              .. "Import Settings.",
          onClick = DoExport },
        { type = "labeledButton", text = "Import Settings", buttonText = "Paste String...",
          tooltip = "Replaces the settings of every module in the string that is enabled here, then reloads the UI. "
              .. "Shows the list first.",
          onClick = AskImport }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Undo Last Import", buttonText = "Restore Backup",
          tooltip = "Puts back the settings the modules had before the last import.",
          disabled = function() return type(BP.Get("dmBackup")) ~= "table" end,
          disabledTooltip = "No import to undo yet.", rawTooltip = true,
          onClick = AskUndo },
        BLANK()
    );  y = y - h

    return math.abs(y)
end
