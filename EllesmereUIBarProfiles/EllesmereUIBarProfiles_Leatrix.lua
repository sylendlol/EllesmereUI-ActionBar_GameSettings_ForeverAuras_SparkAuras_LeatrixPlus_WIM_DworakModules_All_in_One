if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_Leatrix.lua
--  Dworak > Profiles, "Leatrix Plus" tab: every Leatrix Plus setting in one
--  string, and that string put on another account in one go.
--
--  Leatrix Plus keeps its settings in LeaPlusDB, a SavedVariable of the WoW
--  account (every character of one account shares them). While the game runs
--  it works on a private copy and writes it back to LeaPlusDB only at logout /
--  reload (its PLAYER_LOGOUT handler). So:
--    Export: LeaPlusDB holds what was saved at the last reload. "Reload &
--      Export" reloads first (Leatrix saves) and shows the string right after
--      login (opt lpExportPending).
--    Import: Leatrix's own "/ltp nosave" stops it from writing its copy back
--      at the next logout, then LeaPlusDB is replaced with the imported
--      settings and the UI reloads, the same way Leatrix's own preset
--      profile ("/ltp admin") does it.
--  Chat history (LeaPlusDB.ChatHistory*) is per account and never copied.
--  The settings being replaced are kept (lpBackup) for Undo Last Import.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

local LP = {}
BP.LP = LP

LP.PAGE          = "Leatrix Plus"
LP.EXPORT_PREFIX = "!EUILP1!"

local function Loaded()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Leatrix_Plus")
    if loaded == nil and _G.IsAddOnLoaded then loaded = _G.IsAddOnLoaded("Leatrix_Plus") end
    return loaded and type(_G.LeaPlusDB) == "table"
end
LP.Loaded = Loaded

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, "Leatrix_Plus", "Version")
    return ok and v or nil
end

-- Keys that are data of this account, not settings.
local function Skipped(key)
    return type(key) ~= "string" or key:find("^ChatHistory") ~= nil
end

local function Copy(v, depth)
    if type(v) ~= "table" then return v end
    depth = depth or 0
    if depth > 30 then return {} end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x, depth + 1) end
    return t
end

-- The settings in LeaPlusDB (chat history left out) and their count.
function LP.Settings()
    if not Loaded() then return nil, 0 end
    local out, n = {}, 0
    for k, v in pairs(_G.LeaPlusDB) do
        local tv = type(v)
        if not Skipped(k) and (tv == "string" or tv == "number" or tv == "boolean" or tv == "table") then
            out[k] = Copy(v)
            n = n + 1
        end
    end
    return out, n
end

-------------------------------------------------------------------------------
--  Export / decode / apply
-------------------------------------------------------------------------------
-- The export data (also used by All in One): payload, count.
function LP.Payload()
    local settings, n = LP.Settings()
    if not settings then return nil, "Leatrix Plus isn't loaded" end
    if n == 0 then return nil, "Leatrix Plus has no saved settings yet (reload once first)" end
    return { v = 1, char = BP.CharKey(), time = time(), version = Version(), count = n, db = settings }, n
end

function LP.ExportString()
    local payload, n = LP.Payload()
    if not payload then return nil, n end
    local str = BP.Pack(LP.EXPORT_PREFIX, payload)
    if not str then return nil, "LibDeflate is missing" end
    return str, n
end

function LP.DecodeString(str)
    local raw, err = BP.Unpack(LP.EXPORT_PREFIX, str)
    if not raw then
        if err == "wrong kind of string" then err = "this is not a Profiles > Leatrix Plus string" end
        return nil, err
    end
    return LP.FromRaw(raw)
end

function LP.FromRaw(raw)
    if type(raw) ~= "table" or type(raw.db) ~= "table" then return nil, "the string is damaged (data)" end
    local db, n = {}, 0
    for k, v in pairs(raw.db) do
        local tv = type(v)
        if not Skipped(k) and #k <= 80 and (tv == "string" or tv == "number" or tv == "boolean" or tv == "table") then
            db[k] = v
            n = n + 1
        end
    end
    if n == 0 then return nil, "the string holds no settings" end
    return { db = db, count = n, char = type(raw.char) == "string" and raw.char or nil,
             time = type(raw.time) == "number" and raw.time or nil,
             version = type(raw.version) == "string" and raw.version or nil }
end

-- Replaces Leatrix Plus' settings with db (chat history kept). The caller
-- reloads the UI right after. False when Leatrix can't be told not to save.
function LP.Apply(db)
    if not Loaded() then return false end
    local slash = SlashCmdList and SlashCmdList["Leatrix_Plus"]
    if type(slash) ~= "function" then return false end
    -- Leatrix must not write its own copy back at the coming logout.
    local ok = pcall(slash, "nosave")
    if not ok then return false end
    local L = _G.LeaPlusDB
    for k in pairs(L) do
        if not Skipped(k) then L[k] = nil end
    end
    for k, v in pairs(db) do
        if not Skipped(k) then L[k] = Copy(v) end
    end
    return true
end

