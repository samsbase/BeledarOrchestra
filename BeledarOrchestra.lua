local ADDON_NAME, ns = ...

BeledarOrchestraDB = BeledarOrchestraDB or {}

local PREFIX = "BeledarOrch"
local TARGET_NPC_ID = 255888
local UPDATE_INTERVAL = 0.2
local MAX_MEASURES = 25
local RAID_SLOTS = 40

local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"

local EMOTES = {
    CHEER = { command = "CHEER", display = "/cheer", spellId = 1266756 },
    SING = { command = "SING", display = "/sing", spellId = 1266760 },
    DANCE = { command = "DANCE", display = "/dance", spellId = 1266758 },
    VIOLIN = { command = "VIOLIN", display = "/violin", spellId = 1266761 },
    APPLAUD = { command = "APPLAUD", display = "/applaud", spellId = 1266754 },
    CONGRATS = { command = "CONGRATS", display = "/congrats", spellId = 1266755 },
    ROAR = { command = "ROAR", display = "/roar", spellId = 1266759 },
    BOW = { command = "BOW", display = "/bow", spellId = nil },
    PLACEHOLDER = { command = nil, display = "?", spellId = nil },
}

local SPELL_ID_TO_TOKEN = {}
for token, emote in pairs(EMOTES) do
    if emote.spellId then
        SPELL_ID_TO_TOKEN[emote.spellId] = token
    end
end

local MEASURES = ns.MEASURES

local state = {
    currentMeasure = nil,
    status = "YELLOW",
    mismatchText = "No measure selected",
    lastUpdate = 0,
    activePlayers = {},
    lastPingTime = 0,
}

local frame = CreateFrame("Frame")
local ui = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBeledar Orchestra:|r " .. tostring(msg))
end

local function GetNpcID(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local type, _, _, _, _, npcID = strsplit("-", guid)
    if type == "Creature" or type == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

local function IsTargetNpc(unit)
    return GetNpcID(unit) == TARGET_NPC_ID
end

local function IsLeaderOrAssist()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function GetRaidSlotForPlayer()
    if IsInRaid() then
        local playerName = UnitFullName("player")
        local members = {}

        for i = 1, MAX_RAID_MEMBERS do
            local name, rank, subgroup = GetRaidRosterInfo(i)
            if name then
                table.insert(members, {
                    name = name,
                    subgroup = subgroup or 9,
                    raidIndex = i,
                })
            end
        end

        table.sort(members, function(a, b)
            if a.subgroup ~= b.subgroup then
                return a.subgroup < b.subgroup
            end
            return a.raidIndex < b.raidIndex
        end)

        for visualSlot, member in ipairs(members) do
            if member.name == playerName then
                return visualSlot
            end
        end
    elseif IsInGroup() then
        return 1
    end

    return nil
end

local function GetMeasureEmote(measure, slot)
    if not measure or not slot or not MEASURES[measure] then
        return "PLACEHOLDER"
    end
    return MEASURES[measure][slot] or "PLACEHOLDER"
end

local function BuildExpectedCounts(measure)
    local expected = {}

    if not measure or not MEASURES[measure] then
        return expected
    end

    for slot = 1, RAID_SLOTS do
        local token = MEASURES[measure][slot]
        if token and token ~= "PLACEHOLDER" then
            local emote = EMOTES[token]
            if emote and emote.spellId then
                expected[emote.spellId] = (expected[emote.spellId] or 0) + 1
            end
        end
    end

    return expected
end

local function BuildObservedCounts()
    local observed = {}
    local anyAura = false

    AuraUtil.ForEachAura("target", "HELPFUL", nil, function(aura)
        if aura and aura.spellId then
            anyAura = true
            observed[aura.spellId] = aura.applications or 1
        end
        return false
    end, true)

    return observed, anyAura
end

local function CountsEqual(expected, observed)
    for spellId, expectedCount in pairs(expected) do
        if (observed[spellId] or 0) ~= expectedCount then
            return false
        end
    end

    for spellId, observedCount in pairs(observed) do
        if (expected[spellId] or 0) ~= observedCount then
            return false
        end
    end

    return true
end

local function GetSpellNameSafe(spellId)
    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellId)
        if n then return n end
    end
    return tostring(spellId)
end

