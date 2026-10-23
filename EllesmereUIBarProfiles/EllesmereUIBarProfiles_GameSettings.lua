if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_GameSettings.lua
--  Dworak > Profiles, "Game Settings" tab: the game's own options (Esc >
--  Options: My Name, Auto Loot, nameplates, camera, soft targeting, ...)
--  saved under a name and put on another character or account.
--
--  Those options are CVars. The account / character ones are stored on the
--  server, so copying WTF\Account\...\config-cache.wtf does not stick (the
--  server writes its own copy back at login); setting them in game with
--  C_CVar.SetCVar does, the game saves them to the server itself.
--
--  Saved: every CVar the game keeps per account or per character, at its
--  current value (defaults too, so a setting left at default on the saving
--  account is switched back on the other one), minus internal bookkeeping
--  (tutorial flags, closed info frames, last-opened tabs, ...). Graphics and
--  sound live in Config.wtf, shared by every account on this PC: saved when
--  changed from default, loaded only with "This PC (graphics, sound)" on.
--
--  Loading only ever touches CVars the loading client has, that an addon may
--  change (not secure, not read-only, not locked) and that are not on the
--  skip list: an imported string can't reach anything else.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

local GS = {}
BP.GS = GS

GS.PAGE          = "Game Settings"
GS.EXPORT_PREFIX = "!EUIGS1!"

local GetCVar = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
local SetCVar = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
local GetCVarDefault = (C_CVar and C_CVar.GetCVarDefault) or _G.GetCVarDefault
local GetCVarInfo = (C_CVar and C_CVar.GetCVarInfo) or _G.GetCVarInfo

-------------------------------------------------------------------------------
--  Categories (first match on the lower-cased name wins; the rest is
--  "Interface"). "pc" = graphics / sound / anything kept on this PC only.
-------------------------------------------------------------------------------
GS.CATEGORIES = {
    { key = "names",      label = "Names",
      tip = "My Name, NPC names, friendly / enemy player names, minions.",
      pats = { "^unitname" } },
    { key = "nameplates", label = "Nameplates",
      tip = "Which nameplates show, their size, stacking, class colors, auras, cast bars.",
      pats = { "^nameplate", "^showfriendly", "^showenemy" } },
    { key = "loot",       label = "Loot",
      tip = "Auto Loot, loot under mouse, loot effects.",
      pats = { "loot" } },
    { key = "camera",     label = "Camera & Mouse",
      tip = "Max camera distance, camera following and smoothing, mouse speed and look.",
      pats = { "^camera", "^mouse", "^cursor", "^enablemouse", "^invertpitch" } },
    { key = "controls",   label = "Controls & Targeting",
      tip = "Soft targeting, interact key, click to move, self cast, deselect on click, auto dismount.",
      pats = { "^softtarget", "interact", "deselect", "selfcast", "clicktomove", "^autodismount",
               "^autounshift", "^autostand", "^targetnearest", "^tab", "^autoclear", "^autointeract",
               "^stopautoattack", "^autoselfcast" } },
    { key = "combat",     label = "Combat & Action Bars",
      tip = "Floating combat text, cooldown numbers, spell queue, action bar options, low health warning.",
      pats = { "combattext", "^floating", "cooldown", "^spellqueue", "^actionbutton", "^lockactionbars",
               "^alwaysshowactionbars", "lowhealth", "showtargetoftarget", "^showtargetcastbar",
               "^showspellqueue", "^enablefloating" } },
    { key = "chat",       label = "Chat & Social",
      tip = "Chat style and timestamps, whispers, profanity filter, guild / friends options, blocking.",
      pats = { "chat", "timestamp", "whisper", "profanity", "^guild", "friend", "^social", "^block",
               "^showtoast", "^spamfilter", "^colorchatnames", "^removechatdelay" } },
    { key = "interface",  label = "Interface",
      tip = "Everything else: status text, bags, tooltips, map, clock, tutorials off, ...",
      pats = {} },
    { key = "pc",         label = "This PC (graphics, sound)",
      tip = "Settings kept in Config.wtf for this PC (graphics, sound, ...). Every account on the same "
          .. "PC already shares them: only useful for another PC.", pats = {}, pc = true },
}
local CAT_BY_KEY = {}
for _, c in ipairs(GS.CATEGORIES) do CAT_BY_KEY[c.key] = c end