-------------------------------------------------------------------------------
--  Page actions
-------------------------------------------------------------------------------
local function ShowExport()
    local str, n = LP.ExportString()
    if not str then
        BP.Say("|cffff4040export failed:|r " .. tostring(n))
        return
    end
    EllesmereUI:ShowCopyPopup("Export Leatrix Plus",
        string.format("%d settings - copy the string and paste it on the other account", n), str)
end

local function AskExport()
    if not Loaded() then
        BP.Say("Leatrix Plus isn't loaded.")
        return
    end
    EllesmereUI:ShowConfirmPopup({
        title = "Export Leatrix Plus",
        message = "Leatrix Plus writes its settings to disk only when the UI reloads. Changes made since the last "
            .. "reload are in the string only after one.",
        confirmText = "Reload & Export",
        cancelText = "Export As Saved",
        reload = true,
        onConfirm = function() BP.Set("lpExportPending", true) end,
        onCancel = function() C_Timer.After(0, ShowExport) end,
        onDismiss = function() end,
    })
end

local function Backup()
    local settings, n = LP.Settings()
    if settings and n > 0 then
        BP.Set("lpBackup", { time = time(), char = BP.CharKey(), db = settings, count = n })
    end
end

local function AskImport()
    if not Loaded() then
        BP.Say("Leatrix Plus isn't loaded.")
        return
    end
    EllesmereUI:ShowImportPopup(function(str)
        local P, err = LP.DecodeString(str)
        if not P then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        local who = P.char and (P.char:match("^([^%-]+)") or P.char) or "?"
        local mine = Version()
        local warn = "|cff999999Your current Leatrix Plus settings are kept for Undo Last Import. Chat history "
            .. "isn't touched.|r"
        if P.version and mine and P.version ~= mine then
            warn = "|cffffd040Made with Leatrix Plus " .. P.version .. ", you have " .. mine
                .. ": settings it doesn't know are ignored.|r\n" .. warn
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowConfirmPopup({
                title = "Import Leatrix Plus",
                message = string.format("%d Leatrix Plus settings from %s%s.\nThey replace all your Leatrix Plus "
                    .. "settings, then the UI reloads.", P.count, who,
                    P.time and (" (" .. date("%Y-%m-%d", P.time) .. ")") or ""),
                disclaimer = warn,
                confirmText = "Import & Reload",
                reload = true,
                onConfirm = function()
                    Backup()
                    if not LP.Apply(P.db) then
                        BP.Say("|cffff4040import failed:|r Leatrix Plus couldn't be told not to save over it.")
                    end
                end,
            })
        end)
    end, "Import Leatrix Plus", "Paste a Profiles > Leatrix Plus string below")
end

local function AskUndo()
    local B = BP.Get("lpBackup")
    if type(B) ~= "table" or type(B.db) ~= "table" then return end
    EllesmereUI:ShowConfirmPopup({
        title = "Undo Last Import",
        message = string.format("Put back the %d Leatrix Plus settings you had before the last import (%s)? "
            .. "The UI reloads.", B.count or 0, B.time and date("%Y-%m-%d %H:%M", B.time) or "?"),
        confirmText = "Restore & Reload",
        reload = true,
        onConfirm = function()
            if LP.Apply(B.db) then BP.Set("lpBackup", nil) end
        end,
    })
end

LP.AskExport, LP.AskImport, LP.AskUndo, LP.Backup, LP.Version = AskExport, AskImport, AskUndo, Backup, Version

-- Reload & Export: the string right after the reload.
local loginFrame = CreateFrame("Frame")
pcall(loginFrame.RegisterEvent, loginFrame, "PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if BP.Get("lpExportPending") then
        BP.Set("lpExportPending", nil)
        C_Timer.After(3, ShowExport)
    end
end)

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
function LP.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local _, n = LP.Settings()
    local function off() return not Loaded() end
    local OFF_TIP = "Leatrix Plus isn't loaded."
    local ver = Version()

    _, h = W:SectionHeader(parent, "LEATRIX PLUS", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = Loaded()
              and string.format("This account: %d Leatrix Plus settings%s", n, ver and (" (Leatrix Plus " .. ver .. ")") or "")
              or "|cffff4040Leatrix Plus isn't loaded.|r" }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = "|cff999999Every character of an account shares them; another account needs the "
              .. "string. Leatrix Plus saves them only when the UI reloads.|r" }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Export All Settings", buttonText = "Export",
          tooltip = "Every Leatrix Plus setting of this account in one string (chat history left out). "
              .. "Reload & Export saves this session's changes first.",
          disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
          onClick = AskExport },
        { type = "labeledButton", text = "Import Settings", buttonText = "Paste String...",
          tooltip = "Replaces all your Leatrix Plus settings with the ones in the string, then reloads the UI. "
              .. "Your current settings are kept for Undo Last Import.",
          disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
          onClick = AskImport }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Undo Last Import", buttonText = "Restore Backup",
          tooltip = "Puts back the Leatrix Plus settings you had before the last import.",
          disabled = function()
              local B = BP.Get("lpBackup")
              return off() or type(B) ~= "table"
          end,
          disabledTooltip = function() return off() and OFF_TIP or "No import to undo yet." end, rawTooltip = true,
          onClick = AskUndo },
        BLANK()
    );  y = y - h

    return math.abs(y)
end