local function GetSpellTextureSafe(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local t = C_Spell.GetSpellTexture(spellId)
        if t then return t end
    end
    return 134400
end

local function BuildMismatchEntries(expected, observed)
    local entries = {}

    for spellId, expectedCount in pairs(expected) do
        local observedCount = observed[spellId] or 0
        local delta = observedCount - expectedCount
        if delta ~= 0 then
            table.insert(entries, {
                spellId = spellId,
                delta = delta,
            })
        end
    end

    for spellId, observedCount in pairs(observed) do
        if not expected[spellId] then
            table.insert(entries, {
                spellId = spellId,
                delta = observedCount,
            })
        end
    end

    table.sort(entries, function(a, b)
        local am = a.delta < 0 and 0 or 1
        local bm = b.delta < 0 and 0 or 1
        if am ~= bm then
            return am < bm
        end
        return a.spellId < b.spellId
    end)

    return entries
end

local function EnsureMismatchWidgets()
    if not ui.main or ui.mismatchContainer then
        return
    end

    local container = CreateFrame("Frame", nil, ui.main)
    container:SetSize(400, 110)
    container:SetPoint("TOPLEFT", 20, -305)
    ui.mismatchContainer = container

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Aura differences")
    ui.mismatchTitle = title

    local row = CreateFrame("Frame", nil, container)
    row:SetSize(380, 56)
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -20)
    ui.mismatchRow = row

    ui.mismatchWidgets = {}

    local maxIcons = 7
    local cellWidth = 44
    local gap = 10

    for i = 1, maxIcons do
        local cell = CreateFrame("Frame", nil, row)
        cell:SetSize(cellWidth, 56)

        if i == 1 then
            cell:SetPoint("LEFT", row, "LEFT", 0, 0)
        else
            cell:SetPoint("LEFT", ui.mismatchWidgets[i - 1], "RIGHT", gap, 0)
        end

        local icon = cell:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("TOP", 0, 0)

        local count = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        count:SetWidth(cellWidth)
        count:SetPoint("TOP", icon, "BOTTOM", 0, -4)
        count:SetJustifyH("CENTER")
        count:SetText("")

        cell.icon = icon
        cell.count = count
        cell.spellId = nil
        cell:Hide()

        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            if self.spellId then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetSpellByID(self.spellId)
                GameTooltip:Show()
            end
        end)
        cell:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        ui.mismatchWidgets[i] = cell
    end
end

local function RenderMismatchEntries(entries)
    EnsureMismatchWidgets()
    if not ui.mismatchWidgets then
        return
    end

    for i, cell in ipairs(ui.mismatchWidgets) do
        local entry = entries and entries[i] or nil

        if entry then
            cell.spellId = entry.spellId
            cell.icon:SetTexture(GetSpellTextureSafe(entry.spellId))

            if entry.delta > 0 then
                cell.count:SetText(string.format("+%d", entry.delta))
                cell.count:SetTextColor(1, 0.25, 0.25, 1)
            else
                cell.count:SetText(tostring(entry.delta))
                cell.count:SetTextColor(0.25, 1, 0.25, 1)
            end

            cell:Show()
        else
            cell.spellId = nil
            cell:Hide()
        end
    end
end

local function SetStatus(status, text, entries)
    if state.status == status and state.mismatchText == text then
        local entriesChanged = false
        if entries and state.lastEntries then
            if #entries ~= #state.lastEntries then
                entriesChanged = true
            else
                for i = 1, #entries do
                    if entries[i].spellId ~= state.lastEntries[i].spellId or entries[i].delta ~= state.lastEntries[i].delta then
                        entriesChanged = true
                        break
                    end
                end
            end
        elseif (entries and not state.lastEntries) or (not entries and state.lastEntries) then
            entriesChanged = true
        end

        if not entriesChanged then
            return
        end
    end

    state.status = status
    state.mismatchText = text or ""
    state.lastEntries = entries

    if ui.light and ui.light.texture then
        if status == "GREEN" then
            ui.light.texture:SetColorTexture(0, 0.85, 0, 1)
        elseif status == "RED" then
            ui.light.texture:SetColorTexture(0.85, 0, 0, 1)
        else
            ui.light.texture:SetColorTexture(0.85, 0.75, 0, 1)
        end
    end

    if ui.statusText then
        ui.statusText:SetText(text or "")
    end

    RenderMismatchEntries(entries or {})
end

local function BroadcastMeasure(measure)
    if not IsInGroup() then
        return
    end

    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "MEASURE:" .. tostring(measure or 0), channel)
end

local function SendPing()
    if not IsInGroup() then
        return
    end
    
    state.activePlayers = {}
    state.lastPingTime = GetTime()
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PING", channel)
    Print("Sent version check to group...")
end

