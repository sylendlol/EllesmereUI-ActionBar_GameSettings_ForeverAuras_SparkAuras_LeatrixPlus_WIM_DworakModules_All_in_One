if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUIBarProfiles_AllInOne.lua
--  Dworak > Profiles, "All in One" tab (the last one): the other tabs in ONE
--  string. Tick what goes into the export; an import puts every part where it
--  belongs, then a window lists what was imported and anything that didn't
--  work, with a Reload UI button (the game allows a reload only from a click).
--  Anything that didn't
--  work is listed in a window of its own (not in chat).
--
--  Parts and what an import does with them:
--    bars  every saved layout (backups left out) + this character's current
--          bars ("<Name> (current)"): ADDED to the saved layouts, and one is
--          LOADED: the exporting character's current bars when the class
--          matches, else the newest layout of this class in the string
--          (Action Bars tab's Load Options and backup; report in the window).
--    gs    the current game settings: saved as a set AND loaded, with the
--          Game Settings tab's Load Options (categories, backup, reset).
--    fa/sf every ForeverAuras / Spark Forever aura, written like their own
--          tabs do (If An Aura Already Exists from those tabs).
--    lp    every Leatrix Plus setting ("/ltp nosave" first, like its tab).
--    wim   the WIM parts ticked on the WIM tab.
--    dm    the Dworak modules ticked on the Dworak Modules tab.
--  Each part keeps the backup its own tab makes, so Undo Last Import / Undo
--  Last Load on that tab puts it back.
--
--  The string is "!EUIAIO1!" + BP.Pack of { v, char, time, parts = { key =
--  the same table that tab's own export string holds } }. On import every
--  part goes through its tab's own cleaner (FromRaw / CleanLayout).
-------------------------------------------------------------------------------
local _, ns = ...
local BP = ns.BP
if not BP then return end

local AIO = {}
BP.AIO = AIO

AIO.PAGE   = "All in One"
AIO.PREFIX = "!EUIAIO1!"

local function Mod(key)
    if key == "gs" then return BP.GS end
    if key == "fa" then return BP.FA end
    if key == "sf" then return BP.SF end
    if key == "lp" then return BP.LP end
    if key == "wim" then return BP.WM end
    if key == "dm" then return BP.DM end
end

-- Can this part be exported / imported here? true, or false + why not.
local function Available(key)
    if key == "bars" then return true end
    local M = Mod(key)
    if not M then return false, "not available" end
    if key == "gs" then return true end
    if key == "fa" or key == "sf" then
        if M.Displays() then return true end
        return false, M.cfg.label .. " isn't loaded"
    end
    if key == "lp" then
        if M.Loaded() then return true end
        return false, "Leatrix Plus isn't loaded"
    end
    if key == "wim" then
        if M.Loaded() then return true end
        return false, "WIM isn't loaded"
    end
    if key == "dm" then
        for _, m in ipairs(M.Modules()) do
            if m.loaded then return true end
        end
        return false, "no Dworak module is enabled"
    end
    return false, "not available"
end

AIO.PARTS = {
    { key = "bars", label = "Action Bars",
      tip = "Every saved layout (backups left out) and this character's current bars. An import adds them to "
          .. "the saved layouts and loads this character's bars from the string (same class), with the Action Bars "
          .. "tab's Load Options." },
    { key = "gs", label = "Game Settings",
      tip = "Your current game settings (Esc > Options). An import saves them as a set and loads them, with the "
          .. "Game Settings tab's Load Options." },
    { key = "fa", label = "ForeverAuras",
      tip = "Every ForeverAuras aura and group. Auras already there: as set on the ForeverAuras tab (If An Aura "
          .. "Already Exists)." },
    { key = "sf", label = "Spark Forever",
      tip = "Every Spark Forever aura and group. Auras already there: as set on the Spark Forever tab (If An Aura "
          .. "Already Exists)." },
    { key = "lp", label = "Leatrix Plus",
      tip = "Every Leatrix Plus setting (chat history left out). An import replaces all of them." },
    { key = "wim", label = "WIM",
      tip = "The WIM parts ticked on the WIM tab (settings, filters, aliases, history)." },
    { key = "dm", label = "Dworak Modules",
      tip = "The settings of the modules ticked on the Dworak Modules tab." },
}
local LABEL = {}
for _, p in ipairs(AIO.PARTS) do LABEL[p.key] = p.label end

function AIO.PartOn(key)
    local v = BP.Get("aioPart_" .. key)
    if v == nil then return true end
    return v and true or false
end

function AIO.SetPartOn(key, v) BP.Set("aioPart_" .. key, v and true or false) end

local function Who(char)
    return char and (char:match("^([^%-]+)") or char) or "?"
end

-------------------------------------------------------------------------------
--  Result window: what didn't work, then (after an import) Reload UI.
-------------------------------------------------------------------------------
local win

local function Reload()
    if C_UI and C_UI.Reload then
        if pcall(C_UI.Reload) then return end
    end
    pcall(ReloadUI)
end
AIO.Reload = Reload

local function BuildWindow()
    win = CreateFrame("Frame", "EllesmereUIProfilesAllInOneResult", UIParent, "BackdropTemplate")
    win:SetSize(580, 400)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if win.SetBackdrop then
        win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
                          edgeSize = 1 })
        win:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
        win:SetBackdropBorderColor(0.3, 0.3, 0.33, 1)
    end

    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.title:SetPoint("TOPLEFT", 18, -16)
    win.title:SetJustifyH("LEFT")

    win.sub = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -6)
    win.sub:SetPoint("RIGHT", win, "RIGHT", -18, 0)
    win.sub:SetJustifyH("LEFT")
    win.sub:SetTextColor(0.65, 0.65, 0.65)

    local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    if not ok or not sf then sf = CreateFrame("ScrollFrame", nil, win) end
    sf:SetPoint("TOPLEFT", 18, -68)
    sf:SetPoint("BOTTOMRIGHT", -38, 56)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        local v = math.min(max, math.max(0, (self:GetVerticalScroll() or 0) - delta * 40))
        self:SetVerticalScroll(v)
    end)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(520, 10)
    sf:SetScrollChild(child)
    win.scroll = sf
    win.child = child

    win.text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.text:SetPoint("TOPLEFT", 0, 0)
    win.text:SetWidth(520)
    win.text:SetJustifyH("LEFT")
    win.text:SetJustifyV("TOP")
    if win.text.SetSpacing then win.text:SetSpacing(3) end

    win.button = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.button:SetSize(160, 26)

    -- Close: next to Reload UI after an import (the import stays in place;
    -- it finishes with your next reload / logout).
    win.closeButton = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.closeButton:SetSize(160, 26)
    win.closeButton:SetText("Close")
    win.closeButton:SetScript("OnClick", function() win:Hide() end)

    win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    win.close:SetPoint("TOPRIGHT", -2, -2)

    -- Escape closes it too.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "EllesmereUIProfilesAllInOneResult")
    end
