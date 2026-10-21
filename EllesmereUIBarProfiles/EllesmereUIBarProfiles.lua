if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles.lua
--  Dworak > Profiles, "Action Bars" tab: saves what is on your action bars, your
--  macros and your key bindings under a name, and loads them on any other
--  character of the account (or, through an export string, any account).
--
--  Why not Myslot: Myslot stores a spell as its spell ID and puts it back with
--  PickupSpell(id). On WoW Forever spells have ranks, every rank its own ID,
--  and a rank the character has not learned (or a lower rank hidden from the
--  spellbook) is placed as an unusable, wrongly drawn button. Here every spell
--  is saved with its NAME and RANK too, and placed straight from this
--  character's own spellbook (C_SpellBook.PickupSpellBookItem), so the button
--  is always the real, learned spell:
--    Spell Rank "Highest Known": the highest rank of that spell you know.
--    Spell Rank "Same Rank":     the saved rank when you know it, else the
--                                highest you know (keeps down-ranked spells).
--  A spell this character has not learned yet (a level 1 alt) still goes on
--  its button, as the saved rank (Place Unlearned Spells). The slot is then
--  remembered per character, and every time a spell is learned (trainer,
--  level up) the rank this character knows is swapped in, until the saved
--  rank is reached (Fill In When Learned). Slots you change yourself are
--  dropped from that list.
--
--  Macros are matched by name and body: an identical macro is reused, a macro
--  with the same name is updated (Update Same-Name Macros), anything else is
--  created. Buttons that held a macro point at the matching macro here.
--
--  Key bindings: every bound command (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1,
--  EUI_BAR9_BUTTON1, ...) with all its keys. EllesmereUI's action bars bind
--  their keys to these commands, so the keys follow the buttons.
--
--  Action slots 1-180 (every page EllesmereUI's ten bars and the stance /
--  form pages use). The pet bar is not saved: pet actions belong to the pet.
--
--  Layouts are account-wide (EllesmereUIBarProfilesDB), not per EllesmereUI
--  profile. Its own addon: no EllesmereUI file is changed.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local DW = EllesmereUIDworak
if not DW then return end -- the Dworak core is off: nothing to register into

local BP = {}
ns.BP = BP
EllesmereUIBarProfiles = BP

BP.MAX_SLOTS     = 180
BP.EXPORT_PREFIX = "!EUIBP1!"
BP.BACKUP_PREFIX = "Backup: "

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end

-------------------------------------------------------------------------------
--  Saved data (account-wide)
-------------------------------------------------------------------------------
local OPT_DEFAULTS = {
    doBars       = true,       -- Action Bars
    doMacros     = true,       -- Macros
    doBinds      = true,       -- Key Bindings
    rankMode     = "highest",  -- "highest" | "same"
    clearEmpty   = true,       -- Clear Other Slots
    updateMacros = true,       -- Update Same-Name Macros
    clearBinds   = false,      -- Clear Other Key Bindings
    backup       = true,       -- Backup Before Load
    placeUnlearned = true,     -- Place Unlearned Spells
    fillLearned  = true,       -- Fill In When Learned
}

function BP.DB()
    local d = EllesmereUIBarProfilesDB
    if type(d) ~= "table" then
        d = {}
        EllesmereUIBarProfilesDB = d
    end
    if type(d.layouts) ~= "table" then d.layouts = {} end
    if type(d.opt) ~= "table" then d.opt = {} end
    if type(d.pending) ~= "table" then d.pending = {} end
    return d
end

function BP.Get(key)
    local v = BP.DB().opt[key]
    if v == nil then return OPT_DEFAULTS[key] end
    return v
end

function BP.Set(key, value)
    BP.DB().opt[key] = value
end

-------------------------------------------------------------------------------
--  Text helpers
-------------------------------------------------------------------------------
local function Accent()
    local c = EllesmereUI.ELLESMERE_GREEN
    if c and c.r then return c.r, c.g, c.b end
    return 0.05, 0.82, 0.62
end

function BP.AccentHex()
    local r, g, b = Accent()
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function BP.Say(text)
    EllesmereUI.Print(BP.AccentHex() .. "Profiles:|r " .. tostring(text))
end

function BP.ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and c.colorStr then return "|c" .. c.colorStr end
    return "|cffffffff"
end

function BP.ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (class and names and names[class]) or class or "?"
end

function BP.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- This character's slots waiting for a spell to be learned:
--   pending[slot] = { id = saved spellID, n = name, r = saved rank, cur = spellID on the button now }
function BP.Pending()
    local all = BP.DB().pending
    local key = BP.CharKey()
    if type(all[key]) ~= "table" then all[key] = {} end
    return all[key]
end

-------------------------------------------------------------------------------
--  Spells
-------------------------------------------------------------------------------
local PickupSpell = (C_Spell and C_Spell.PickupSpell) or _G.PickupSpell
local PickupItem  = (C_Item and C_Item.PickupItem) or _G.PickupItem
local GetSubtext  = (C_Spell and C_Spell.GetSpellSubtext) or _G.GetSpellSubtext

local function SpellName(id)
    if not Plain(id) then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and Plain(n) then return n end
    end
    if _G.GetSpellInfo then
        local ok, n = pcall(_G.GetSpellInfo, id)
        if ok and Plain(n) then return n end
    end
    return nil
