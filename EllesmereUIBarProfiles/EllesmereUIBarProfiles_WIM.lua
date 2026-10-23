if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_WIM.lua
--  Dworak > Profiles, "WIM" tab: WIM (WoW Instant Messenger) settings in one
--  string, and that string put on another account in one go.
--
--  WIM keeps everything in account-wide SavedVariables and works on them
--  directly (WIM.lua VARIABLES_LOADED: db = WIM3_Data, filters =
--  WIM3_Filters, ...), with no logout handler writing a private copy back.
--  So an import replaces those tables IN PLACE (same table, new contents)
--  and reloads; WIM saves them as they are.
--
--  Parts (each can be left out, opt wimPart_<key>):
--    settings  WIM3_Data          windows, skins, sounds, tabs, history options
--    filters   WIM3_Filters, WIM3_ChatFilters
--    alias     WIM3_Alias         nicknames you gave players
--    history   WIM3_History       the saved conversations (off by default:
--                                 private, and can be large)
--  WIM3_Cache (player info cache) is never copied.
--  The parts being replaced are kept (wimBackup) for Undo Last Import.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

local WM = {}
BP.WM = WM

WM.PAGE          = "WIM"
WM.EXPORT_PREFIX = "!EUIWIM1!"

WM.PARTS = {
    { key = "settings", label = "Settings", svs = { "WIM3_Data" }, default = true,
      tip = "Windows, skin, fonts, sounds, tabs, popup rules, history options: everything in WIM's options." },
    { key = "filters", label = "Filters", svs = { "WIM3_Filters", "WIM3_ChatFilters" }, default = true,
      tip = "Whisper and chat filters." },
    { key = "alias", label = "Player Aliases", svs = { "WIM3_Alias" }, default = true,
      tip = "The nicknames you gave players." },
    { key = "history", label = "Conversation History", svs = { "WIM3_History" }, default = false,
      tip = "Your saved whisper conversations. Off by default: they are private and can be large." },
}

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

local function Loaded()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("WIM")
    if loaded == nil and _G.IsAddOnLoaded then loaded = _G.IsAddOnLoaded("WIM") end
    return loaded and type(_G.WIM3_Data) == "table"
end
WM.Loaded = Loaded

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, "WIM", "Version")
    return ok and v or nil
end

function WM.PartOn(key)
    local v = BP.Get("wimPart_" .. key)
    if v == nil then
        for _, p in ipairs(WM.PARTS) do
            if p.key == key then return p.default end
        end
        return false
    end
    return v and true or false
end

function WM.SetPartOn(key, v) BP.Set("wimPart_" .. key, v and true or false) end

local function Count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- Entries per part, for the page.
function WM.PartCount(p)
    local n = 0
    for _, sv in ipairs(p.svs) do n = n + Count(_G[sv]) end
    return n
end