local function SendPong()
    if not IsInGroup() then
        return
    end
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PONG:" .. VERSION, channel)
end

local function SetMeasure(measure, silent)
    if measure and (measure < 1 or measure > MAX_MEASURES) then
        Print("Measure must be between 1 and 25.")
        return
    end

    state.currentMeasure = measure

    if ui.measureLabel then
        ui.measureLabel:SetText(measure and ("Measure " .. measure) or "No measure")
    end

    if ui.gridButtons then
        for i, btn in ipairs(ui.gridButtons) do
            local fs = btn:GetFontString()
            if fs then
                if i == measure then
                    fs:SetTextColor(0, 1, 0, 1)
                else
                    fs:SetTextColor(1, 0.82, 0, 1)
                end
            end
        end
    end

    if not silent then
        BroadcastMeasure(measure)
    end
end

local function PressPlayerEmote()
    local slot = GetRaidSlotForPlayer()
    if not slot or not state.currentMeasure then
        UpdatePlayerPanel()
        slot = GetRaidSlotForPlayer()
        if not slot or not state.currentMeasure then
            return
        end
    end

    local token = GetMeasureEmote(state.currentMeasure, slot)
    local emote = EMOTES[token]
    if emote and emote.command then
        DoEmote(emote.command)
    end
end

local function PressBow()
    DoEmote("BOW")
end

local function UpdatePlayerPanel()
    if not ui.playerFrame then
        return
    end

    local isTargeted = IsTargetNpc("target")

    if not isTargeted then
        if ui.playerFrame:IsShown() then
            ui.playerFrame:Hide()
        end
        return
    end

    if not ui.playerFrame:IsShown() then
        ui.playerFrame:Show()
    end

    local slot = GetRaidSlotForPlayer()
    local token = "PLACEHOLDER"

    if slot and state.currentMeasure then
        token = GetMeasureEmote(state.currentMeasure, slot)
    end

    local emote = EMOTES[token] or EMOTES.PLACEHOLDER
    local enabled = state.currentMeasure and slot and token ~= "PLACEHOLDER" and emote.command

    if ui.playerMeasureText then
        ui.playerMeasureText:SetText(state.currentMeasure and ("Measure " .. state.currentMeasure) or "Waiting for measure")
    end

    if ui.playerSlotText then
        ui.playerSlotText:SetText(slot and ("Raid slot " .. slot) or "No raid slot")
    end

    if ui.playerButton then
        if not state.currentMeasure then
            ui.playerButton:SetText("No measure")
        elseif not slot then
            ui.playerButton:SetText("No raid slot")
        elseif token == "PLACEHOLDER" then
            ui.playerButton:SetText("Placeholder")
        else
            ui.playerButton:SetText(emote.display)
        end

        ui.playerButton:SetEnabled(enabled and true or false)
        ui.playerButton:SetAlpha(enabled and 1 or 0.6)
        ui.playerButton:Show()
    end

    ui.playerFrame:Show()
end

local function ValidateTarget()
    if not ui.main or not ui.main:IsShown() then
        return
    end

    -- Update addon check status if pending
    if state.lastPingTime > 0 then
        local now = GetTime()
        local elapsed = now - state.lastPingTime
        if elapsed < 5 then
            ui.addonStatusText:SetText(string.format("Checking addon... (%.1fs)", 5 - elapsed))
        else
            local missing = {}
            local versions = {}
            local numMembers = GetNumGroupMembers()
            local groupMembers = {}
            
            if IsInRaid() then
                for i = 1, MAX_RAID_MEMBERS do
                    local name = GetRaidRosterInfo(i)
                    if name then
                        table.insert(groupMembers, Ambiguate(name, "none"))
                    end
                end
            elseif IsInGroup() then
                for i = 1, numMembers do
                    local unit = (i == numMembers) and "player" or ("party" .. i)
                    local name = UnitFullName(unit)
                    if name then
                        table.insert(groupMembers, Ambiguate(name, "none"))
                    end
                end
            end

            for _, name in ipairs(groupMembers) do
                local v = state.activePlayers[name]
                if not v then
                    table.insert(missing, name)
                else
                    versions[v] = versions[v] or {}
                    table.insert(versions[v], name)
                end
            end
            
            local statusLines = {}
            if #missing > 0 then
                table.sort(missing)
                table.insert(statusLines, "|cffff0000Missing:|r " .. table.concat(missing, ", "))
            end

            local sortedVersions = {}
            for v in pairs(versions) do table.insert(sortedVersions, v) end
            table.sort(sortedVersions, function(a, b) return a > b end)

            for _, v in ipairs(sortedVersions) do
                local names = versions[v]
                table.sort(names)
                local color = (v == VERSION) and "|cff00ff00" or "|cffffff00"
                table.insert(statusLines, color .. "v" .. v .. ":|r " .. table.concat(names, ", "))
            end
            
            if #statusLines == 0 then
                ui.addonStatusText:SetText("|cffff0000No members detected.|r")
            else
                ui.addonStatusText:SetText(table.concat(statusLines, " | "))
            end
        end
    end

    if not state.currentMeasure then
        SetStatus("YELLOW", "No measure selected", {})
        return
    end

    if not IsTargetNpc("target") then
        SetStatus("YELLOW", "Target the Divine Flame of Beledar", {})
        return
    end

    local expected = BuildExpectedCounts(state.currentMeasure)
    if next(expected) == nil then
        SetStatus("YELLOW", "Selected measure only contains placeholders", {})
        return
    end

    local observed, anyAura = BuildObservedCounts()
    if not anyAura then
        SetStatus("RED", "No helpful auras on target", BuildMismatchEntries(expected, observed))
        return
    end

    if CountsEqual(expected, observed) then
        SetStatus("GREEN", "Ready to bow", {})
    else
        SetStatus("RED", "Aura mismatch", BuildMismatchEntries(expected, observed))
    end