end
BP.SpellName = SpellName

-- Number from a rank subtext ("Rank 3" -> 3); "Racial", "Passive", "" -> nil.
local function RankOf(sub)
    if not Plain(sub) or type(sub) ~= "string" or sub == "" then return nil end
    return tonumber(sub:match("(%d+)"))
end

local function SpellRank(id)
    if not (GetSubtext and Plain(id)) then return nil end
    local ok, sub = pcall(GetSubtext, id)
    if not ok then return nil end
    return RankOf(sub)
end

local function SpellKnown(id)
    if not Plain(id) then return false end
    for _, fn in ipairs({ _G.IsPlayerSpell, _G.IsSpellKnown,
                          C_SpellBook and C_SpellBook.IsSpellKnown,
                          C_SpellBook and C_SpellBook.IsSpellInSpellBook }) do
        if fn then
            local ok, r = pcall(fn, id)
            if ok and Plain(r) and r then return true end
        end
    end
    return false
end

local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then
        local ok, n = pcall(C_Item.GetItemNameByID, id)
        if ok and Plain(n) then return n end
    end
    if _G.GetItemInfo then
        local ok, n = pcall(_G.GetItemInfo, id)
        if ok and Plain(n) then return n end
    end
    return nil
end

-- This character's spellbook: by spell ID and by name (every rank, plus the
-- highest). Built fresh for every load / preview.
--   entry = { idx = bookIndex, bank = bank, id = spellID, r = rank or nil }
local function AddBook(book, idx, bank, id, name, rank)
    if not (Plain(id) and Plain(name)) or type(name) ~= "string" or name == "" then return end
    local e = { idx = idx, bank = bank, id = id, r = rank }
    book.byID[id] = book.byID[id] or e
    local list = book.byName[name]
    if not list then
        list = {}
        book.byName[name] = list
    end
    list[#list + 1] = e
    if not list.best or (rank or 0) > (list.best.r or 0) then list.best = e end
end

local function ScanBookModern(book)
    local SB = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo
            and SB.GetSpellBookItemInfo and SB.PickupSpellBookItem and bank) then
        return false
    end
    local SPELL_T = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
        local li = SB.GetSpellBookSkillLineInfo(line)
        local offSpec = li and li.offSpecID
        if li and not (Plain(offSpec) and offSpec ~= 0) then
            local off, cnt = li.itemIndexOffset or 0, li.numSpellBookItems or 0
            for i = off + 1, off + cnt do
                local ok, info = pcall(SB.GetSpellBookItemInfo, i, bank)
                if ok and info and Plain(info.spellID) and not info.isPassive
                        and (not SPELL_T or info.itemType == SPELL_T) then
                    local id = info.spellID
                    AddBook(book, i, bank, id, info.name or SpellName(id),
                        RankOf(info.subName) or SpellRank(id))
                end
            end
        end
    end
    book.modern = true
    return true
end

local function ScanBookLegacy(book)
    local NumTabs, TabInfo = _G.GetNumSpellTabs, _G.GetSpellTabInfo
    local ItemInfo, ItemNameFn = _G.GetSpellBookItemInfo, _G.GetSpellBookItemName
    if not (NumTabs and TabInfo and ItemInfo and ItemNameFn and _G.PickupSpellBookItem) then return false end
    local bank = _G.BOOKTYPE_SPELL or "spell"
    for tab = 1, NumTabs() do
        local _, _, off, cnt, _, offSpec = TabInfo(tab)
        if off and cnt and (not offSpec or offSpec == 0) then
            for i = off + 1, off + cnt do
                local sType, id = ItemInfo(i, bank)
                if sType == "SPELL" and id then
                    local name, sub = ItemNameFn(i, bank)
                    AddBook(book, i, bank, id, name, RankOf(sub) or SpellRank(id))
                end
            end
        end
    end
    return true
end

function BP.BuildBook()
    local book = { byID = {}, byName = {} }
    local ok, done = pcall(ScanBookModern, book)
    if not (ok and done) then
        book = { byID = {}, byName = {} }
        pcall(ScanBookLegacy, book)
    end
    return book
end

-- Which spell of THIS character goes into a saved spell slot, or nil.
function BP.ResolveSpell(book, e, mode)
    local list = e.n and book.byName[e.n]
    if mode == "highest" and list and list.best then return list.best end
    local exact = book.byID[e.id]
    if exact then return exact end
    if list then
        if e.r then
            for _, b in ipairs(list) do
                if b.r == e.r then return b end
            end
        end
        -- "Same Rank": the saved rank is learned but hidden from the
        -- spellbook (lower ranks hidden): place it by its own ID.
        if SpellKnown(e.id) then return { id = e.id, direct = true } end
        return list.best
    end
    -- Not in the spellbook under that name (racials on some clients, spells
    -- learned outside the book): place by ID when the character knows it.
    if SpellKnown(e.id) then return { id = e.id, direct = true } end
    return nil
end

local function PickupBookEntry(b)
    if not b.direct then
        if b.bank and C_SpellBook and C_SpellBook.PickupSpellBookItem and type(b.bank) == "number" then
            pcall(C_SpellBook.PickupSpellBookItem, b.idx, b.bank)
        elseif _G.PickupSpellBookItem then
            pcall(_G.PickupSpellBookItem, b.idx, b.bank)
        end
    end
    if not GetCursorInfo() and b.id and PickupSpell then
        pcall(PickupSpell, b.id)
    end