end

-- lines: { "text", ... }. reload: the button reloads the UI (after an
-- import), else it closes the window.
function AIO.ShowResult(title, sub, lines, reload)
    if not win then BuildWindow() end
    win.title:SetText(BP.AccentHex() .. title .. "|r")
    win.sub:SetText(sub or "")
    win.text:SetText(table.concat(lines, "\n"))
    win.child:SetHeight(math.max(10, (win.text:GetStringHeight() or 0) + 8))
    win.scroll:SetVerticalScroll(0)
    win.button:ClearAllPoints()
    if reload then
        win.button:SetText("Reload UI")
        win.button:SetScript("OnClick", Reload)
        win.button:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -6, 16)
        win.closeButton:SetPoint("BOTTOMLEFT", win, "BOTTOM", 6, 16)
        win.closeButton:Show()
    else
        win.button:SetText("Close")
        win.button:SetScript("OnClick", function() win:Hide() end)
        win.button:SetPoint("BOTTOM", 0, 16)
        win.closeButton:Hide()
    end
    win.close:Show()
    win:Show()
    win:Raise()
end

-------------------------------------------------------------------------------
--  Export
-------------------------------------------------------------------------------
-- payload, labels of the parts in it, notes ("Label: why it's left out").
function AIO.Collect()
    local parts, labels, notes = {}, {}, {}
    local function Left(key, why) notes[#notes + 1] = LABEL[key] .. ": " .. tostring(why) end
    for _, p in ipairs(AIO.PARTS) do
        local key = p.key
        if AIO.PartOn(key) then
            local okAvail, why = Available(key)
            if not okAvail then
                Left(key, why)
            elseif key == "bars" then
                local list = {}
                local names = BP.SortedNames()
                for _, n in ipairs(names) do
                    local L = BP.DB().layouts[n]
                    if L and not L.backup then
                        local c = {}
                        for k, v in pairs(L) do c[k] = v end
                        c.backup = nil
                        list[#list + 1] = c
                    end
                end
                local cur = BP.Capture((UnitName("player") or "?") .. " (current)")
                if cur then list[#list + 1] = cur end
                -- current: which layout an import loads (this character's bars).
                parts.bars = { list = list, current = cur and #list or nil }
                labels[#labels + 1] = string.format("%s (%d layouts)", p.label, #list)
            elseif key == "gs" then
                local S = BP.GS.Capture("All in One: " .. (UnitName("player") or "?"))
                if (S.count or 0) == 0 then
                    Left(key, "the game didn't list its settings")
                else
                    parts.gs = S
                    labels[#labels + 1] = string.format("%s (%d)", p.label, S.count)
                end
            elseif key == "fa" or key == "sf" then
                local payload, n = Mod(key).Payload()
                if payload then
                    parts[key] = payload
                    labels[#labels + 1] = string.format("%s (%d auras)", p.label, n)
                else
                    Left(key, n)
                end
            elseif key == "lp" then
                local payload, n = BP.LP.Payload()
                if payload then
                    parts.lp = payload
                    labels[#labels + 1] = string.format("%s (%d)", p.label, n)
                else
                    Left(key, n)
                end
            elseif key == "wim" then
                local payload, wparts = BP.WM.Payload()
                if payload then
                    parts.wim = payload
                    labels[#labels + 1] = p.label .. " (" .. table.concat(wparts, ", ") .. ")"
                else
                    Left(key, wparts)
                end
            elseif key == "dm" then
                local payload, titles = BP.DM.Payload()
                if payload then
                    parts.dm = payload
                    labels[#labels + 1] = string.format("%s (%d)", p.label, #titles)
                else
                    Left(key, titles)
                end
            end
        end
    end
    return { v = 1, char = BP.CharKey(), time = time(), parts = parts }, labels, notes
end

local function ShowExport()
    if InCombatLockdown() then
        AIO.ShowResult("Export All in One", "Nothing was exported.", { "Out of combat only." }, false)
        return
    end
    local payload, labels, notes = AIO.Collect()
    if #labels == 0 then
        local lines = { "Nothing to export." }
        for _, n in ipairs(notes) do lines[#lines + 1] = "|cffff4040" .. n .. "|r" end
        AIO.ShowResult("Export All in One", "Nothing was exported.", lines, false)
        return
    end
    local str = BP.Pack(AIO.PREFIX, payload)
    if not str then
        AIO.ShowResult("Export All in One", "Nothing was exported.", { "LibDeflate is missing." }, false)
        return
    end
    EllesmereUI:ShowCopyPopup("Export All in One", table.concat(labels, ", ")
        .. " - copy the string and paste it on the other account"
        .. (#notes > 0 and ("\n|cffffd040Left out: " .. table.concat(notes, "; ") .. "|r") or ""), str)
end

local function AskExport()
    local any = false
    for _, p in ipairs(AIO.PARTS) do
        if AIO.PartOn(p.key) then any = true end
    end
    if not any then
        AIO.ShowResult("Export All in One", "Nothing was exported.", { "No part is ticked." }, false)
        return
    end
    -- Leatrix Plus writes its settings to disk only at reload: offer one first.
    if AIO.PartOn("lp") and BP.LP and BP.LP.Loaded() then
        EllesmereUI:ShowConfirmPopup({
            title = "Export All in One",
            message = "Leatrix Plus writes its settings to disk only when the UI reloads. Changes made in Leatrix Plus "
                .. "since the last reload are in the string only after one.",
            confirmText = "Reload & Export",
            cancelText = "Export Now",
            reload = true,
            onConfirm = function() BP.Set("aioExportPending", true) end,
            onCancel = function() C_Timer.After(0, ShowExport) end,
            onDismiss = function() end,
        })
        return
    end
    ShowExport()
end

-- Reload & Export: the string right after the reload.
local loginFrame = CreateFrame("Frame")
pcall(loginFrame.RegisterEvent, loginFrame, "PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if BP.Get("aioExportPending") then
        BP.Set("aioExportPending", nil)
        C_Timer.After(3, ShowExport)
    end
end)

-------------------------------------------------------------------------------
--  Import
-------------------------------------------------------------------------------
-- { char, time, parts = { key = cleaned part }, bad = { "Label: why" } }
function AIO.Decode(str)
    local raw, err = BP.Unpack(AIO.PREFIX, str)
    if not raw then
        if err == "wrong kind of string" then
            err = "this is not a Profiles > All in One string (the other tabs' strings go into their own tab)"
        end
        return nil, err
    end
    if type(raw.parts) ~= "table" then return nil, "the string is damaged (data)" end
    local P = { char = type(raw.char) == "string" and raw.char or nil,
                time = type(raw.time) == "number" and raw.time or nil, parts = {}, bad = {}, count = 0 }
    local function Bad(key, why) P.bad[#P.bad + 1] = LABEL[key] .. ": " .. tostring(why) end
    local function Put(key, v, why)
        if v then
            P.parts[key] = v
            P.count = P.count + 1
        else
            Bad(key, why or "damaged")
        end
    end
    local rp = raw.parts
    if rp.bars ~= nil then
        local list, current = {}, nil
        if type(rp.bars) == "table" and type(rp.bars.list) == "table" then
            for i, L in ipairs(rp.bars.list) do
                local c = BP.CleanLayout(L)
                if c then
                    list[#list + 1] = c
                    if rp.bars.current == i then current = #list end
                end
            end
        end
        Put("bars", #list > 0 and { list = list, current = current } or nil, "no layout in it could be read")
    end
    if rp.gs ~= nil then Put("gs", BP.GS.FromRaw(rp.gs)) end
    for _, key in ipairs({ "fa", "sf", "lp", "wim", "dm" }) do
        if rp[key] ~= nil then
            local M = Mod(key)
            if M then Put(key, M.FromRaw(rp[key])) else Bad(key, "not available") end
        end
    end
    if P.count == 0 then return nil, "the string holds nothing that can be read" end
    return P
end

-- The layout an import loads on this character: the exporting character's
-- current bars when the class matches, else the newest layout of this class
-- in the string. Returns index or nil + why not.
local function PickLayout(bars)
    local _, myClass = UnitClass("player")
    local L = bars.current and bars.list[bars.current]
    if L and (not L.class or L.class == myClass) then return bars.current end
    local best, bestTime
    for i, c in ipairs(bars.list) do
        if c.class == myClass and (not bestTime or (c.time or 0) > bestTime) then
            best, bestTime = i, c.time or 0
        end
    end
    if best then return best end
    local cls = BP.ClassName and BP.ClassName(myClass) or tostring(myClass)
    return nil, "no layout in the string was saved on a " .. tostring(cls)
end
AIO.PickLayout = PickLayout

local function Describe(key, v)
    if key == "bars" then
        local i, why = PickLayout(v)
        if i then
            return string.format("%d layouts saved, %s loaded on this character", #v.list,
                tostring(v.list[i].name))
        end
        return string.format("%d layouts saved, none loaded (%s)", #v.list, why)
    end
    if key == "gs" then return string.format("%d settings (loaded)", v.count or 0) end
    if key == "fa" or key == "sf" then return string.format("%d auras", v.count or 0) end
    if key == "lp" then return string.format("%d settings (replace yours)", v.count or 0) end
    if key == "wim" then return table.concat(v.labels or {}, ", ") end
    if key == "dm" then return string.format("%d modules", v.count or 0) end
    return ""
end

-- Puts every part in place, then shows the result window (what was imported,
-- what went wrong) with a Reload UI button.
function AIO.Apply(P)
    local problems, done = {}, {}
    local function Fail(key, text) problems[#problems + 1] = "|cffff4040" .. LABEL[key] .. ":|r " .. text end
    local parts = P.parts
    -- Parts of the string that couldn't be read at all.
    for _, b in ipairs(P.bad or {}) do
        problems[#problems + 1] = "|cffff4040" .. b .. "|r (damaged in the string, skipped)"
    end

    for _, p in ipairs(AIO.PARTS) do
        local key, v = p.key, parts[p.key]
        if v and key ~= "gs" then
            local okAvail, why = Available(key)
            if not okAvail then
                Fail(key, "skipped, " .. tostring(why) .. ".")
            elseif key == "bars" then
                -- A layout with the same name is replaced (importing the same
                -- string again makes no "(2)" copies). Backups are never hit:
                -- the export leaves them out.
                local layouts = BP.DB().layouts
                for _, L in ipairs(v.list) do
                    local name = L.name or "Imported"
                    if name:sub(1, #BP.BACKUP_PREFIX) == BP.BACKUP_PREFIX then name = BP.FreeName(name .. " (imported)") end
                    L.name = name
                    layouts[name] = L
                end
                -- Then one of them is loaded (Action Bars tab's Load Options,
                -- its backup first), with the report going to the window.
                local pick, why = PickLayout(v)
                if not pick then
                    Fail(key, "layouts saved, none loaded: " .. why .. ". Load one on the Action Bars tab.")
                else
                    local L = v.list[pick]
                    if BP.Get("backup") then
                        BP.Save(BP.BACKUP_PREFIX .. (UnitName("player") or "?"), true)
                    end
                    local ok, rep = pcall(BP.Apply, L)
                    if not ok or not rep then
                        Fail(key, "\"" .. tostring(L.name) .. "\" saved but not loaded ("
                            .. tostring(ok and "in combat?" or rep) .. "). Load it on the Action Bars tab.")
                    else
                        BP.Set("selected", L.name)
                        done[#done + 1] = LABEL[key] .. " (\"" .. tostring(L.name) .. "\" loaded)"
                        if #rep.missing > 0 then
                            Fail(key, "not available here: " .. table.concat(rep.missing, ", ") .. ".")
                        end
                        if (rep.macFailed or 0) > 0 then
                            Fail(key, rep.macFailed .. " macro(s) couldn't be created (no free macro slot?)"
                                .. (#(rep.macFailedNames or {}) > 0 and (": " .. table.concat(rep.macFailedNames, ", ")) or "")
                                .. ".")
                        end
                        if (rep.bindFailed or 0) > 0 then
                            Fail(key, rep.bindFailed .. " key binding(s) couldn't be set (their addon not loaded?).")
                        end
                    end
                end
            elseif key == "fa" or key == "sf" then
                local ok, a = pcall(Mod(key).Write, v)
                if ok and a then done[#done + 1] = LABEL[key]
                else Fail(key, "the auras couldn't be written (" .. tostring(ok and "addon not ready" or a) .. ").") end
            elseif key == "wim" then
                local ok, r = pcall(BP.WM.Apply, v.data, true)
                if ok and r then done[#done + 1] = LABEL[key]
                else Fail(key, "couldn't be written (" .. tostring(ok and "WIM isn't loaded" or r) .. ").") end
            elseif key == "dm" then
                local ok, applied, skipped = pcall(BP.DM.Apply, v.mods, true)
                if not ok then
                    Fail(key, "couldn't be written (" .. tostring(applied) .. ").")
                else
                    if #applied > 0 then done[#done + 1] = LABEL[key] end
                    if #skipped > 0 then
                        Fail(key, "not installed or not enabled here, skipped: " .. table.concat(skipped, ", ") .. ".")
                    end
                end
            elseif key == "lp" then
                BP.LP.Backup()
                local ok, r = pcall(BP.LP.Apply, v.db)
                if ok and r then done[#done + 1] = LABEL[key]
                else Fail(key, "Leatrix Plus couldn't be told not to save over it, nothing was changed.") end
            end
        end
    end

    -- Always the window: the game only allows a reload from a click (a reload
    -- called from the Game Settings re-check timer is ADDON_ACTION_BLOCKED),
    -- so its Reload UI button does it.
    local function Finish()
        local lines = {}
        if #done > 0 then
            lines[#lines + 1] = "|cff40ff40Imported:|r"
            for _, d in ipairs(done) do lines[#lines + 1] = "  " .. d end
        end
        if #problems > 0 then
            if #lines > 0 then lines[#lines + 1] = " " end
            for _, l in ipairs(problems) do lines[#lines + 1] = l end
        end
        if #lines == 0 then lines[1] = "Nothing needed changing." end
        AIO.ShowResult("All in One Import", #problems == 0
            and "Everything is in place. Reload the UI to finish."
            or "Not everything worked. The rest is in place; reload the UI to finish.", lines, true)
    end

    -- Game Settings last: they are checked again a second after being set.
    local S = parts.gs
    if not S then return Finish() end
    local GS = BP.GS
    -- Same name: replaced (no "(2)" copies), backups never hit.
    local name = S.name or "Imported"
    if name:sub(1, #BP.BACKUP_PREFIX) == BP.BACKUP_PREFIX then name = GS.FreeName(name .. " (imported)") end
    S.name = name
    S.backup = nil
    GS.Store()[name] = S
    local started = GS.Load(name, function(rep)
        if rep.changed > 0 or rep.total == 0 then done[#done + 1] = LABEL.gs end
        for _, d in ipairs(rep.failedList or {}) do
            local now = select(1, GS.Info(d.n))
            local hint = GS.HAND_HINT[d.n]
            Fail("gs", string.format("refused by the game: %s = %s (now %s)%s", d.n, tostring(d.val), tostring(now),
                hint and (" - set it by hand: " .. hint(d.val)) or ""))
        end
        for _, d in ipairs(rep.manual or {}) do
            local hint = GS.HAND_HINT[d.n]
            Fail("gs", "set it by hand: " .. (hint and hint(d.val) or (d.n .. " = " .. tostring(d.val)))
                .. " (the game doesn't let addons change it)")
        end
        Finish()
    end)
    if not started then
        Fail("gs", "saved as \"" .. name .. "\" but not loaded (in combat?): load it on the Game Settings tab.")
        Finish()
    end
end

local function AskImport()
    if InCombatLockdown() then
        AIO.ShowResult("All in One Import", "Nothing was imported.", { "Out of combat only." }, false)
        return
    end
    EllesmereUI:ShowImportPopup(function(str)
        local P, err = AIO.Decode(str)
        if not P then
            AIO.ShowResult("All in One Import", "Nothing was imported.", { "|cffff4040" .. tostring(err) .. "|r" }, false)
            return
        end
        local lines, skip = {}, {}
        for _, p in ipairs(AIO.PARTS) do
            local v = P.parts[p.key]
            if v then
                local okAvail, why = Available(p.key)
                if okAvail then
                    lines[#lines + 1] = p.label .. ": " .. Describe(p.key, v)
                else
                    skip[#skip + 1] = p.label .. " (" .. tostring(why) .. ")"
                end
            end
        end
        if #lines == 0 then
            local out = { "None of the parts in the string can be imported here:" }
            for _, s in ipairs(skip) do out[#out + 1] = "|cffff4040" .. s .. "|r" end
            for _, b in ipairs(P.bad) do out[#out + 1] = "|cffff4040" .. b .. "|r" end
            AIO.ShowResult("All in One Import", "Nothing was imported.", out, false)
            return
        end
        local warn = {}
        if #skip > 0 then warn[#warn + 1] = "|cffffd040Skipped here: " .. table.concat(skip, ", ") .. "|r" end
        if #P.bad > 0 then warn[#warn + 1] = "|cffff4040Damaged, skipped: " .. table.concat(P.bad, ", ") .. "|r" end
        warn[#warn + 1] = "|cff999999What you have now is kept for Undo on each tab. Auras can run their own code: "
            .. "only import strings you made yourself or trust.|r"
        C_Timer.After(0, function()
            EllesmereUI:ShowConfirmPopup({
                title = "Import All in One",
                message = string.format("From %s%s:\n%s\nThen a window shows the result; its Reload UI button finishes the import.", Who(P.char),
                    P.time and (" (" .. date("%Y-%m-%d", P.time) .. ")") or "", table.concat(lines, "\n")),
                disclaimer = table.concat(warn, "\n"),
                confirmText = "Import",
                onConfirm = function()
                    -- Damaged / unavailable parts go into the result window too.
                    local ok, e = pcall(AIO.Apply, P)
                    if not ok then
                        AIO.ShowResult("All in One Import", "The import stopped with an error. Parts before it are "
                            .. "in place; reload to finish.", { "|cffff4040" .. tostring(e) .. "|r" }, true)
                    end
                end,
            })
        end)
    end, "Import All in One", "Paste a Profiles > All in One string below")
end

AIO.AskExport, AIO.AskImport = AskExport, AskImport

-- The UI Accent Color repaints the highlighted intro row live.
if EllesmereUI.RegAccent then
    EllesmereUI.RegAccent({ type = "callback", fn = function()
        local ar, ag, ab = BP.Accent()
        if AIO.introWash then AIO.introWash:SetColorTexture(ar, ag, ab, 0.08) end
        if AIO.introBorder and AIO.introBorder.SetColor then AIO.introBorder:SetColor(ar, ag, ab, 0.7) end
    end })
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function PartInfo(key)
    local okAvail, why = Available(key)
    if not okAvail then return nil, why end
    if key == "bars" then
        local n = 0
        for _, L in pairs(BP.DB().layouts) do
            if not L.backup then n = n + 1 end
        end
        return n .. " saved layouts + this character's current bars."
    end
    if key == "gs" then return "Your current game settings." end
    if key == "fa" or key == "sf" then
        local n = Mod(key).Count()
        return (n or 0) .. " auras here."
    end
    if key == "lp" then
        local _, n = BP.LP.Settings()
        return (n or 0) .. " settings saved (at the last reload)."
    end
    if key == "wim" then
        local on = {}
        for _, p in ipairs(BP.WM.PARTS) do
            if BP.WM.PartOn(p.key) then on[#on + 1] = p.label end
        end
        return #on > 0 and ("Ticked on the WIM tab: " .. table.concat(on, ", ") .. ".") or "Nothing ticked on the WIM tab."
    end
    if key == "dm" then
        local n = 0
        for _, m in ipairs(BP.DM.Modules()) do
            if m.loaded and BP.DM.Selected(m.name) then n = n + 1 end
        end
        return n .. " modules ticked on the Dworak Modules tab."
    end
end

function AIO.BuildPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    _, h = W:SectionHeader(parent, "ALL IN ONE", y);  y = y - h

    local introRow
    introRow, h = W:DualRow(parent, y,
        { type = "label", text = "Everything on the other Profiles tabs in one string. Tick what goes into the export." }
    );  y = y - h
    -- Highlight like the Talent Calculator's Legacy row: accent frame and a
    -- faint accent wash (repainted when the UI Accent Color changes).
    local prebuild = EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild()
    if not prebuild and introRow and introRow.CreateTexture then
        local ar, ag, ab = BP.Accent()
        AIO.introWash = introRow:CreateTexture(nil, "BACKGROUND", nil, 2)
        AIO.introWash:SetAllPoints()
        AIO.introWash:SetColorTexture(ar, ag, ab, 0.08)
        AIO.introBorder = EllesmereUI.MakeBorder and EllesmereUI.MakeBorder(introRow, ar, ag, ab, 0.7, EllesmereUI.PanelPP)
    end

    -- One sentence per row: as one row the text ran past the page edge.
    for _, line in ipairs({
        "An import puts every part where it belongs.",
        "Then a window lists what was imported and anything that didn't work.",
        "Its Reload UI button finishes the import.",
        "Each tab's Undo puts its part back.",
    }) do
        _, h = W:DualRow(parent, y, { type = "label", text = "|cff999999" .. line .. "|r" });  y = y - h
    end

    local function PartToggle(p)
        if not p then return BLANK() end
        local info, why = PartInfo(p.key)
        return { type = "toggle", text = p.label,
                 tooltip = p.tip .. "\n" .. (info or (tostring(why) .. ": left out.")),
                 rawTooltip = true,
                 disabled = function() return not Available(p.key) end,
                 disabledTooltip = function() return select(2, Available(p.key)) or "" end,
                 getValue = function() return AIO.PartOn(p.key) end,
                 setValue = function(v) AIO.SetPartOn(p.key, v) end }
    end
    local parts = AIO.PARTS
    for i = 1, #parts, 2 do
        _, h = W:DualRow(parent, y, PartToggle(parts[i]), PartToggle(parts[i + 1]));  y = y - h
    end

    _, h = W:DualRow(parent, y,
        { type = "button", text = "Tick All", width = 160,
          onClick = function()
              for _, p in ipairs(AIO.PARTS) do AIO.SetPartOn(p.key, true) end
              EllesmereUI:RefreshPage()
          end },
        { type = "button", text = "Untick All", width = 160,
          onClick = function()
              for _, p in ipairs(AIO.PARTS) do AIO.SetPartOn(p.key, false) end
              EllesmereUI:RefreshPage()
          end }
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h
    _, h = W:SectionHeader(parent, "EXPORT / IMPORT", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Export All in One", buttonText = "Export",
          tooltip = "The ticked parts in one string. With Leatrix Plus ticked you can reload first, so its latest "
              .. "changes are in the string.",
          onClick = AskExport },
        { type = "labeledButton", text = "Import All in One", buttonText = "Paste String...",
          tooltip = "Puts every part of an All in One string where it belongs, then shows the result with a Reload UI button. Shows what is "
              .. "in the string first.",
          onClick = AskImport }
    );  y = y - h

    return math.abs(y)
end