end

local function MakeMovable(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local function CreateBackdropFrame(name, parent, width, height)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    return f
end

local function CreateLeaderUI()
    local main = CreateBackdropFrame("BeledarOrchestraMainFrame", UIParent, 440, 480)
    main:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
    main:SetFrameStrata("MEDIUM")
    main:SetClampedToScreen(true)
    main:Hide()
    MakeMovable(main)
    ui.main = main

    local title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText("Beledar Orchestra")

    local measureLabel = main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    measureLabel:SetPoint("TOPLEFT", 14, -42)
    measureLabel:SetText("No measure")
    ui.measureLabel = measureLabel

    local light = CreateFrame("Frame", nil, main)
	light:SetSize(36, 36)
	light:SetPoint("TOPRIGHT", -22, -22)
	light.texture = light:CreateTexture(nil, "BACKGROUND")
	light.texture:SetAllPoints()
	light.texture:SetColorTexture(0.85, 0.75, 0, 1)
	ui.light = light

    local statusText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("TOPRIGHT", -16, -66)
	statusText:SetWidth(120)
	statusText:SetJustifyH("CENTER")
	statusText:SetText("No measure selected")
	ui.statusText = statusText

    ui.gridButtons = {}

    local startX, startY = 16, -78
    local btnW, btnH, gap = 54, 36, 8
    local index = 1

    for row = 1, 5 do
        for col = 1, 5 do
            local measureIndex = index

            local btn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetPoint("TOPLEFT", startX + (col - 1) * (btnW + gap), startY - (row - 1) * (btnH + gap))
            btn:SetText(measureIndex)

            btn:SetScript("OnClick", function()
                if not IsLeaderOrAssist() then
                    Print("Only raid leader or assist should change measures.")
                    return
                end
                SetMeasure(measureIndex)
                UpdatePlayerPanel()
                ValidateTarget()
            end)

            ui.gridButtons[measureIndex] = btn
            index = index + 1
        end
    end

    local bowButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    bowButton:SetSize(120, 36)
    bowButton:SetPoint("BOTTOMLEFT", 16, 12)
    bowButton:SetText("Bow")
    bowButton:SetScript("OnClick", PressBow)
    ui.bowButton = bowButton

    local checkButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    checkButton:SetSize(120, 36)
    checkButton:SetPoint("LEFT", bowButton, "RIGHT", 10, 0)
    checkButton:SetText("Check Versions")
    checkButton:SetScript("OnClick", function()
        if not IsInGroup() then
            Print("You are not in a group.")
            return
        end
        SendPing()
    end)
    ui.checkButton = checkButton

    local addonStatusText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addonStatusText:SetPoint("BOTTOMLEFT", 16, 52)
    addonStatusText:SetWidth(400)
    addonStatusText:SetJustifyH("LEFT")
    addonStatusText:SetText("")
    ui.addonStatusText = addonStatusText

    local closeButton = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)

    EnsureMismatchWidgets()
end

