if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_ForeverAuras.lua
--  Dworak > Profiles, "ForeverAuras" and "Spark Forever" tabs: every aura of
--  a WeakAuras-style addon in ONE string, and that string put back on another
--  account in one go, instead of importing the auras one by one.
--
--  Both addons are WeakAuras forks with the same saved layout:
--    ForeverAuras  -> ForeverAurasSaved.displays  (global ForeverAuras)
--    Spark Forever -> SparkForeverSaved.displays  (global SparkForever)
--  The SavedVariable belongs to the WoW account: every character of one
--  account already shares the auras, another account needs the string.
--  One tab per addon, built by MakeAuraTab(cfg) below.
--
--  Export: <Saved>.displays (every aura, groups with their children)
--  serialized + LibDeflate'd ("!EUIFA1!" ForeverAuras, "!EUISF1!" Spark).
--  Import: the auras are written straight into <Saved>.displays and the UI
--  reloads. The addon's own login does the rest, exactly as for the auras
--  already saved: parent / child links are re-checked
--  (SyncParentChildRelationships), duplicate uids fixed
--  (ValidateUniqueDataIds) and each aura is migrated to the running version.
--  An aura (or group) whose name already exists here is kept, replaced or
--  added as a copy (If An Aura Already Exists). A string of the other addon
--  is accepted too (moving auras from ForeverAuras to Spark Forever), with a
--  note in the confirm popup.
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

-- Every aura tab's export prefix -> its label, so one tab can name a string
-- made by the other.
local PREFIX_LABEL = {}

local function MakeAuraTab(cfg)
local FA = { cfg = cfg }
local LABEL = cfg.label

FA.PAGE          = cfg.page
FA.EXPORT_PREFIX = cfg.prefix
PREFIX_LABEL[cfg.prefix] = LABEL

function FA.Get(key)
    local v = BP.DB().opt[key]
    if v == nil and key == cfg.optKey then return "keep" end -- "keep" | "replace" | "copy"
    return v
end

function FA.Set(key, value) BP.DB().opt[key] = value end

-- The addon's running version (its InternalVersion), or nil.
local function Version()
    local g = _G[cfg.global]
    if type(g) == "table" and type(g.InternalVersion) == "function" then
        local ok, v = pcall(g.InternalVersion)
        if ok and type(v) == "number" then return v end
    end
end

-- The addon's saved aura table, or nil when the addon isn't loaded.
function FA.Displays()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(cfg.addon)
    if loaded == nil and _G.IsAddOnLoaded then loaded = _G.IsAddOnLoaded(cfg.addon) end
    local saved = _G[cfg.sv]
    if not loaded or type(saved) ~= "table" or type(saved.displays) ~= "table" then return nil end
    return saved.displays
end