end

-------------------------------------------------------------------------------
--  Macros
-------------------------------------------------------------------------------
local MacroConsts = _G.Constants and _G.Constants.MacroConsts
local MAX_ACC  = _G.MAX_ACCOUNT_MACROS or (MacroConsts and MacroConsts.MAX_ACCOUNT_MACROS) or 120
local MAX_CHAR = _G.MAX_CHARACTER_MACROS or (MacroConsts and MacroConsts.MAX_CHARACTER_MACROS) or 30
local DEFAULT_ICON = 134400 -- INV_Misc_QuestionMark

local function MacroKey(name, body) return tostring(name) .. "\n" .. tostring(body or "") end

local function MacroIndex()
    local byFull, byName = {}, {}
    for i = 1, MAX_ACC + MAX_CHAR do
        local n, _, b = GetMacroInfo(i)
        if n then
            local k = MacroKey(n, b)
            byFull[k] = byFull[k] or i
            byName[n] = byName[n] or i
        end
    end
    return byFull, byName
end

-- The macro index behind an action slot. GetActionInfo returns the macro's
-- spell or item (not its index) for a macro that shows one, so the slot is
-- picked up and put straight back to read the index from the cursor.
local function SlotMacroIndex(slot, id, subType)
    if (subType == nil or subType == "") and Plain(id) and type(id) == "number"
            and id >= 1 and id <= MAX_ACC + MAX_CHAR and GetMacroInfo(id) then
        return id
    end
    ClearCursor()
    PickupAction(slot)
    local cType, idx = GetCursorInfo()
    PlaceAction(slot)
    ClearCursor()
    if cType == "macro" and type(idx) == "number" then return idx end
    return nil
end

-------------------------------------------------------------------------------
--  Save
-------------------------------------------------------------------------------
function BP.Capture(name)
    local _, class = UnitClass("player")
    local L = {
        v = 1, name = name, char = BP.CharKey(), class = class,
        level = UnitLevel("player"), time = time(),
        slots = {}, macros = {}, binds = {},
    }

    -- Macros (account then character), each remembered by its index here.
    local posOf = {}
    for i = 1, MAX_ACC + MAX_CHAR do
        local n, icon, body = GetMacroInfo(i)
        if n then
            L.macros[#L.macros + 1] = { n = n, ic = icon or DEFAULT_ICON, b = body or "",
                                        c = (i > MAX_ACC) or nil }
            posOf[i] = #L.macros
        end
    end

    -- Action slots.
    local nSlots = 0
    for s = 1, BP.MAX_SLOTS do
        if HasAction(s) then
            local t, id, sub = GetActionInfo(s)
            local e
            if not Plain(t) then
                e = nil
            elseif t == "spell" and Plain(id) then
                e = { t = "spell", id = id, n = SpellName(id), r = SpellRank(id) }
            elseif t == "macro" then
                local mi = SlotMacroIndex(s, id, sub)
                if mi and posOf[mi] then
                    e = { t = "macro", m = posOf[mi] }
                else
                    local txt = GetActionText(s)
                    if Plain(txt) and txt then e = { t = "macro", mn = txt } end
                end
            elseif t == "item" and Plain(id) then
                e = { t = "item", id = id, n = ItemName(id) }
            elseif t == "equipmentset" and Plain(id) then
                e = { t = "eqset", n = tostring(id) }
            end
            if e then
                L.slots[s] = e
                nSlots = nSlots + 1
            end
        end
    end

    -- Key bindings: every command with a key, with all its keys.
    local nBinds = 0
    for i = 1, GetNumBindings() do
        local cmd, _, k1 = GetBinding(i)
        if cmd and k1 and not L.binds[cmd] then
            local keys = { GetBindingKey(cmd) }
            if #keys > 0 then
                L.binds[cmd] = keys
                nBinds = nBinds + #keys
            end
        end
    end

    L.nSlots, L.nMacros, L.nBinds = nSlots, #L.macros, nBinds
    return L
end

function BP.Save(name, isBackup)
    if InCombatLockdown() then
        BP.Say("layouts can only be saved out of combat.")
        return nil
    end
    local L = BP.Capture(name)
    L.backup = isBackup or nil
    BP.DB().layouts[name] = L
    if not isBackup then BP.Set("selected", name) end
    return L
end

-------------------------------------------------------------------------------
--  Load
-------------------------------------------------------------------------------
local function ClearSlot(s)
    ClearCursor()
    PickupAction(s)
    ClearCursor()
end

-- Spells of a layout this character can't place (names, no duplicates).
function BP.MissingSpells(L, book, mode)
    book = book or BP.BuildBook()
    mode = mode or BP.Get("rankMode")
    local seen, out = {}, {}
    for s = 1, BP.MAX_SLOTS do
        local e = L.slots and L.slots[s]
        if e and e.t == "spell" and not BP.ResolveSpell(book, e, mode) then
            local n = e.n or ("spell " .. tostring(e.id))
            if not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
    end
    return out
end