-------------------------------------------------------------------------------
--  Export / decode / apply
-------------------------------------------------------------------------------
-- The export data (also used by All in One): payload, part labels.
function WM.Payload()
    if not Loaded() then return nil, "WIM isn't loaded" end
    local data, parts = {}, {}
    for _, p in ipairs(WM.PARTS) do
        if WM.PartOn(p.key) then
            for _, sv in ipairs(p.svs) do
                if type(_G[sv]) == "table" then data[sv] = Copy(_G[sv]) end
            end
            parts[#parts + 1] = p.label
        end
    end
    if #parts == 0 then return nil, "no part is ticked" end
    return { v = 1, char = BP.CharKey(), time = time(), version = Version(), data = data }, parts
end

function WM.ExportString()
    local payload, parts = WM.Payload()
    if not payload then return nil, parts end
    local str = BP.Pack(WM.EXPORT_PREFIX, payload)
    if not str then return nil, "LibDeflate is missing" end
    return str, parts
end

local KNOWN_SV = {}
for _, p in ipairs(WM.PARTS) do
    for _, sv in ipairs(p.svs) do KNOWN_SV[sv] = p end
end

function WM.DecodeString(str)
    local raw, err = BP.Unpack(WM.EXPORT_PREFIX, str)
    if not raw then
        if err == "wrong kind of string" then err = "this is not a Profiles > WIM string" end
        return nil, err
    end
    return WM.FromRaw(raw)
end

function WM.FromRaw(raw)
    if type(raw) ~= "table" or type(raw.data) ~= "table" then return nil, "the string is damaged (data)" end
    local data, labels, seen = {}, {}, {}
    for sv, t in pairs(raw.data) do
        local p = KNOWN_SV[sv]
        if p and type(t) == "table" then
            data[sv] = t
            if not seen[p.key] then
                seen[p.key] = true
                labels[#labels + 1] = p.label
            end
        end
    end
    if #labels == 0 then return nil, "the string holds no WIM data" end
    return { data = data, labels = labels, char = type(raw.char) == "string" and raw.char or nil,
             time = type(raw.time) == "number" and raw.time or nil,
             version = type(raw.version) == "string" and raw.version or nil }
end

-- Replaces the WIM tables in data in place. With backup, the tables being
-- replaced are kept for Undo Last Import first.
function WM.Apply(data, backup)
    if not Loaded() then return false end
    if backup then
        local B = { time = time(), data = {} }
        for sv in pairs(data) do
            B.data[sv] = type(_G[sv]) == "table" and Copy(_G[sv]) or {}
        end
        BP.Set("wimBackup", B)
    end
    for sv, t in pairs(data) do
        if KNOWN_SV[sv] then
            if type(_G[sv]) == "table" then Replace(_G[sv], t) else _G[sv] = Copy(t) end
        end
    end
    return true
end

-------------------------------------------------------------------------------
--  Page actions
-------------------------------------------------------------------------------
local function DoExport()
    local str, parts = WM.ExportString()
    if not str then
        BP.Say("|cffff4040export failed:|r " .. tostring(parts))
        return
    end
    EllesmereUI:ShowCopyPopup("Export WIM",
        table.concat(parts, ", ") .. " - copy the string and paste it on the other account", str)
end

local function AskImport()
    if not Loaded() then
        BP.Say("WIM isn't loaded.")
        return
    end
    EllesmereUI:ShowImportPopup(function(str)
        local P, err = WM.DecodeString(str)
        if not P then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        local who = P.char and (P.char:match("^([^%-]+)") or P.char) or "?"
        local mine = Version()
        local warn = "|cff999999What you have now is kept for Undo Last Import.|r"
        if P.version and mine and P.version ~= mine then
            warn = "|cffffd040Made with WIM " .. P.version .. ", you have " .. mine .. ".|r\n" .. warn
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowConfirmPopup({
                title = "Import WIM",
                message = string.format("WIM data from %s%s:\n%s\nIt replaces yours, then the UI reloads.", who,
                    P.time and (" (" .. date("%Y-%m-%d", P.time) .. ")") or "", table.concat(P.labels, ", ")),
                disclaimer = warn,
                confirmText = "Import & Reload",
                reload = true,
                onConfirm = function()
                    if not WM.Apply(P.data, true) then BP.Say("|cffff4040import failed:|r WIM isn't loaded.") end
                end,
            })
        end)
    end, "Import WIM", "Paste a Profiles > WIM string below")
end

local function AskUndo()
    local B = BP.Get("wimBackup")
    if type(B) ~= "table" or type(B.data) ~= "table" then return end
    EllesmereUI:ShowConfirmPopup({
        title = "Undo Last Import",
        message = "Put back the WIM data you had before the last import ("
            .. (B.time and date("%Y-%m-%d %H:%M", B.time) or "?") .. ")? The UI reloads.",
        confirmText = "Restore & Reload",
        reload = true,
        onConfirm = function()
            if WM.Apply(B.data, false) then BP.Set("wimBackup", nil) end
        end,
    })
end

WM.DoExport, WM.AskImport, WM.AskUndo = DoExport, AskImport, AskUndo

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
function WM.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local function off() return not Loaded() end
    local OFF_TIP = "WIM isn't loaded."
    local ver = Version()

    _, h = W:SectionHeader(parent, "WIM", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = Loaded() and ("This account: WIM" .. (ver and (" " .. ver) or ""))
              or "|cffff4040WIM isn't loaded.|r" }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = "|cff999999Every character of an account shares WIM's data; another account needs "
              .. "the string. Tick what goes into the export.|r" }
    );  y = y - h

    local function PartToggle(p)
        if not p then return BLANK() end
        return { type = "toggle", text = p.label,
                 tooltip = p.tip .. (Loaded() and ("\n" .. WM.PartCount(p) .. " entries here.") or ""),
                 disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
                 getValue = function() return WM.PartOn(p.key) end,
                 setValue = function(v) WM.SetPartOn(p.key, v) end }
    end
    for i = 1, #WM.PARTS, 2 do
        _, h = W:DualRow(parent, y, PartToggle(WM.PARTS[i]), PartToggle(WM.PARTS[i + 1]));  y = y - h
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h
    _, h = W:SectionHeader(parent, "EXPORT / IMPORT", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Export WIM", buttonText = "Export",
          tooltip = "The ticked parts of WIM's data in one string. Paste it on the other account with Import WIM.",
          disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
          onClick = DoExport },
        { type = "labeledButton", text = "Import WIM", buttonText = "Paste String...",
          tooltip = "Replaces the parts in the string with the imported ones, then reloads the UI. "
              .. "What you have now is kept for Undo Last Import.",
          disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
          onClick = AskImport }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Undo Last Import", buttonText = "Restore Backup",
          tooltip = "Puts back the WIM data you had before the last import.",
          disabled = function() return off() or type(BP.Get("wimBackup")) ~= "table" end,
          disabledTooltip = function() return off() and OFF_TIP or "No import to undo yet." end, rawTooltip = true,
          onClick = AskUndo },
        BLANK()
    );  y = y - h

    return math.abs(y)
end