-- Top-level auras / groups (no parent in the set), each with every aura
-- below it: { root = id, ids = { id, ... } }, sorted by name.
local function Trees(displays)
    local function RootOf(id)
        local seen = {}
        local cur = id
        while true do
            local d = displays[cur]
            local p = d and d.parent
            if type(p) ~= "string" or not displays[p] or seen[p] then return cur end
            seen[cur] = true
            cur = p
        end
    end
    local byRoot, order = {}, {}
    for id in pairs(displays) do
        local r = RootOf(id)
        if not byRoot[r] then
            byRoot[r] = { root = r, ids = {} }
            order[#order + 1] = r
        end
        local t = byRoot[r].ids
        t[#t + 1] = id
    end
    table.sort(order, function(a, b) return a:lower() < b:lower() end)
    local out = {}
    for i, r in ipairs(order) do out[i] = byRoot[r] end
    return out
end
FA.Trees = Trees

function FA.Count()
    local displays = FA.Displays()
    if not displays then return nil end
    local n = 0
    for _ in pairs(displays) do n = n + 1 end
    return n, #Trees(displays)
end

-------------------------------------------------------------------------------
--  Export / decode
-------------------------------------------------------------------------------
function FA.ExportString()
    local displays = FA.Displays()
    if not displays then return nil, LABEL .. " isn't loaded" end
    local n, tops = FA.Count()
    if n == 0 then return nil, "you have no " .. LABEL .. " auras" end
    local payload = {
        v = 1, addon = cfg.addon, char = BP.CharKey(), time = time(), count = n, tops = tops,
        version = Version(), displays = displays,
    }
    local str = BP.Pack(FA.EXPORT_PREFIX, payload)
    if not str then return nil, "LibDeflate is missing" end
    return str, n, tops
end

function FA.DecodeString(str)
    -- This tab's own string first, then any other aura tab's.
    local raw, err = BP.Unpack(FA.EXPORT_PREFIX, str)
    local from
    if not raw and err == "wrong kind of string" then
        local trimmed = type(str) == "string" and str:gsub("%s+", "") or ""
        for prefix, label in pairs(PREFIX_LABEL) do
            if prefix ~= FA.EXPORT_PREFIX and trimmed:sub(1, #prefix) == prefix then
                raw, err = BP.Unpack(prefix, trimmed)
                from = label
                break
            end
        end
    end
    if not raw then
        if err == "wrong kind of string" then
            err = "this is not a Profiles > " .. LABEL .. " string (a single aura's own string goes into "
                .. LABEL .. "'s Import)"
        end
        return nil, err
    end
    if type(raw.displays) ~= "table" then return nil, "the string is damaged (data)" end
    -- Only string ids with table data; each aura's id matches its key.
    local displays, count = {}, 0
    for id, data in pairs(raw.displays) do
        if type(id) == "string" and id ~= "" and type(data) == "table" then
            data.id = id
            displays[id] = data
            count = count + 1
        end
    end
    if count == 0 then return nil, "the string holds no auras" end
    return { displays = displays, count = count, char = raw.char, time = raw.time,
             version = (not from) and raw.version or nil, from = from }
end

-------------------------------------------------------------------------------
--  Import
-------------------------------------------------------------------------------
-- What an import would do, per top-level aura: { root, ids, clash }.
function FA.Plan(P)
    local here = FA.Displays()
    if not here then return nil end
    local plan = { trees = {}, new = 0, clash = 0 }
    for _, t in ipairs(Trees(P.displays)) do
        local clash = false
        for _, id in ipairs(t.ids) do
            if here[id] then clash = true break end
        end
        t.clash = clash
        plan.trees[#plan.trees + 1] = t
        if clash then plan.clash = plan.clash + 1 else plan.new = plan.new + 1 end
    end
    return plan
end

-- A free name: "Name (2)", "Name (3)", ... (not here, not taken in this import).
local function FreeId(id, here, taken)
    for i = 2, 999 do
        local n = id .. " (" .. i .. ")"
        if not here[n] and not taken[n] then return n end
    end
    return id .. " " .. time()
end

-- Writes the auras into <Saved>.displays. Returns added, replaced,
-- copied, skipped (counts of auras, children included).
function FA.Write(P, mode)
    local here = FA.Displays()
    if not here then return nil end
    mode = mode or FA.Get(cfg.optKey)
    local added, replaced, copied, skipped = 0, 0, 0, 0
    local taken = {}
    for _, t in ipairs(FA.Plan(P).trees) do
        if t.clash and mode == "keep" then
            skipped = skipped + #t.ids
        elseif t.clash and mode == "copy" then
            -- New names for the whole tree, links rewritten to them.
            local rename = {}
            for _, id in ipairs(t.ids) do
                if here[id] then
                    local n = FreeId(id, here, taken)
                    rename[id] = n
                    taken[n] = true
                else
                    rename[id] = id
                    taken[id] = true
                end
            end
            for _, id in ipairs(t.ids) do
                local data = P.displays[id]
                local newId = rename[id]
                data.id = newId
                data.uid = nil -- the addon gives it a new one
                if type(data.parent) == "string" and rename[data.parent] then
                    data.parent = rename[data.parent]
                end
                if type(data.controlledChildren) == "table" then
                    for i, child in ipairs(data.controlledChildren) do
                        if rename[child] then data.controlledChildren[i] = rename[child] end
                    end
                end
                here[newId] = data
                copied = copied + 1
            end
        else
            for _, id in ipairs(t.ids) do
                if here[id] then replaced = replaced + 1 else added = added + 1 end
                here[id] = P.displays[id]
                taken[id] = true
            end
        end
    end
    return added, replaced, copied, skipped
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function DoExport()
    local str, n, tops = FA.ExportString()
    if not str then
        BP.Say("|cffff4040export failed:|r " .. tostring(n))
        return
    end
    EllesmereUI:ShowCopyPopup("Export " .. LABEL,
        string.format("%d auras (%d top-level) - copy the string and paste it on the other account", n, tops), str)
end

local MODE_TEXT = { keep = "kept (not imported)", replace = "replaced", copy = "added as copies" }

local function AskImport()
    if not FA.Displays() then
        BP.Say(LABEL .. " isn't loaded.")
        return
    end
    EllesmereUI:ShowImportPopup(function(str)
        local P, err = FA.DecodeString(str)
        if not P then
            BP.Say("|cffff4040import failed:|r " .. tostring(err))
            return
        end
        local plan = FA.Plan(P)
        if not plan then return end
        local mode = FA.Get(cfg.optKey)
        local names = {}
        for i, t in ipairs(plan.trees) do
            if i > 8 then
                names[#names + 1] = "..."
                break
            end
            names[#names + 1] = (t.clash and "|cffffd040" or "") .. t.root .. (#t.ids > 1 and (" (" .. #t.ids .. ")") or "")
                .. (t.clash and "|r" or "")
        end
        local msg = string.format("%d auras, %d top-level: %d new%s.\n%s", P.count, #plan.trees, plan.new,
            plan.clash > 0 and string.format(", %d already here (yellow) will be %s", plan.clash, MODE_TEXT[mode]) or "",
            table.concat(names, ", "))
        local warn = "|cff999999Auras can run their own code: only import strings you made yourself or trust.\n"
            .. "The UI reloads to load them.|r"
        local mine = Version()
        if P.version and mine and P.version > mine then
            warn = "|cffff8040Made with a newer " .. LABEL .. " than yours: update " .. LABEL .. " first.|r\n" .. warn
        end
        if P.from then
            warn = "|cffffd040Made in " .. P.from .. ": the auras are moved into " .. LABEL
                .. ". Auras that use something only " .. P.from .. " has may need fixing.|r\n" .. warn
        end
        C_Timer.After(0, function()
            EllesmereUI:ShowConfirmPopup({
                title = "Import " .. LABEL,
                message = msg,
                disclaimer = warn,
                confirmText = "Import & Reload",
                reload = true,
                onConfirm = function()
                    local a, r, c, s = FA.Write(P, mode)
                    if a then
                        BP.Say(string.format("%s: %d added, %d replaced, %d copied, %d kept.", LABEL, a, r, c, s))
                    end
                end,
            })
        end)
    end, "Import " .. LABEL, "Paste a Profiles > " .. LABEL .. " string below")
end

FA.DoExport, FA.AskImport = DoExport, AskImport

function FA.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local n, tops = FA.Count()
    local function off() return FA.Displays() == nil end
    local OFF_TIP = LABEL .. " isn't loaded."

    _, h = W:SectionHeader(parent, cfg.header, y);  y = y - h

    -- Two full-width rows (no right half), so the long lines don't overlap.
    _, h = W:DualRow(parent, y,
        { type = "label", text = n and string.format("This account: %d top-level auras / groups, %d auras in all (group contents too)", tops, n)
              or ("|cffff4040" .. LABEL .. " isn't loaded.|r") }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "label", text = "|cff999999Every character of an account shares them; another account needs the string.|r" }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Export All Auras", buttonText = "Export",
          tooltip = "Every " .. LABEL .. " aura and group of this account in one string. Paste it on the other "
              .. "account with Import Auras.",
          disabled = function() return off() or (FA.Count() or 0) == 0 end,
          disabledTooltip = function() return off() and OFF_TIP or "No auras to export." end, rawTooltip = true,
          onClick = DoExport },
        { type = "labeledButton", text = "Import Auras", buttonText = "Paste String...",
          tooltip = "Adds every aura of an Export All Auras string at once, then reloads the UI. Shows what it will "
              .. "do first.",
          disabled = off, disabledTooltip = OFF_TIP, rawTooltip = true,
          onClick = AskImport }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "If An Aura Already Exists",
          values = { keep = "Keep Mine", replace = "Replace It", copy = "Add as Copy" },
          order = { "keep", "replace", "copy" },
          tooltip = "An imported aura or group with a name this account already has:\n"
              .. "Keep Mine: not imported.\nReplace It: the imported one takes its place.\n"
              .. "Add as Copy: imported under a new name, \"Name (2)\".",
          getValue = function() return FA.Get(cfg.optKey) end,
          setValue = function(v) FA.Set(cfg.optKey, v) end },
        BLANK()
    );  y = y - h

    return math.abs(y)
end

return FA
end -- MakeAuraTab

BP.FA = MakeAuraTab({
    addon = "ForeverAuras", sv = "ForeverAurasSaved", global = "ForeverAuras",
    label = "ForeverAuras", page = "ForeverAuras", header = "FOREVERAURAS",
    prefix = "!EUIFA1!", optKey = "faExisting",
})

BP.SF = MakeAuraTab({
    addon = "SparkForever", sv = "SparkForeverSaved", global = "SparkForever",
    label = "Spark Forever", page = "Spark Forever", header = "SPARK FOREVER",
    prefix = "!EUISF1!", optKey = "sfExisting",
})