local function Bind(key, cmd)
    local ctx
    if cmd and C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, c = pcall(C_KeyBindings.GetBindingContextForAction, cmd)
        if ok then ctx = c end
    end
    local ok, r
    if ctx ~= nil then
        ok, r = pcall(SetBinding, key, cmd, ctx)
    else
        ok, r = pcall(SetBinding, key, cmd)
    end
    return ok and r ~= false
end

local function Unbind(key)
    local cur = GetBindingAction(key)
    local ctx
    if cur and cur ~= "" and C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, c = pcall(C_KeyBindings.GetBindingContextForAction, cur)
        if ok then ctx = c end
    end
    if ctx ~= nil then pcall(SetBinding, key, nil, ctx) else pcall(SetBinding, key) end
end

local function LoadMacros(L, rep)
    local doMacros = BP.Get("doMacros")
    local byFull, byName = MacroIndex()
    if doMacros then
        for _, m in ipairs(L.macros or {}) do
            if not byFull[MacroKey(m.n, m.b)] then
                local idx = byName[m.n]
                if idx and BP.Get("updateMacros") then
                    local ok = pcall(EditMacro, idx, m.n, m.ic or DEFAULT_ICON, m.b)
                    if ok then rep.macUpdated = rep.macUpdated + 1 else rep.macFailed = rep.macFailed + 1 end
                else
                    local na, nc = GetNumMacros()
                    local perChar = m.c and true or false
                    if perChar and nc >= MAX_CHAR then perChar = false end
                    if not perChar and na >= MAX_ACC then perChar = true end
                    local full = (perChar and nc >= MAX_CHAR) or (not perChar and na >= MAX_ACC)
                    local ok, newID = false, nil
                    if not full then
                        ok, newID = pcall(CreateMacro, m.n, m.ic or DEFAULT_ICON, m.b, perChar)
                    end
                    if ok and newID then
                        rep.macCreated = rep.macCreated + 1
                    else
                        rep.macFailed = rep.macFailed + 1
                        rep.macFailedNames[#rep.macFailedNames + 1] = m.n
                    end
                end
                -- Macros are kept sorted: indices move after every change.
                byFull, byName = MacroIndex()
            end
        end
    end
    -- Saved macro position -> macro index on this character.
    local map = {}
    for pos, m in ipairs(L.macros or {}) do
        map[pos] = byFull[MacroKey(m.n, m.b)] or byName[m.n]
    end
    return map, byName
end

-- Puts one saved slot on action slot s. Returns "placed", "same" or nil.
local function PlaceSlot(s, e, book, mode, macroMap, macroByName, rep)
    local curT, curID = GetActionInfo(s)
    if not Plain(curT) then curT, curID = nil, nil end
    ClearCursor()
    if e.t == "spell" then
        local label = (e.n or ("spell " .. tostring(e.id))) .. (e.r and (" (" .. e.r .. ")") or "")
        local pending = BP.Pending()
        local b = BP.ResolveSpell(book, e, mode)
        if not b then
            -- Not learned yet: the saved rank goes on the button anyway.
            if BP.Get("placeUnlearned") and PickupSpell then
                pcall(PickupSpell, e.id)
                if GetCursorInfo() then
                    PlaceAction(s)
                    ClearCursor()
                    local t2, id2 = GetActionInfo(s)
                    if Plain(t2) and t2 == "spell" and Plain(id2) then
                        pending[s] = { id = e.id, n = e.n, r = e.r, cur = id2 }
                        if id2 ~= e.id then
                            rep.mismatch[#rep.mismatch + 1] = label .. " -> " .. tostring(id2)
                        end
                    end
                    rep.unlearned[#rep.unlearned + 1] = label
                    return "placed"
                end
                ClearCursor()
            end
            -- The game won't put an unlearned spell on a button: the button is
            -- kept free for it and filled the moment it is learned.
            if BP.Get("fillLearned") then
                pending[s] = { id = e.id, n = e.n, r = e.r, cur = false }
                rep.waiting[#rep.waiting + 1] = label
                return "waiting"
            end
            rep.missing[#rep.missing + 1] = label
            return nil
        end
        -- A lower rank than saved: swapped up as higher ranks are learned.
        if b.id ~= e.id and (b.r or 0) < (e.r or 0) then
            pending[s] = { id = e.id, n = e.n, r = e.r, cur = b.id }
        end
        if curT == "spell" and curID == b.id then return "same" end
        PickupBookEntry(b)
    elseif e.t == "macro" then
        local idx = (e.m and macroMap[e.m]) or (e.mn and macroByName[e.mn])
        if not idx then
            -- BP.Apply swaps in the saved macro's name.
            rep.missing[#rep.missing + 1] = "macro " .. tostring(e.mn or "?")
            return nil
        end
        PickupMacro(idx)
    elseif e.t == "item" then
        if curT == "item" and curID == e.id then return "same" end
        if PickupItem then pcall(PickupItem, e.id) end
    elseif e.t == "eqset" then
        local setID = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetID
            and C_EquipmentSet.GetEquipmentSetID(e.n)
        if setID then pcall(C_EquipmentSet.PickupEquipmentSet, setID) end
    end
    if GetCursorInfo() then
        PlaceAction(s)
        ClearCursor()
        return "placed"
    end
    ClearCursor()
    if e.t == "spell" then BP.Pending()[s] = nil end
    rep.missing[#rep.missing + 1] = (e.t == "spell" and (e.n or ("spell " .. tostring(e.id))))
        or (e.t == "item" and (e.n or ("item " .. tostring(e.id))))
        or (e.t == "eqset" and ("equipment set " .. tostring(e.n)))
        or (e.t == "macro" and "macro")
        or tostring(e.t)
    return nil
end

function BP.Apply(L)
    if InCombatLockdown() then
        BP.Say("layouts can only be loaded out of combat.")
        return nil
    end
    local rep = {
        name = L.name, placed = 0, same = 0, cleared = 0, missing = {},
        macCreated = 0, macUpdated = 0, macFailed = 0, macFailedNames = {},
        binds = 0, bindFailed = 0, unbound = 0,
        unlearned = {}, mismatch = {}, waiting = {},
    }

    -- Macros first: the buttons need them.
    local macroMap, macroByName = LoadMacros(L, rep)

    if BP.Get("doBars") then
        local book = BP.BuildBook()
        local mode = BP.Get("rankMode")
        local clear = BP.Get("clearEmpty")
        -- A new layout: forget what the last one was waiting for.
        wipe(BP.Pending())
        for s = 1, BP.MAX_SLOTS do
            local e = L.slots and L.slots[s]
            if e then
                local r = PlaceSlot(s, e, book, mode, macroMap, macroByName, rep)
                if e.t == "macro" and not r then
                    -- PlaceSlot listed it as "macro ?": put the real name in.
                    local m = e.m and L.macros and L.macros[e.m]
                    if m then rep.missing[#rep.missing] = "macro " .. m.n end
                end
                -- What the button really holds now: Fill In When Learned compares to it.
                local pend = e.t == "spell" and r and r ~= "waiting" and BP.Pending()[s]
                if pend then
                    local t2, id2 = GetActionInfo(s)
                    if Plain(t2) and t2 == "spell" and Plain(id2) then pend.cur = id2 end
                end
                if r == "waiting" then
                    -- Kept free for the spell; with Clear Other Slots off a
                    -- button that holds something stays as it is.
                    if HasAction(s) then
                        if clear then
                            ClearSlot(s)
                            rep.cleared = rep.cleared + 1
                        else
                            BP.Pending()[s] = nil
                        end
                    end
                elseif r == "placed" then
                    rep.placed = rep.placed + 1
                elseif r == "same" then
                    rep.same = rep.same + 1
                elseif clear and HasAction(s) then
                    ClearSlot(s)
                    rep.cleared = rep.cleared + 1
                end
            elseif clear and HasAction(s) then
                ClearSlot(s)
                rep.cleared = rep.cleared + 1
            end
        end
        ClearCursor()
    end

    if BP.Get("doBinds") and L.binds then
        if BP.Get("clearBinds") then
            for i = 1, GetNumBindings() do
                local cmd, _, k1 = GetBinding(i)
                if cmd and k1 and not L.binds[cmd] then
                    for _, k in ipairs({ GetBindingKey(cmd) }) do
                        Unbind(k)
                        rep.unbound = rep.unbound + 1
                    end
                end
            end
        end
        for cmd, keys in pairs(L.binds) do
            if type(cmd) == "string" and type(keys) == "table" then
                local want = {}
                for _, k in ipairs(keys) do want[k] = true end
                for _, k in ipairs({ GetBindingKey(cmd) }) do
                    if not want[k] then Unbind(k) end
                end
                for _, k in ipairs(keys) do
                    if type(k) == "string" then
                        if GetBindingAction(k) == cmd or Bind(k, cmd) then
                            rep.binds = rep.binds + 1
                        else
                            rep.bindFailed = rep.bindFailed + 1
                        end
                    end
                end
            end
        end
        local set = GetCurrentBindingSet and GetCurrentBindingSet()
        if set then SaveBindings(set) end
    end

    BP.lastReport = rep
    return rep
end

-- Report of the last load, in chat.
function BP.PrintReport(rep)
    rep = rep or BP.lastReport
    if not rep then
        BP.Say("nothing loaded yet this session.")
        return
    end
    local A = BP.AccentHex()
    BP.Say("loaded " .. A .. tostring(rep.name) .. "|r.")
    if BP.Get("doBars") then
        BP.Say(string.format("action bars: %d placed, %d already there, %d cleared, %d not available.",
            rep.placed, rep.same, rep.cleared, #rep.missing))
        if #rep.waiting > 0 then
            local shown = {}
            for i = 1, math.min(#rep.waiting, 12) do shown[i] = rep.waiting[i] end
            BP.Say(string.format("|cffffd040%d spell%s not learned yet|r: %s button%s kept free, filled in the moment you "
                .. "learn %s: %s%s", #rep.waiting, #rep.waiting > 1 and "s" or "", #rep.waiting > 1 and "their" or "its",
                #rep.waiting > 1 and "s" or "", #rep.waiting > 1 and "them" or "it", table.concat(shown, ", "),
                #rep.waiting > 12 and ", ..." or ""))
        end
        if #rep.unlearned > 0 then
            BP.Say(string.format("|cffffd040%d spell%s not learned yet|r: on the bars anyway%s.",
                #rep.unlearned, #rep.unlearned > 1 and "s" or "",
                BP.Get("fillLearned") and ", the rank you learn is swapped in automatically" or ""))
        end
        if #rep.mismatch > 0 then
            BP.Say("|cffff8040the game put another spell ID on " .. #rep.mismatch .. " button(s):|r "
                .. table.concat(rep.mismatch, ", ", 1, math.min(#rep.mismatch, 6)))
        end
        if #rep.missing > 0 then
            local shown = {}
            for i = 1, math.min(#rep.missing, 12) do shown[i] = rep.missing[i] end
            local more = #rep.missing > 12 and (" |cff999999+" .. (#rep.missing - 12) .. " more|r") or ""
            BP.Say("|cffff8040not available here:|r " .. table.concat(shown, ", ") .. more)
        end
    end
    if BP.Get("doMacros") then
        BP.Say(string.format("macros: %d created, %d updated%s.", rep.macCreated, rep.macUpdated,
            rep.macFailed > 0 and (", |cffff4040" .. rep.macFailed .. " failed (no free macro slot?)|r") or ""))
    end
    if BP.Get("doBinds") then
        BP.Say(string.format("key bindings: %d set%s%s.", rep.binds,
            rep.unbound > 0 and (", " .. rep.unbound .. " cleared") or "",
            rep.bindFailed > 0 and (", |cffff4040" .. rep.bindFailed .. " failed (addon not loaded?)|r") or ""))
    end
end

-- Loads a saved layout (with the backup first, when on).
function BP.Load(name)
    local L = BP.DB().layouts[name]
    if not L then
        BP.Say("no layout called " .. tostring(name) .. ".")
        return
    end
    if InCombatLockdown() then
        BP.Say("layouts can only be loaded out of combat.")
        return
    end
    if BP.Get("backup") and not L.backup then
        BP.Save(BP.BACKUP_PREFIX .. (UnitName("player") or "?"), true)
    end
    local rep = BP.Apply(L)
    if rep then BP.PrintReport(rep) end
    return rep
end

-- The backup of this character, if there is one.
function BP.BackupName()
    local n = BP.BACKUP_PREFIX .. (UnitName("player") or "?")
    if BP.DB().layouts[n] then return n end
end

-------------------------------------------------------------------------------
--  Fill In When Learned: after a spell is learned, the waiting slots get the
--  rank this character knows now (Spell Rank decides which), until the saved
--  rank itself is known. A slot whose button no longer holds what was put
--  there (you moved or removed it) is dropped from the list.
-------------------------------------------------------------------------------
local fillQueued, fillAfterCombat = false, false

function BP.FillPending(silent)
    fillQueued = false
    local pending = BP.Pending()
    if not BP.Get("fillLearned") or not next(pending) then
        BP.pushed = nil
        return 0
    end
    if InCombatLockdown() then
        fillAfterCombat = true
        return 0
    end
    local book = BP.BuildBook()
    local mode = BP.Get("rankMode")
    local done, names, seen = 0, {}, {}

    -- Spells the game pushed onto empty buttons itself (it does that with every
    -- new spell): one pushed onto a button kept free for another spell is taken
    -- off again; one this layout has a button for is moved there below.
    local pushed = BP.pushed or {}
    BP.pushed = {}
    local pushedByName = {}
    for slot, sid in pairs(pushed) do
        local t, id = GetActionInfo(slot)
        if Plain(t) and t == "spell" and id == sid then
            local p = pending[slot]
            if p and p.cur == false then
                ClearSlot(slot)
            else
                local n = SpellName(sid)
                if n then
                    pushedByName[n] = pushedByName[n] or {}
                    table.insert(pushedByName[n], slot)
                end
            end
        end
    end

    for s, p in pairs(pending) do
        local curT, curID = GetActionInfo(s)
        if not Plain(curT) then curT, curID = nil, nil end
        local ours
        if p.cur == false then
            ours = not HasAction(s)                  -- kept free, still empty
        else
            ours = curT == "spell" and curID == p.cur -- still what we put there
        end
        if not ours then
            pending[s] = nil
        else
            local b = BP.ResolveSpell(book, p, mode)
            if b and b.id ~= curID then
                ClearCursor()
                PickupBookEntry(b)
                if GetCursorInfo() then
                    PlaceAction(s)
                    ClearCursor()
                    local _, id2 = GetActionInfo(s)
                    p.cur = Plain(id2) and id2 or b.id
                    done = done + 1
                    local label = (p.n or "?") .. (b.r and (" (" .. b.r .. ")") or "")
                    if not seen[label] then
                        seen[label] = true
                        names[#names + 1] = label
                    end
                end
                ClearCursor()
            end
            -- The saved rank (or better) is on the button: nothing left to wait for.
            if b and (b.id == p.id or (b.r or 0) >= (p.r or 0)) then pending[s] = nil end
            -- The copy the game pushed onto some other button goes.
            if b and p.n and pushedByName[p.n] and p.cur ~= false then
                for _, slot in ipairs(pushedByName[p.n]) do
                    if slot ~= s then
                        local t2, id2 = GetActionInfo(slot)
                        if Plain(t2) and t2 == "spell" and SpellName(id2) == p.n then ClearSlot(slot) end
                    end
                end
                pushedByName[p.n] = nil
            end
        end
    end
    if done > 0 and not silent then
        BP.Say("learned: " .. table.concat(names, ", ") .. " |cff999999(" .. done .. " button"
            .. (done > 1 and "s" or "") .. " updated)|r")
    end
    return done
end

local function QueueFill()
    if fillQueued then return end
    fillQueued = true
    C_Timer.After(1, function() BP.FillPending() end)
end

-- RegisterEvent throws on an event the client doesn't have (the 12.x engine
-- renamed LEARNED_SPELL_IN_TAB to LEARNED_SPELL_IN_SKILL_LINE), and an error
-- here would stop the rest of this file from loading: each one is guarded.
local fillFrame = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
                      "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED",
                      "SPELL_PUSHED_TO_ACTIONBAR" }) do
    pcall(fillFrame.RegisterEvent, fillFrame, ev)
end
fillFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "SPELL_PUSHED_TO_ACTIONBAR" then
        -- (spellID, actionSlot, slotPosition): remembered for FillPending.
        local sid, slot = ...
        if Plain(sid) and Plain(slot) and type(slot) == "number" then
            BP.pushed = BP.pushed or {}
            BP.pushed[slot] = sid
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not fillAfterCombat then return end
        fillAfterCombat = false
    end
    QueueFill()
end)

function BP.CountPending()
    local n = 0
    for _ in pairs(BP.Pending()) do n = n + 1 end
    return n
end

-------------------------------------------------------------------------------
--  Export / import strings
--  A small serializer of its own (no loadstring: an imported string is only
--  ever read as data), LibDeflate (shipped with EllesmereUI) to compress it.
-------------------------------------------------------------------------------
local function SerValue(v, parts, depth)
    depth = depth or 0
    local tv = type(v)
    if tv == "number" then
        if v ~= v then
            parts[#parts + 1] = "N"               -- nan
        elseif v == math.huge or v == -math.huge then
            parts[#parts + 1] = v > 0 and "I" or "J"
        elseif v == math.floor(v) and v > -2147483648 and v < 2147483648 then
            parts[#parts + 1] = "n" .. string.format("%d", v) .. ";"
        else
            parts[#parts + 1] = "n" .. string.format("%.17g", v) .. ";"
        end
    elseif tv == "string" then
        parts[#parts + 1] = "s" .. #v .. ":" .. v
    elseif tv == "boolean" then
        parts[#parts + 1] = v and "T" or "F"
    elseif tv == "table" then
        if depth > 90 then parts[#parts + 1] = "te" return end -- a loop: written as {}
        parts[#parts + 1] = "t"
        for k, val in pairs(v) do
            local tk = type(k)
            local tval = type(val)
            if (tk == "string" or tk == "number" or tk == "boolean")
                    and (tval == "string" or tval == "number" or tval == "boolean" or tval == "table") then
                SerValue(k, parts, depth + 1)
                SerValue(val, parts, depth + 1)
            end
        end
        parts[#parts + 1] = "e"
    end
end

local function Serialize(v)
    local parts = {}
    SerValue(v, parts)
    return table.concat(parts)
end

local function Deserialize(str)
    local pos, depth = 1, 0
    local read
    read = function()
        local tag = str:sub(pos, pos)
        pos = pos + 1
        if tag == "n" then
            local e = str:find(";", pos, true)
            local v = tonumber(str:sub(pos, e - 1))
            if not v then error("number") end
            pos = e + 1
            return v
        elseif tag == "s" then
            local c = str:find(":", pos, true)
            local len = tonumber(str:sub(pos, c - 1))
            if not len or len < 0 then error("string") end
            local v = str:sub(c + 1, c + len)
            if #v ~= len then error("string") end
            pos = c + 1 + len
            return v
        elseif tag == "T" then
            return true
        elseif tag == "F" then
            return false
        elseif tag == "I" then
            return math.huge
        elseif tag == "J" then
            return -math.huge
        elseif tag == "N" then
            return 0 / 0
        elseif tag == "t" then
            depth = depth + 1
            if depth > 100 then error("depth") end
            local t = {}
            while str:sub(pos, pos) ~= "e" do
                if pos > #str then error("end") end
                local k = read()
                local v = read()
                t[k] = v
            end
            pos = pos + 1
            depth = depth - 1
            return t
        end
        error("tag")
    end
    local ok, v = pcall(read)
    if ok then return v end
    return nil
end

local function Deflate()
    return LibStub and LibStub("LibDeflate", true) or _G.LibDeflate
end

-- Generic string packing, shared with the Game Settings tab:
-- prefix .. EncodeForPrint(CompressDeflate(Serialize(tbl))) and back.
function BP.Pack(prefix, tbl)
    local LD = Deflate()
    if not LD then return nil end
    return prefix .. LD:EncodeForPrint(LD:CompressDeflate(Serialize(tbl)))
end

function BP.Unpack(prefix, str)
    if type(str) ~= "string" then return nil, "empty string" end
    str = str:gsub("%s+", "")
    if str:sub(1, #prefix) ~= prefix then return nil, "wrong kind of string" end
    local LD = Deflate()
    if not LD then return nil, "LibDeflate is missing" end
    local decoded = LD:DecodeForPrint(str:sub(#prefix + 1))
    if not decoded then return nil, "the string is damaged (decode)" end
    local raw = LD:DecompressDeflate(decoded)
    if not raw then return nil, "the string is damaged (decompress)" end
    local t = Deserialize(raw)
    if type(t) ~= "table" then return nil, "the string is damaged (data)" end
    return t
end

function BP.ExportString(L)
    local LD = Deflate()
    if not LD then return nil end
    local copy = {}
    for k, v in pairs(L) do copy[k] = v end
    copy.backup = nil
    return BP.EXPORT_PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(Serialize(copy)))
end

-- A decoded layout, cleaned field by field (it came from someone else).
local function Clean(raw)
    if type(raw) ~= "table" or type(raw.slots) ~= "table" then return nil end
    local function S(v, max) return type(v) == "string" and v:sub(1, max or 255) or nil end
    local function N(v) return type(v) == "number" and v or nil end
    local L = {
        v = 1, name = S(raw.name, 60), char = S(raw.char, 80), class = S(raw.class, 20),
        level = N(raw.level), time = N(raw.time),
        slots = {}, macros = {}, binds = {},
    }
    for i, m in ipairs(type(raw.macros) == "table" and raw.macros or {}) do
        if type(m) == "table" and S(m.n) then
            L.macros[i] = { n = S(m.n, 16), ic = (type(m.ic) == "number" or type(m.ic) == "string") and m.ic or DEFAULT_ICON,
                            b = S(m.b, 255) or "", c = m.c and true or nil }
        else
            L.macros[i] = { n = "?", ic = DEFAULT_ICON, b = "" }
        end
    end
    local nSlots = 0
    for s, e in pairs(raw.slots) do
        if type(s) == "number" and s >= 1 and s <= BP.MAX_SLOTS and s == math.floor(s) and type(e) == "table" then
            local t = e.t
            local c
            if t == "spell" and N(e.id) then
                c = { t = "spell", id = e.id, n = S(e.n), r = N(e.r) }
            elseif t == "macro" then
                c = { t = "macro", m = N(e.m), mn = S(e.mn, 16) }
            elseif t == "item" and N(e.id) then
                c = { t = "item", id = e.id, n = S(e.n) }
            elseif t == "eqset" and S(e.n) then
                c = { t = "eqset", n = S(e.n, 40) }
            end
            if c then
                L.slots[s] = c
                nSlots = nSlots + 1
            end
        end
    end
    local nBinds = 0
    for cmd, keys in pairs(type(raw.binds) == "table" and raw.binds or {}) do
        if S(cmd) and type(keys) == "table" then
            local list = {}
            for _, k in ipairs(keys) do
                if S(k, 64) then list[#list + 1] = k end
            end
            if #list > 0 then
                L.binds[cmd] = list
                nBinds = nBinds + #list
            end
        end
    end
    L.nSlots, L.nMacros, L.nBinds = nSlots, #L.macros, nBinds
    return L
end

function BP.DecodeString(str)
    if type(str) ~= "string" then return nil, "empty string" end
    str = str:gsub("%s+", "")
    if str:sub(1, #BP.EXPORT_PREFIX) ~= BP.EXPORT_PREFIX then
        return nil, "this is not a Profiles > Action Bars string"
    end
    local LD = Deflate()
    if not LD then return nil, "LibDeflate is missing" end
    local decoded = LD:DecodeForPrint(str:sub(#BP.EXPORT_PREFIX + 1))
    if not decoded then return nil, "the string is damaged (decode)" end
    local raw = LD:DecompressDeflate(decoded)
    if not raw then return nil, "the string is damaged (decompress)" end
    local L = Clean(Deserialize(raw))
    if not L then return nil, "the string is damaged (data)" end
    return L
end

-- A name not used yet: "Name", "Name (2)", ...
function BP.FreeName(base)
    base = (base and base ~= "") and base or "Imported"
    local layouts = BP.DB().layouts
    if not layouts[base] then return base end
    for i = 2, 99 do
        local n = base .. " (" .. i .. ")"
        if not layouts[n] then return n end
    end
    return base .. " " .. time()
end

-------------------------------------------------------------------------------
--  Layout list helpers
-------------------------------------------------------------------------------
-- Names, saved layouts first (alphabetical), backups last.
function BP.SortedNames()
    local out = {}
    for n in pairs(BP.DB().layouts) do out[#out + 1] = n end
    local layouts = BP.DB().layouts
    table.sort(out, function(a, b)
        local ba, bb = layouts[a].backup and true or false, layouts[b].backup and true or false
        if ba ~= bb then return bb end
        return a:lower() < b:lower()
    end)
    return out
end

function BP.Selected()
    local sel = BP.Get("selected")
    local layouts = BP.DB().layouts
    if sel and layouts[sel] then return sel end
    return BP.SortedNames()[1]
end

function BP.Delete(name)
    local d = BP.DB()
    d.layouts[name] = nil
    if d.opt.selected == name then d.opt.selected = nil end
end

function BP.Rename(old, new)
    local layouts = BP.DB().layouts
    local L = layouts[old]
    if not L or not new or new == "" or layouts[new] then return false end
    layouts[new], layouts[old] = L, nil
    L.name = new
    L.backup = nil
    BP.Set("selected", new)
    return true
end