-- Internal bookkeeping, never worth copying (lower-case patterns).
local SKIP = {
    "tutorial", "closedinfoframe", "^last", "seen", "^petjournal", "^transmog", "perksactivit",
    "playeridentity", "showcreatecharacter", "^ej", "^lfg", "^pvpframe", "^encounterjournal",
    "allowdangerousscripts", "^portal", "^realm", "^account", "^agent", "^gxapi", "^test",
    "^lastcharacter", "^installlocale", "^textlocale", "^audiolocale", "^launcher", "^uiscale$",
    "^usecompactparty", "^shown", "orderhall", "^garrison", "^collections", "^wardrobe",
    "^toybox", "^heirloom", "^mount", "^professions", "^talentframe", "^spellbook", "^calendar",
    "^addfriendinfo", "^minimapshow", "^achievement", "^tracked", "^questlog", "^worldmapshow",
    "^characterframe", "^bag%d", "^backpack", "^bank", "^reagent", "^currency", "^majorfactions",
    "^newbie", "^checkaddonversion", "^scripterrors", "^taintlog", "^xp", "^experience",
}

local function Skipped(name)
    local lower = name:lower()
    for _, p in ipairs(SKIP) do
        if lower:find(p) then return true end
    end
    return false
end

function GS.CategoryOf(name, isPC)
    if isPC then return "pc" end
    local lower = name:lower()
    for _, c in ipairs(GS.CATEGORIES) do
        for _, p in ipairs(c.pats) do
            if lower:find(p) then return c.key end
        end
    end
    return "interface"
end

-------------------------------------------------------------------------------
--  Options (stored with the Action Bars options, "gs" prefix)
-------------------------------------------------------------------------------
local GS_DEFAULTS = {
    gsResetOthers = false,  -- Reset Other Settings
    gsBackup      = true,   -- Backup Before Load
}

function GS.Get(key)
    local v = BP.DB().opt[key]
    if v == nil then return GS_DEFAULTS[key] end
    return v
end

function GS.Set(key, value) BP.DB().opt[key] = value end

function GS.CatOn(key)
    local v = BP.DB().opt["gsCat_" .. key]
    if v == nil then return not (CAT_BY_KEY[key] and CAT_BY_KEY[key].pc) end
    return v and true or false
end

function GS.SetCatOn(key, v) BP.DB().opt["gsCat_" .. key] = v and true or false end

function GS.Store()
    local d = BP.DB()
    if type(d.settings) ~= "table" then d.settings = {} end
    return d.settings
end