local function CreatePlayerUI()
    local playerFrame = CreateBackdropFrame("BeledarOrchestraPlayerFrame", UIParent, 260, 155)
    playerFrame:SetPoint("CENTER", UIParent, "CENTER", 360, -120)
    playerFrame:SetFrameStrata("MEDIUM")
    playerFrame:SetClampedToScreen(true)
    playerFrame:EnableMouse(true)
    playerFrame:Show()
    MakeMovable(playerFrame)
    ui.playerFrame = playerFrame

    local title = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Beledar Assignment")

    local measureText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    measureText:SetPoint("TOP", title, "BOTTOM", 0, -10)
    measureText:SetText("Waiting for measure")
    ui.playerMeasureText = measureText

    local slotText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slotText:SetPoint("TOP", measureText, "BOTTOM", 0, -8)
    slotText:SetText("No raid slot")
    ui.playerSlotText = slotText

    local button = CreateFrame("Button", nil, playerFrame, "UIPanelButtonTemplate")
    button:SetSize(180, 44)
    button:SetPoint("BOTTOM", 0, 14)
    button:SetScript("OnClick", PressPlayerEmote)
    button:SetText("No measure")
    button:Show()
    ui.playerButton = button

    local closeButton = CreateFrame("Button", nil, playerFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)

    UpdatePlayerPanel()
end

SLASH_BELEDARORCHESTRA1 = "/bo"
SlashCmdList.BELEDARORCHESTRA = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        if ui.main:IsShown() then
            ui.main:Hide()
        else
            ui.main:Show()
        end
        return
    elseif cmd == "show" then
        ui.main:Show()
        return
    elseif cmd == "hide" then
        ui.main:Hide()
        return
    elseif cmd == "player" then
        if ui.playerFrame:IsShown() then
            ui.playerFrame:Hide()
        else
            ui.playerFrame:Show()
        end
        return
    elseif cmd == "playershow" then
        ui.playerFrame:Show()
        return
    elseif cmd == "playerhide" then
        ui.playerFrame:Hide()
        return
    elseif cmd == "measure" then
        local n = tonumber(rest)
        if not n then
            Print("Usage: /bo measure <1-25>")
            return
        end
        SetMeasure(n)
        UpdatePlayerPanel()
        ValidateTarget()
        return
    elseif cmd == "reset" then
        SetMeasure(nil)
        UpdatePlayerPanel()
        ValidateTarget()
        return
    elseif cmd == "debug" then
        local observed, anyAura = BuildObservedCounts()
        if not anyAura then
            Print("No helpful auras on target")
            return
        end
        for spellId, count in pairs(observed) do
            Print(GetSpellNameSafe(spellId) .. " x" .. tostring(count) .. " (" .. tostring(spellId) .. ")")
        end
        return
    elseif cmd == "slot" then
        local slot = GetRaidSlotForPlayer()
        Print("Computed slot: " .. tostring(slot or "nil"))
        return
    end

    Print("Commands: /bo, /bo show, /bo hide, /bo player, /bo playershow, /bo playerhide, /bo measure <1-25>, /bo reset, /bo debug, /bo slot")
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then
            return
        end

        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        CreateLeaderUI()
        CreatePlayerUI()
        SetMeasure(nil, true)
        UpdatePlayerPanel()
        SetStatus("YELLOW", "No measure selected", {})

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix ~= PREFIX then
            return
        end

        local action, value = strsplit(":", message)
        if action == "MEASURE" then
            local n = tonumber(value)
            if n == 0 then
                n = nil
            end
            SetMeasure(n, true)
            UpdatePlayerPanel()
            ValidateTarget()
        elseif action == "PING" then
            SendPong()
        elseif action == "PONG" then
            local name = Ambiguate(sender, "none")
            state.activePlayers[name] = value or "Unknown"
        end

    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TARGET_CHANGED" then
        if event == "GROUP_ROSTER_UPDATE" then
            -- Optional: Reset check when roster changes
            -- state.lastPingTime = 0
            -- ui.addonStatusText:SetText("")
        end
        UpdatePlayerPanel()
        ValidateTarget()

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "target" then
            ValidateTarget()
        end
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    if not ((ui.main and ui.main:IsShown()) or (ui.playerFrame and ui.playerFrame:IsShown())) then
        return
    end

    state.lastUpdate = state.lastUpdate + elapsed
    if state.lastUpdate >= UPDATE_INTERVAL then
        state.lastUpdate = 0
        if ui.playerFrame and ui.playerFrame:IsShown() then
            UpdatePlayerPanel()
        end
        if ui.main and ui.main:IsShown() then
            ValidateTarget()
        end
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_AURA")