-------------------------------------------------------------------------------
--  CVar list
-------------------------------------------------------------------------------
-- Every CVar name the client has.
local function AllCVars()
    local cmds
    if C_Console and C_Console.GetAllCommands then
        local ok, r = pcall(C_Console.GetAllCommands)
        if ok then cmds = r end
    end
    if not cmds and _G.ConsoleGetAllCommands then
        local ok, r = pcall(_G.ConsoleGetAllCommands)
        if ok then cmds = r end
    end
    local CVAR = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
    local out = {}
    for _, c in ipairs(cmds or {}) do
        if type(c) == "table" and c.commandType == CVAR and type(c.command) == "string" then
            out[#out + 1] = c.command
        end
    end
    return out
end
GS.AllCVars = AllCVars

-- value, default, kind ("account" / "character" / "pc"), changeable
local function Info(name)
    local value, default, acct, char, locked, secure, readOnly
    if GetCVarInfo then
        local ok, v, d, a, c, l, s, r = pcall(GetCVarInfo, name)
        if ok then value, default, acct, char, locked, secure, readOnly = v, d, a, c, l, s, r end
    end
    if value == nil then
        local ok, v = pcall(GetCVar, name)
        if ok then value = v end
    end
    if value == nil then return nil end
    if default == nil and GetCVarDefault then
        local ok, d = pcall(GetCVarDefault, name)
        if ok then default = d end
    end
    local kind = (acct and "account") or (char and "character") or "pc"
    local changeable = not (locked or secure or readOnly)
    return tostring(value), default ~= nil and tostring(default) or nil, kind, changeable
end
GS.Info = Info

-- True when the client marks no CVar as server-stored at all (an API without
-- those flags): then everything not obviously graphics / sound counts.
local PC_PATS = { "^gx", "^graphics", "^sound", "^render", "^raidgraphics", "^ffx", "^shadow",
                  "^texture", "^water", "^particle", "^projected", "^ssao", "^spelldensity",
                  "^weather", "^farclip", "^horizon", "^terrain", "^anti", "^msaa", "^maxfps",
                  "^vsync", "^gamma", "^brightness", "^contrast", "^resample", "^lod", "^physics",
                  "^audio", "^voice", "^environment", "^ambience", "^dialog", "^music", "^master" }
local function LooksPC(name)
    local lower = name:lower()
    for _, p in ipairs(PC_PATS) do
        if lower:find(p) then return true end
    end
    return false
end

-------------------------------------------------------------------------------
--  Save
-------------------------------------------------------------------------------
function GS.Capture(name)
    local _, class = UnitClass("player")
    local S = { v = 1, name = name, char = BP.CharKey(), class = class, level = UnitLevel("player"),
                time = time(), vars = {}, pc = {} }
    local names = AllCVars()
    local anyServer = false
    local rows = {}
    for _, n in ipairs(names) do
        if not Skipped(n) then
            local value, default, kind, changeable = Info(n)
            if value and changeable then
                if kind ~= "pc" then anyServer = true end
                rows[#rows + 1] = { n = n, v = value, d = default, k = kind }
            end
        end
    end
    local count = 0
    -- Account / character settings are saved at ANY value, defaults
    -- included: a setting left at default here (Sticky Targeting on =
    -- deselectOnClick "0") must still switch the other account back to it.
    -- This-PC settings only when changed from default.
    local nonDefault = 0
    for _, r in ipairs(rows) do
        local isPC = (r.k == "pc")
        if not anyServer then isPC = LooksPC(r.n) end
        local changed = (r.d == nil or r.v ~= r.d)
        if changed or not isPC then
            S.vars[r.n] = r.v
            if isPC then S.pc[r.n] = true end
            count = count + 1
            if changed then nonDefault = nonDefault + 1 end
        end
    end
    S.count, S.nonDefault = count, nonDefault
    if #names == 0 then
        BP.Say("|cffff4040the game didn't list its settings (C_Console.GetAllCommands): nothing could be saved.|r")
    end
    return S
end

function GS.Save(name, isBackup)
    if InCombatLockdown() then
        BP.Say("game settings can only be saved out of combat.")
        return nil
    end
    local S = GS.Capture(name)
    S.backup = isBackup or nil
    GS.Store()[name] = S
    if not isBackup then GS.Set("gsSelected", name) end
    return S
end

-------------------------------------------------------------------------------
--  Load
-------------------------------------------------------------------------------
-- What a load would change: { n, cur, val, cat } sorted by category, name.
function GS.Diff(S)
    local out = {}
    local order = {}
    for i, c in ipairs(GS.CATEGORIES) do order[c.key] = i end
    for n, val in pairs(S.vars or {}) do
        local cat = GS.CategoryOf(n, S.pc and S.pc[n])
        if GS.CatOn(cat) and not Skipped(n) then
            local cur, _, _, changeable = Info(n)
            if cur and changeable and cur ~= val then
                out[#out + 1] = { n = n, cur = cur, val = val, cat = cat }
            end
        end
    end
    if GS.Get("gsResetOthers") then
        for _, n in ipairs(AllCVars()) do
            if not (S.vars and S.vars[n] ~= nil) and not Skipped(n) then
                local cur, default, kind, changeable = Info(n)
                if cur and default and changeable and cur ~= default then
                    local cat = GS.CategoryOf(n, kind == "pc")
                    if GS.CatOn(cat) then
                        out[#out + 1] = { n = n, cur = cur, val = default, cat = cat, reset = true }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.cat ~= b.cat then return (order[a.cat] or 99) < (order[b.cat] or 99) end
        return a.n:lower() < b.n:lower()
    end)
    return out
end

-- Sets one CVar and reads it back: C_CVar.SetCVar, then the old global
-- SetCVar. True when the value stuck.
local function TrySet(name, val)
    pcall(SetCVar, name, val)
    if select(1, Info(name)) == val then return true end
    if _G.SetCVar and _G.SetCVar ~= SetCVar then
        pcall(_G.SetCVar, name, val)
        if select(1, Info(name)) == val then return true end
    end
    -- The console route (same as typing /console name value).
    if _G.ConsoleExec and type(val) == "string" and not val:find("[\r\n;]") then
        pcall(_G.ConsoleExec, name .. " " .. (val:find("%s") and ('"' .. val .. '"') or val))
        if select(1, Info(name)) == val then return true end
    end
    return false
end

-- Where a few settings live in Esc > Options, for the "set it by hand" hint.
-- Settings the game won't let an addon change (tested in game): never set,
-- only reported with what to do by hand.
--   deselectOnClick: SetCVar / ConsoleExec to "0" leave it at "1" (2026-10-21).
local HAND_ONLY = { deselectOnClick = true }

-- Each entry gets the wanted value and returns what to do by hand.
local HAND_HINT = {
    deselectOnClick = function(val)
        return (val == "0" and "tick" or "untick") .. " Esc > Options > Controls > Sticky Targeting"
    end,
}

-- Sets every change, then checks again a second later and retries what
-- didn't stick (some settings are written back by the game a moment after
-- an addon changes them). onDone(report) runs after that second check.
function GS.Apply(S, onDone)
    if InCombatLockdown() then
        BP.Say("game settings can only be loaded out of combat.")
        return nil
    end
    local diff, manual = {}, {}
    for _, d in ipairs(GS.Diff(S)) do
        if HAND_ONLY[d.n] then manual[#manual + 1] = d else diff[#diff + 1] = d end
    end
    for _, d in ipairs(diff) do TrySet(d.n, d.val) end
    C_Timer.After(1, function()
        local changed, failedNames = 0, {}
        for _, d in ipairs(diff) do
            local ok = select(1, Info(d.n)) == d.val
            if not ok and not InCombatLockdown() then ok = TrySet(d.n, d.val) end
            if ok then
                changed = changed + 1
            else
                failedNames[#failedNames + 1] = d
            end
        end
        if onDone then
            onDone({ name = S.name, changed = changed, failed = #failedNames, failedList = failedNames,
                     manual = manual, total = #diff })
        end
    end)
    return true
end

GS.HAND_HINT = HAND_HINT

-- onDone(rep): given by All in One, which reports itself (no chat, no popup).
function GS.Load(name, onDone)
    local S = GS.Store()[name]
    if not S then return end
    if InCombatLockdown() then
        BP.Say("game settings can only be loaded out of combat.")
        return
    end
    -- The backup holds the current value of exactly what this load changes
    -- (defaults included), so Undo Last Load puts every one of them back.
    if GS.Get("gsBackup") and not S.backup then
        local _, class = UnitClass("player")
        local bname = BP.BACKUP_PREFIX .. (UnitName("player") or "?")
        local B = { v = 1, name = bname, char = BP.CharKey(), class = class, level = UnitLevel("player"),
                    time = time(), vars = {}, pc = {}, count = 0, backup = true }
        for _, d in ipairs(GS.Diff(S)) do
            B.vars[d.n] = d.cur
            if d.cat == "pc" then B.pc[d.n] = true end
            B.count = B.count + 1
        end
        GS.Store()[bname] = B
    end
    GS.Apply(S, function(rep)
        GS.lastReport = rep
        if onDone then return onDone(rep) end
        BP.Say(string.format("game settings %s%s|r loaded: %d changed%s.", BP.AccentHex(), tostring(name),
            rep.changed, rep.failed > 0 and (", |cffff4040" .. rep.failed .. " refused by the game|r") or ""))
        for i, d in ipairs(rep.failedList) do
            if i > 10 then
                BP.Say("|cff999999... and " .. (rep.failed - 10) .. " more|r")
                break
            end
            BP.Say(string.format("|cff999999refused: %s = %s (now %s)%s|r", d.n, d.val, tostring(select(1, Info(d.n))),
                HAND_HINT[d.n] and (" - set it by hand: " .. HAND_HINT[d.n](d.val)) or ""))
        end
        for _, d in ipairs(rep.manual or {}) do
            BP.Say("|cffffd040set by hand:|r " .. (HAND_HINT[d.n] and HAND_HINT[d.n](d.val) or (d.n .. " = " .. d.val))
                .. " |cff999999(the game doesn't let addons change it)|r")
        end
        if rep.changed > 0 then
            EllesmereUI:ShowConfirmPopup({
                title = "Game Settings Loaded",
                message = rep.changed .. " settings changed. Some of them (nameplates, interface) only fully "
                    .. "apply after a reload. Reload now?",
                confirmText = "Reload",
                cancelText = "Later",
                reload = true,
            })
        end
    end)
    return true
end

function GS.BackupName()
    local n = BP.BACKUP_PREFIX .. (UnitName("player") or "?")
    if GS.Store()[n] then return n end
end

-- The changes a load would make, in chat.
function GS.PrintDiff(name)
    local S = name and GS.Store()[name]
    if not S then return end
    local diff = GS.Diff(S)
    if #diff == 0 then
        BP.Say("loading " .. tostring(name) .. " changes nothing here (with the categories switched on).")
        return
    end
    BP.Say(#diff .. " setting" .. (#diff > 1 and "s" or "") .. " would change:")
    local lastCat
    for i, d in ipairs(diff) do
        if i > 60 then
            BP.Say("|cff999999... and " .. (#diff - 60) .. " more|r")
            break
        end
        if d.cat ~= lastCat then
            lastCat = d.cat
            BP.Say(BP.AccentHex() .. (CAT_BY_KEY[d.cat] and CAT_BY_KEY[d.cat].label or d.cat) .. "|r")
        end
        BP.Say(string.format("  %s: |cff999999%s|r -> %s%s", d.n, d.cur, d.val, d.reset and " |cff999999(default)|r" or ""))
    end
end

-------------------------------------------------------------------------------
--  Strings, list helpers
-------------------------------------------------------------------------------
function GS.ExportString(S)
    local copy = {}
    for k, v in pairs(S) do copy[k] = v end
    copy.backup = nil
    return BP.Pack(GS.EXPORT_PREFIX, copy)
end

function GS.DecodeString(str)
    local raw, err = BP.Unpack(GS.EXPORT_PREFIX, str)
    if not raw then
        if err == "wrong kind of string" then err = "this is not a Profiles > Game Settings string" end
        return nil, err
    end
    return GS.FromRaw(raw)
end

-- A decoded set, cleaned field by field (it came from someone else).
function GS.FromRaw(raw)
    if type(raw) ~= "table" or type(raw.vars) ~= "table" then return nil, "the string is damaged (data)" end
    local function S_(v, max) return type(v) == "string" and v:sub(1, max or 255) or nil end
    local S = { v = 1, name = S_(raw.name, 60), char = S_(raw.char, 80), class = S_(raw.class, 20),
                level = type(raw.level) == "number" and raw.level or nil,
                time = type(raw.time) == "number" and raw.time or nil, vars = {}, pc = {} }
    local count = 0
    for n, v in pairs(raw.vars) do
        if type(n) == "string" and #n <= 64 and n:find("^[%w_]+$") and type(v) == "string" and #v <= 1024 then
            S.vars[n] = v
            if type(raw.pc) == "table" and raw.pc[n] then S.pc[n] = true end
            count = count + 1
        end
    end
    S.count = count
    return S
end

function GS.FreeName(base)
    base = (base and base ~= "") and base or "Imported"
    local store = GS.Store()
    if not store[base] then return base end
    for i = 2, 99 do
        local n = base .. " (" .. i .. ")"
        if not store[n] then return n end
    end
    return base .. " " .. time()
end

function GS.SortedNames()
    local store = GS.Store()
    local out = {}
    for n in pairs(store) do out[#out + 1] = n end
    table.sort(out, function(a, b)
        local ba, bb = store[a].backup and true or false, store[b].backup and true or false
        if ba ~= bb then return bb end
        return a:lower() < b:lower()
    end)
    return out
end

function GS.Selected()
    local sel = GS.Get("gsSelected")
    if sel and GS.Store()[sel] then return sel end
    return GS.SortedNames()[1]
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function Rebuild() if BP.Rebuild then BP.Rebuild() end end

local function Colored(name, S)
    if S and S.backup then return "|cff999999" .. name .. "|r" end
    return BP.ClassHex(S and S.class) .. name .. "|r"
end

local function AskSave()
    if InCombatLockdown() then
        BP.Say("game settings can only be saved out of combat.")
        return
    end
    EllesmereUI:ShowInputPopup({
        title = "Save Game Settings",
        message = "The game's own options (names, nameplates, loot, camera, controls, chat, ...), "
            .. "saved for every character of this account.",
        placeholder = "Name...",
        initialText = (UnitName("player") or "Settings") .. " " .. date("%m-%d"),
        maxLetters = 40,
        confirmText = "Save",
        onConfirm = function(text)
            text = strtrim(text or "")
            if text == "" then return end
            local function DoSave()
                local S = GS.Save(text)
                if S then
                    BP.Say(string.format("game settings saved as %s%s|r: %d settings.",
                        BP.AccentHex(), text, S.count))
                    Rebuild()
                end
            end
            if GS.Store()[text] then
                C_Timer.After(0, function()
                    EllesmereUI:ShowConfirmPopup({
                        title = "Overwrite Settings",
                        message = text .. " already exists. Overwrite it with your current game settings?",
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
    local S = name and GS.Store()[name]
    if not S then return end
    if InCombatLockdown() then
        BP.Say("game settings can only be loaded out of combat.")
        return
    end
    local diff = GS.Diff(S)
    if #diff == 0 then
        BP.Say("loading " .. name .. " changes nothing here (with the categories switched on).")
        return
    end
    local perCat, order = {}, {}
    for _, d in ipairs(diff) do
        if not perCat[d.cat] then
            perCat[d.cat] = 0
            order[#order + 1] = d.cat
        end
        perCat[d.cat] = perCat[d.cat] + 1
    end
    local parts = {}
    for _, k in ipairs(order) do
        parts[#parts + 1] = (CAT_BY_KEY[k] and CAT_BY_KEY[k].label or k) .. " " .. perCat[k]
    end
    local warn = {}
    if GS.Get("gsBackup") and not S.backup then
        warn[#warn + 1] = "|cff999999Your current settings are backed up first (" .. BP.BACKUP_PREFIX
            .. (UnitName("player") or "?") .. ").|r"
    end
    warn[#warn + 1] = "|cff999999Preview Changes lists every setting in chat.|r"
    EllesmereUI:ShowConfirmPopup({
        title = "Load Game Settings",
        message = "Load " .. Colored(name, S) .. "?\n" .. #diff .. " setting" .. (#diff > 1 and "s" or "")
            .. " change: " .. table.concat(parts, ", ") .. ".",
        disclaimer = table.concat(warn, "\n"),
        confirmText = "Load",
        onConfirm = function()
            GS.Load(name)
            Rebuild()
        end,
    })
end

local function DoExport(name)
    local S = name and GS.Store()[name]
    if not S then return end
    local str = GS.ExportString(S)
    if not str then
        BP.Say("export failed: LibDeflate is missing.")
        return
    end
    EllesmereUI:ShowCopyPopup("Export Game Settings", name .. " - copy the string below and paste it on the other account", str)
end

local function AskImport()
    EllesmereUI:ShowImportPopup(function(str)
        local S, err = GS.DecodeString(str)
        if not S then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowInputPopup({
                title = "Name the Settings",
                message = S.count .. " settings.",
                placeholder = "Name...",
                initialText = GS.FreeName(S.name),
                maxLetters = 40,
                confirmText = "Save",
                onConfirm = function(text)
                    text = strtrim(text or "")
                    if text == "" then return end
                    text = GS.FreeName(text)
                    S.name = text
                    GS.Store()[text] = S
                    GS.Set("gsSelected", text)
                    BP.Say("imported " .. BP.AccentHex() .. text .. "|r. Pick it and press Load to use it.")
                    Rebuild()
                end,
            })
        end)
    end, "Import Game Settings", "Paste a Profiles > Game Settings string below")
end

local function AskRename(name)
    if not name then return end
    EllesmereUI:ShowInputPopup({
        title = "Rename Settings",
        placeholder = "New name...",
        initialText = name,
        maxLetters = 40,
        confirmText = "Rename",
        onConfirm = function(text)
            text = strtrim(text or "")
            local store = GS.Store()
            if text == "" or text == name or not store[name] then return end
            if store[text] then
                BP.Say("a setting set called " .. text .. " already exists.")
                return
            end
            store[text], store[name] = store[name], nil
            store[text].name, store[text].backup = text, nil
            GS.Set("gsSelected", text)
            Rebuild()
        end,
    })
end

local function AskDelete(name)
    if not name then return end
    EllesmereUI:ShowConfirmPopup({
        title = "Delete Settings",
        message = "Delete " .. Colored(name, GS.Store()[name]) .. "? This can't be undone.",
        confirmText = "Delete",
        onConfirm = function()
            GS.Store()[name] = nil
            if GS.Get("gsSelected") == name then GS.Set("gsSelected", nil) end
            Rebuild()
        end,
    })
end

local function AskUpdate(name)
    if not name then return end
    EllesmereUI:ShowConfirmPopup({
        title = "Update Settings",
        message = "Overwrite " .. Colored(name, GS.Store()[name]) .. " with your current game settings?",
        confirmText = "Overwrite",
        onConfirm = function()
            local S = GS.Save(name)
            if S then
                BP.Say(string.format("updated %s%s|r: %d settings.", BP.AccentHex(), name, S.count))
            end
            Rebuild()
        end,
    })
end

GS.AskSave, GS.AskLoad, GS.AskImport, GS.DoExport = AskSave, AskLoad, AskImport, DoExport

function GS.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local store = GS.Store()
    local sel = GS.Selected()
    local S = sel and store[sel]
    local function none() return GS.Selected() == nil end
    local NONE_TIP = "Save or import game settings first."

    ---------------------------------------------------------------------------
    --  SAVE
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "SAVE", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Save Game Settings", buttonText = "Save As...",
          tooltip = "Saves the game's own options (Esc > Options), every one at its current value: names, "
              .. "nameplates, loot, camera, controls, combat, chat, interface.",
          onClick = AskSave },
        { type = "labeledButton", text = "Import String", buttonText = "Paste String...",
          tooltip = "Adds a setting set from an export string, e.g. one made on your other account.",
          onClick = AskImport }
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  SAVED SETTINGS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "SAVED SETTINGS", y);  y = y - h

    if not S then
        _, h = W:DualRow(parent, y,
            { type = "label", text = "|cff999999Nothing saved yet. Press Save As... above.|r" },
            BLANK()
        );  y = y - h
    else
        local values, order = {}, {}
        for _, n in ipairs(GS.SortedNames()) do
            values[n] = Colored(n, store[n])
            order[#order + 1] = n
        end
        _, h = W:DualRow(parent, y,
            { type = "dropdown", text = "Settings", values = values, order = order, dropdownWidth = 210,
              tooltip = "The setting set the buttons below work on. Backups (grey) are made before every load.",
              getValue = function() return GS.Selected() end,
              setValue = function(v)
                  GS.Set("gsSelected", v)
                  Rebuild()
              end },
            { type = "labeledButton", text = "Load Settings", buttonText = "Load",
              tooltip = "Sets these game options here, in the categories switched on below.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskLoad(GS.Selected()) end }
        );  y = y - h

        local who = (S.char or "?"):match("^([^%-]+)") or S.char or "?"
        _, h = W:DualRow(parent, y,
            { type = "label", text = "Saved by " .. BP.ClassHex(S.class) .. who .. "|r" },
            { type = "label", text = string.format("|cff999999%s  ·  %d settings|r",
                S.time and date("%Y-%m-%d %H:%M", S.time) or "?", S.count or 0) }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "labeledButton", text = "Preview Changes", buttonText = "Show in Chat",
              tooltip = "Lists every setting a load would change here: current value -> saved value.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() GS.PrintDiff(GS.Selected()) end },
            { type = "labeledButton", text = "Export String", buttonText = "Export",
              tooltip = "A string to copy: import it with Paste String... on your other account.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() DoExport(GS.Selected()) end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "labeledButton", text = "Update Settings", buttonText = "Overwrite",
              tooltip = "Saves your current game settings into this set.",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskUpdate(GS.Selected()) end },
            { type = "labeledButton", text = "Rename Settings", buttonText = "Rename...",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskRename(GS.Selected()) end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type = "labeledButton", text = "Delete Settings", buttonText = "Delete",
              disabled = none, disabledTooltip = NONE_TIP, rawTooltip = true,
              onClick = function() AskDelete(GS.Selected()) end },
            BLANK()
        );  y = y - h
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  LOAD OPTIONS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "LOAD OPTIONS", y);  y = y - h

    local function CatToggle(c)
        if not c then return BLANK() end
        return { type = "toggle", text = c.label, tooltip = c.tip,
                 getValue = function() return GS.CatOn(c.key) end,
                 setValue = function(v) GS.SetCatOn(c.key, v) end }
    end
    local cats = GS.CATEGORIES
    for i = 1, #cats, 2 do
        _, h = W:DualRow(parent, y, CatToggle(cats[i]), CatToggle(cats[i + 1]));  y = y - h
    end

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Reset Other Settings",
          tooltip = "Settings in the categories switched on that the saved set leaves at default, but that are "
              .. "changed here, go back to default, so this character matches exactly.",
          getValue = function() return GS.Get("gsResetOthers") and true or false end,
          setValue = function(v) GS.Set("gsResetOthers", v and true or false) end },
        { type = "toggle", text = "Backup Before Load",
          tooltip = "Saves your current settings as \"" .. BP.BACKUP_PREFIX .. "<name>\" before loading, "
              .. "so Undo Last Load can bring them back.",
          getValue = function() return GS.Get("gsBackup") and true or false end,
          setValue = function(v) GS.Set("gsBackup", v and true or false) end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Undo Last Load", buttonText = "Restore Backup",
          tooltip = "Loads this character's backup (made before the last load).",
          disabled = function() return GS.BackupName() == nil end,
          disabledTooltip = "No backup of this character yet: one is made before each load while Backup "
              .. "Before Load is on.", rawTooltip = true,
          onClick = function() local b = GS.BackupName(); if b then AskLoad(b) end end },
        BLANK()
    );  y = y - h

    return math.abs(y)
end
