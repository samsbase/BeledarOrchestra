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
    CONGRATS = { command = "CONGRATULATE", display = "/congrats", spellId = 1266755 },
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


local state = {
    currentMeasure = nil,
    status = "YELLOW",
    mismatchText = "No measure selected",
    lastUpdate = 0,
    activePlayers = {},
    lastPingTime = 0,
    performedEmotes = {},
    danceMoving = {},    -- slot -> true if started moving after dance
    danceComplete = {},  -- slot -> true if stopped moving after dance
    measureLocked = false, -- true once any player has performed their emote
}

local frame = CreateFrame("Frame")
local ui = {}

-- Forward declarations for local functions to prevent "nil global" errors
local Print, GetNpcID, IsTargetNpc, IsLeaderOrAssist, HasAura, GetMeasureEmote, IsReady
local GetSortedRaidMembers, GetRaidSlotForPlayer, BuildExpectedCounts, BuildObservedCounts, CountsEqual
local GetSpellNameSafe, GetSpellTextureSafe, BuildMismatchEntries, OpenEmoteDropdown, UpdateAssignmentGrid
local CreateAssignmentGrid, CreateVersionGrid, EnsureMismatchWidgets, RenderMismatchEntries, SetStatus
local BroadcastMeasure, SendPing, SendPong, SetMeasure, PressPlayerEmote, PressBow
local UpdatePlayerPanel, ValidateTarget, MakeMovable, CreateBackdropFrame, CreateLeaderUI
local ShowMode, CreatePlayerUI, RetryMeasure

Print = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBeledar Orchestra:|r " .. tostring(msg))
end

GetNpcID = function(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local type, _, _, _, _, npcID = strsplit("-", guid)
    if type == "Creature" or type == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

IsTargetNpc = function(unit)
    return GetNpcID(unit) == TARGET_NPC_ID
end

IsLeaderOrAssist = function()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

HasAura = function(unit, spellId)
    if not unit or not spellId then return false end
    
    -- Use a direct loop with C_UnitAuras.GetAuraDataByIndex for stability across versions
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        if type(aura) == "table" and aura.spellId == spellId then
            return true
        end
    end
    
    return false
end

GetMeasureEmote = function(measure, slot)
    if not measure or not slot then
        return "PLACEHOLDER"
    end
    if BeledarOrchestraDB.Overrides and BeledarOrchestraDB.Overrides[measure] and BeledarOrchestraDB.Overrides[measure][slot] then
        return BeledarOrchestraDB.Overrides[measure][slot]
    end
    if not ns.MEASURES or not ns.MEASURES[measure] then
        return "PLACEHOLDER"
    end
    return ns.MEASURES[measure][slot] or "PLACEHOLDER"
end

IsReady = function(unit, slotIndex)
    if not unit then return false end
    if not UnitIsConnected(unit) then return false end
    
    -- Check for the participation aura
    if HasAura(unit, 1266536) then return true end
    
    -- Fallback: check if they have any of the emote auras
    for _, emote in pairs(EMOTES) do
        if emote.spellId and HasAura(unit, emote.spellId) then
            return true
        end
    end

    -- If we have an assigned emote for the current measure, check that specifically too
    if state.currentMeasure and slotIndex then
        local token = GetMeasureEmote(state.currentMeasure, slotIndex)
        local emote = EMOTES[token]
        if emote and emote.spellId and HasAura(unit, emote.spellId) then
            return true
        end
    end
    
    return false
end

GetSortedRaidMembers = function()
    local members = {}
    if IsInRaid() then
        for i = 1, RAID_SLOTS do
            local name, rank, subgroup = GetRaidRosterInfo(i)
            if name then
                table.insert(members, {
                    name = Ambiguate(name, "none"),
                    subgroup = subgroup or 9,
                    raidIndex = i,
                    unit = "raid" .. i,
                })
            end
        end
    elseif IsInGroup() then
        local num = GetNumGroupMembers()
        for i = 1, num do
            local unit = (i == num) and "player" or ("party" .. i)
            local name, realm = UnitFullName(unit)
            if name then
                local fullName = name
                if realm and realm ~= "" then
                    fullName = name .. "-" .. realm
                end
                table.insert(members, {
                    name = Ambiguate(fullName, "none"),
                    subgroup = 1,
                    raidIndex = i,
                    unit = unit,
                })
            end
        end
    end

    table.sort(members, function(a, b)
        if a.subgroup ~= b.subgroup then
            return a.subgroup < b.subgroup
        end
        return a.raidIndex < b.raidIndex
    end)

    return members
end

GetRaidSlotForPlayer = function()
    local members = GetSortedRaidMembers()
    for visualSlot, member in ipairs(members) do
        if member.unit and UnitIsUnit(member.unit, "player") then
            return visualSlot
        end
    end
    return nil
end

BuildExpectedCounts = function(measure)
    local expected = {}

    if not measure then
        return expected
    end

    for slot = 1, RAID_SLOTS do
        local token = GetMeasureEmote(measure, slot)
        if token and token ~= "PLACEHOLDER" then
            local emote = EMOTES[token]
            if emote and emote.spellId then
                expected[emote.spellId] = (expected[emote.spellId] or 0) + 1
            end
        end
    end

    return expected
end

BuildObservedCounts = function()
    local observed = {}
    local anyAura = false

    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
        if not aura then break end
        if type(aura) == "table" and aura.spellId then
            anyAura = true
            observed[aura.spellId] = aura.applications or 1
        end
    end

    return observed, anyAura
end

CountsEqual = function(expected, observed)
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

GetSpellNameSafe = function(spellId)
    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellId)
        if n then return n end
    end
    return tostring(spellId)
end

GetSpellTextureSafe = function(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local t = C_Spell.GetSpellTexture(spellId)
        if t then return t end
    end
    return 134400
end

BuildMismatchEntries = function(expected, observed)
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

OpenEmoteDropdown = function(anchor, measure, slotIndex)
    local tokens = {}
    for token in pairs(EMOTES) do
        table.insert(tokens, token)
    end
    table.sort(tokens)

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
            rootDescription:CreateTitle("Assign Emote for Slot " .. slotIndex)
            for _, token in ipairs(tokens) do
                local data = EMOTES[token]
                rootDescription:CreateButton(data.display or token, function()
                    if not IsLeaderOrAssist() then return end
                    BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                    BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
                    BeledarOrchestraDB.Overrides[measure][slotIndex] = token
                    
                    if IsInGroup() then
                        local channel = IsInRaid() and "RAID" or "PARTY"
                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", measure, slotIndex, token), channel)
                    end
                    
                    UpdateAssignmentGrid()
                    UpdatePlayerPanel()
                    ValidateTarget()
                end)
            end
        end)
    else
        -- Fallback for legacy clients where MenuUtil might not exist
        local menu = {
            { text = "Assign Emote for Slot " .. slotIndex, isTitle = true, notCheckable = true },
        }
        for _, token in ipairs(tokens) do
            local data = EMOTES[token]
            table.insert(menu, {
                text = data.display or token,
                func = function()
                    if not IsLeaderOrAssist() then return end
                    BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                    BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
                    BeledarOrchestraDB.Overrides[measure][slotIndex] = token
                    
                    if IsInGroup() then
                        local channel = IsInRaid() and "RAID" or "PARTY"
                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", measure, slotIndex, token), channel)
                    end
                    
                    UpdateAssignmentGrid()
                    UpdatePlayerPanel()
                    ValidateTarget()
                end,
                notCheckable = true,
            })
        end
        if not ui.dropdownFrame then
            ui.dropdownFrame = CreateFrame("Frame", "BeledarOrchestraDropdown", UIParent, "UIDropDownMenuTemplate")
        end
        if _G.EasyMenu then
            _G.EasyMenu(menu, ui.dropdownFrame, anchor, 0, 0, "MENU")
        end
    end
end

UpdateAssignmentGrid = function(members)
    if not ui.assignmentSlots or not ui.main or not ui.main:IsShown() then return end
    if not state.currentMeasure then
        for i = 1, RAID_SLOTS do ui.assignmentSlots[i]:Hide() end
        return
    end
    
    members = members or GetSortedRaidMembers()
    for i = 1, RAID_SLOTS do
        local slot = ui.assignmentSlots[i]
        local member = members[i]
        local token = GetMeasureEmote(state.currentMeasure, i)
        local emote = EMOTES[token] or EMOTES.PLACEHOLDER
        
        local isOverride = BeledarOrchestraDB.Overrides and BeledarOrchestraDB.Overrides[state.currentMeasure] and BeledarOrchestraDB.Overrides[state.currentMeasure][i]
        if isOverride then
            slot:SetBackdropBorderColor(1, 0.82, 0, 1)
            slot:SetBackdropColor(0.2, 0.15, 0, 0.8)
            if slot.overrideBorder then slot.overrideBorder:Show() end
        else
            slot:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            if slot.overrideBorder then slot.overrideBorder:Hide() end
        end

        if emote.spellId then
            slot.icon:SetTexture(GetSpellTextureSafe(emote.spellId))
        else
            slot.icon:SetTexture(134400) -- Question mark
        end
        slot.icon:Show()
        
        local playerName = member and member.name or ""
        slot.text:SetText(playerName)
        
        if member and member.unit then
            local isConnected = UnitIsConnected(member.unit)
            local isReady = IsReady(member.unit, i)
            local hasPerformed = state.performedEmotes[i]
            local isDanceSlot = (token == "DANCE")
            local danceMovingSlot = state.danceMoving[i]
            local danceCompleteSlot = state.danceComplete[i]
            
            if hasPerformed and isDanceSlot then
                if danceCompleteSlot then
                    slot.text:SetTextColor(0, 1, 0) -- Green: dance + move complete
                elseif danceMovingSlot then
                    slot.text:SetTextColor(1, 0.5, 0) -- Orange: moving
                else
                    slot.text:SetTextColor(1, 0.5, 0) -- Orange: needs to move
                end
            elseif hasPerformed then
                slot.text:SetTextColor(0, 1, 0) -- Green
            elseif state.measureLocked then
                slot.text:SetTextColor(0.5, 0.5, 0.5) -- Grey: locked
            elseif not isConnected or not isReady then
                slot.text:SetTextColor(1, 0, 0) -- Red
            else
                slot.text:SetTextColor(1, 1, 1) -- White
            end
        else
            slot.text:SetTextColor(1, 1, 1)
        end
        
        slot:Show()
    end
end

CreateAssignmentGrid = function(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(706, 126)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -470)
    ui.assignmentContainer = container

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 2)
    title:SetText("Assigned Emotes")
    ui.assignmentTitle = title

    ui.assignmentSlots = {}
    local boxW, boxH = 70, 22
    local gapW, gapH = 20, 4

    for i = 1, RAID_SLOTS do
        local slot = CreateFrame("Frame", nil, container, "BackdropTemplate")
        slot:SetSize(boxW, boxH)
        
        local col = math.floor((i - 1) / 5)
        local row = (i - 1) % 5
        slot:SetPoint("TOPLEFT", col * (boxW + gapW), -row * (boxH + gapH))
        
        local slotNum = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slotNum:SetText(i)
        slotNum:SetTextColor(0.7, 0.7, 0.7)
        slotNum:SetPoint("RIGHT", slot, "LEFT", -2, 0)
        slot.slotNum = slotNum
        
        slot:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        slot:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        local overrideBorder = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        overrideBorder:SetPoint("TOPLEFT", -2, 2)
        overrideBorder:SetPoint("BOTTOMRIGHT", 2, -2)
        overrideBorder:SetBackdrop({
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 14,
        })
        overrideBorder:SetBackdropBorderColor(1, 0.82, 0, 1)
        overrideBorder:Hide()
        slot.overrideBorder = overrideBorder

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 4, 0)
        slot.icon = icon

        local text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetText("")
        slot.text = text

        slot:EnableMouse(true)
        slot.slotIndex = i
        slot:SetScript("OnEnter", function(self)
            local measure = state.currentMeasure
            if not measure then return end
            
            local token = GetMeasureEmote(measure, self.slotIndex)
            local emote = EMOTES[token] or EMOTES.PLACEHOLDER
            local members = GetSortedRaidMembers()
            local member = members[self.slotIndex]
            
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Slot " .. self.slotIndex)
            if member then
                GameTooltip:AddLine("Player: " .. member.name, 1, 1, 1)
            end
            GameTooltip:AddLine("Emote: " .. (emote.display or token), 1, 0.82, 0)
            local isOverride = BeledarOrchestraDB.Overrides and BeledarOrchestraDB.Overrides[measure] and BeledarOrchestraDB.Overrides[measure][self.slotIndex]
            if isOverride then
                GameTooltip:AddLine("(Modified by leader)", 1, 0.5, 0)
            end
            if IsLeaderOrAssist() then
                GameTooltip:AddLine("|cff00ff00Click to change|r")
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:SetScript("OnMouseDown", function(self)
            if state.currentMeasure and IsLeaderOrAssist() then
                OpenEmoteDropdown(self, state.currentMeasure, self.slotIndex)
            end
        end)

        ui.assignmentSlots[i] = slot
        slot:Hide()
    end
end

CreateVersionGrid = function(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(706, 126)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -470)
    ui.versionContainer = container

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 2)
    title:SetText("Addon Versions")
    ui.versionTitle = title

    ui.versionSlots = {}
    local boxW, boxH = 70, 22
    local gapW, gapH = 20, 4

    for i = 1, RAID_SLOTS do
        local slot = CreateFrame("Frame", nil, container, "BackdropTemplate")
        slot:SetSize(boxW, boxH)
        
        local col = math.floor((i - 1) / 5)
        local row = (i - 1) % 5
        slot:SetPoint("TOPLEFT", col * (boxW + gapW), -row * (boxH + gapH))

        local slotNum = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slotNum:SetText(i)
        slotNum:SetTextColor(0.7, 0.7, 0.7)
        slotNum:SetPoint("RIGHT", slot, "LEFT", -2, 0)
        slot.slotNum = slotNum
        
        slot:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        slot:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        local text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", 0, 0)
        text:SetText("-")
        slot.text = text

        slot:EnableMouse(true)
        slot:SetScript("OnEnter", function(self)
            if self.playerName then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.playerName)
                GameTooltip:AddLine("Version: " .. (self.version or "|cffff0000Missing|r"), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

        ui.versionSlots[i] = slot
        slot:Hide()
    end
end

EnsureMismatchWidgets = function()
    if not ui.main or ui.mismatchContainer then
        return
    end

    local container = CreateFrame("Frame", nil, ui.main)
    container:SetSize(400, 110)
    container:SetPoint("TOPLEFT", 180, -305)
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

RenderMismatchEntries = function(entries)
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

SetStatus = function(status, text, entries)
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

BroadcastMeasure = function(measure)
    if not IsInGroup() then
        return
    end

    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "MEASURE:" .. tostring(measure or 0), channel)
end

SendPing = function()
    if not IsInGroup() then
        return
    end
    
    state.activePlayers = {}
    state.lastPingTime = GetTime()
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PING", channel)
    Print("Sent version check to group...")
end

SendPong = function()
    if not IsInGroup() then
        return
    end
    
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PONG:" .. VERSION, channel)
end

SetMeasure = function(measure, silent)
    if measure and (measure < 1 or measure > MAX_MEASURES) then
        Print("Measure must be between 1 and 25.")
        return
    end

    state.currentMeasure = measure
    state.performedEmotes = {}
    state.danceMoving = {}
    state.danceComplete = {}
    state.measureLocked = false

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

    UpdateAssignmentGrid()

    if not silent then
        BroadcastMeasure(measure)
    end
end

PressPlayerEmote = function()
    local slot = GetRaidSlotForPlayer()
    local measure = state.currentMeasure

    if not slot or not measure then
        UpdatePlayerPanel()
        slot = GetRaidSlotForPlayer()
        measure = state.currentMeasure
    end

    if not slot then
        Print("Cannot emote: no raid slot found.")
        return
    end
    if not measure then
        Print("Cannot emote: no measure selected.")
        return
    end

    if state.measureLocked then
        Print("Measure already performed. Wait for a new measure or leader retry.")
        return
    end

    local token = GetMeasureEmote(measure, slot)
    if not token or token == "PLACEHOLDER" then
        Print("Cannot emote: slot " .. slot .. " has no assignment for measure " .. measure .. ".")
        return
    end

    local emote = EMOTES[token]
    if not emote or not emote.command then
        Print("Cannot emote: unknown emote token '" .. tostring(token) .. "'.")
        return
    end

    DoEmote(emote.command)
    state.measureLocked = true

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(PREFIX, string.format("PERFORMED:%d:%d", measure, slot), channel)
    end

    -- If the emote is DANCE, register movement events
    if token == "DANCE" then
        frame:RegisterEvent("PLAYER_STARTED_MOVING")
        frame:RegisterEvent("PLAYER_STOPPED_MOVING")
    end

    UpdatePlayerPanel()
end

RetryMeasure = function()
    if not state.currentMeasure then
        Print("No measure selected.")
        return
    end
    state.performedEmotes = {}
    state.danceMoving = {}
    state.danceComplete = {}
    state.measureLocked = false

    if IsInGroup() and IsLeaderOrAssist() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(PREFIX, "RETRY:" .. tostring(state.currentMeasure), channel)
    end

    UpdateAssignmentGrid()
    UpdatePlayerPanel()
    ValidateTarget()
end

PressBow = function()
    DoEmote("BOW")
end

UpdatePlayerPanel = function()
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

    if ui.playerModifiedText then
        local isModified = false
        if slot and state.currentMeasure and BeledarOrchestraDB.Overrides and BeledarOrchestraDB.Overrides[state.currentMeasure] and BeledarOrchestraDB.Overrides[state.currentMeasure][slot] then
            isModified = true
        end
        ui.playerModifiedText:SetShown(isModified)
    end

    if ui.playerButton then
        local mySlot = slot
        local myToken = token
        local isDance = myToken == "DANCE"
        local danceNeedsMove = isDance and state.measureLocked and not state.danceMoving[mySlot]
        local danceNeedsStop = isDance and state.measureLocked and state.danceMoving[mySlot] and not state.danceComplete[mySlot]
        local danceFinished = isDance and state.measureLocked and state.danceComplete[mySlot]

        if state.measureLocked then
            if danceNeedsMove then
                ui.playerButton:SetText("Move!")
                ui.playerButton:SetEnabled(false)
                ui.playerButton:SetAlpha(0.8)
            elseif danceNeedsStop then
                ui.playerButton:SetText("Stop Moving!")
                ui.playerButton:SetEnabled(false)
                ui.playerButton:SetAlpha(0.8)
            elseif danceFinished then
                ui.playerButton:SetText("Done!")
                ui.playerButton:SetEnabled(false)
                ui.playerButton:SetAlpha(0.5)
            else
                ui.playerButton:SetText("Done!")
                ui.playerButton:SetEnabled(false)
                ui.playerButton:SetAlpha(0.5)
            end
        elseif not state.currentMeasure then
            ui.playerButton:SetText("No measure")
            ui.playerButton:SetEnabled(false)
            ui.playerButton:SetAlpha(0.6)
        elseif not slot then
            ui.playerButton:SetText("No raid slot")
            ui.playerButton:SetEnabled(false)
            ui.playerButton:SetAlpha(0.6)
        elseif token == "PLACEHOLDER" then
            ui.playerButton:SetText("Placeholder")
            ui.playerButton:SetEnabled(false)
            ui.playerButton:SetAlpha(0.6)
        else
            ui.playerButton:SetText(emote.display)
            ui.playerButton:SetEnabled(true)
            ui.playerButton:SetAlpha(1)
        end
        ui.playerButton:Show()
    end

    ui.playerFrame:Show()
end

ValidateTarget = function()
    if not ui.main or not ui.main:IsShown() then
        return
    end

    local members = GetSortedRaidMembers()

    -- Update addon check status if pending
    if state.lastPingTime > 0 then
        local now = GetTime()
        local elapsed = now - state.lastPingTime
        
        if elapsed < 5 then
            ui.addonStatusText:SetText(string.format("Checking addon... (%.1fs)", 5 - elapsed))
        else
            ui.addonStatusText:SetText("Check complete.")
        end

        if ui.versionSlots then
            for i = 1, RAID_SLOTS do
                local slot = ui.versionSlots[i]
                local member = members[i]
                if slot then
                    if member then
                        slot.playerName = member.name
                        local v = state.activePlayers[member.name]
                        slot.version = v
                        
                        if not v then
                            slot.text:SetText("?")
                            slot:SetBackdropColor(0.5, 0, 0, 0.8)
                        elseif v == VERSION then
                            slot.text:SetText(v)
                            slot:SetBackdropColor(0, 0.5, 0, 0.8)
                        else
                            slot.text:SetText(v)
                            slot:SetBackdropColor(0.5, 0.5, 0, 0.8)
                        end
                        slot:Show()
                    else
                        slot.playerName = nil
                        slot:Hide()
                    end
                end
            end
        end
    end

    UpdateAssignmentGrid(members)

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

MakeMovable = function(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

CreateBackdropFrame = function(name, parent, width, height)
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

StaticPopupDialogs["BELEDAR_SAVE_SET"] = {
    text = "Enter name for the assignment set:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 32,
    OnAccept = function(self)
        local editBox = self.editBox or self.EditBox
        local name = editBox:GetText()
        if name and name ~= "" then
            local m = state.currentMeasure
            if not m then
                Print("No measure selected. Cannot save set.")
                return
            end
            BeledarOrchestraDB.SavedSets = BeledarOrchestraDB.SavedSets or {}
            BeledarOrchestraDB.SavedSets[m] = BeledarOrchestraDB.SavedSets[m] or {}
            
            local copy = {}
            if BeledarOrchestraDB.Overrides and BeledarOrchestraDB.Overrides[m] then
                for s, token in pairs(BeledarOrchestraDB.Overrides[m]) do
                    copy[s] = token
                end
            end
            BeledarOrchestraDB.SavedSets[m][name] = copy
            Print("Saved assignments for measure " .. m .. " as '" .. name .. "'")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["BELEDAR_SAVE_SET"].OnAccept(parent)
        parent:Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["BELEDAR_DELETE_SET"] = {
    text = "Delete assignment set '%s' for measure %d?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data.measure and data.name then
            if BeledarOrchestraDB.SavedSets and BeledarOrchestraDB.SavedSets[data.measure] then
                BeledarOrchestraDB.SavedSets[data.measure][data.name] = nil
                Print("Deleted set '" .. data.name .. "' for measure " .. data.measure)
            end
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

CreateLeaderUI = function()
    local main = CreateBackdropFrame("BeledarOrchestraMainFrame", UIParent, 760, 750)
    main:SetPoint("CENTER", UIParent, "CENTER", -380, 0)
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
	statusText:ClearAllPoints()
	statusText:SetPoint("RIGHT", light, "LEFT", -8, 0)
	statusText:SetWidth(260)
	statusText:SetJustifyH("RIGHT")
	statusText:SetText("No measure selected")
	ui.statusText = statusText

    ui.gridButtons = {}

    local startX, startY = 173, -78
    local btnW, btnH, gap = 78, 36, 6
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
    bowButton:SetPoint("BOTTOMLEFT", 220, 15)
    bowButton:SetText("Bow")
    bowButton:SetScript("OnClick", PressBow)
    ui.bowButton = bowButton

    local retryButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    retryButton:SetSize(120, 36)
    retryButton:SetPoint("LEFT", bowButton, "RIGHT", 10, 0)
    retryButton:SetText("Retry")
    retryButton:SetScript("OnClick", function()
        if not IsLeaderOrAssist() then
            Print("Only raid leader or assist can retry.")
            return
        end
        RetryMeasure()
    end)
    ui.retryButton = retryButton

    local addonStatusText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addonStatusText:SetPoint("BOTTOMLEFT", 20, 52)
    addonStatusText:SetWidth(720)
    addonStatusText:SetJustifyH("CENTER")
    addonStatusText:SetText("")
    ui.addonStatusText = addonStatusText

    CreateAssignmentGrid(main)
    CreateVersionGrid(main)

    ShowMode = function(mode)
        if mode == "VERSION" then
            ui.assignmentContainer:Hide()
            ui.versionContainer:Show()
            ui.btnAssign:SetEnabled(true)
            ui.btnVersion:SetEnabled(false)
            if ui.checkButton then ui.checkButton:Show() end
        else
            ui.assignmentContainer:Show()
            ui.versionContainer:Hide()
            ui.btnAssign:SetEnabled(false)
            ui.btnVersion:SetEnabled(true)
            if ui.checkButton then ui.checkButton:Hide() end
            UpdateAssignmentGrid()
        end
    end

    local btnAssign = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnAssign:SetSize(100, 22)
    btnAssign:SetPoint("TOPLEFT", 278, -425)
    btnAssign:SetText("Assignments")
    btnAssign:SetScript("OnClick", function() ShowMode("ASSIGN") end)
    ui.btnAssign = btnAssign

    local btnVersion = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnVersion:SetSize(100, 22)
    btnVersion:SetPoint("LEFT", btnAssign, "RIGHT", 4, 0)
    btnVersion:SetText("Versions")
    btnVersion:SetScript("OnClick", function() ShowMode("VERSION") end)
    ui.btnVersion = btnVersion

    local checkButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    checkButton:SetSize(120, 22)
    checkButton:SetPoint("LEFT", btnVersion, "RIGHT", 10, 0)
    checkButton:SetText("Check Versions")
    checkButton:SetScript("OnClick", function()
        if not IsInGroup() then
            Print("You are not in a group.")
            return
        end
        SendPing()
    end)
    checkButton:Hide()  -- Hidden initially since we start in ASSIGN mode
    ui.checkButton = checkButton

    ShowMode("ASSIGN")

    local btnSave = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnSave:SetSize(80, 22)
    btnSave:SetPoint("BOTTOMLEFT", 256, 75)
    btnSave:SetText("Save")
    btnSave:SetScript("OnClick", function()
        StaticPopup_Show("BELEDAR_SAVE_SET")
    end)

    local btnLoad = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnLoad:SetSize(80, 22)
    btnLoad:SetPoint("LEFT", btnSave, "RIGHT", 4, 0)
    btnLoad:SetText("Load")
    btnLoad:SetScript("OnClick", function(self)
        local m = state.currentMeasure
        if not m then
            Print("Select a measure first to load sets for it.")
            return
        end
        
        local measureSets = BeledarOrchestraDB.SavedSets and BeledarOrchestraDB.SavedSets[m] or {}
        local names = {}
        for name in pairs(measureSets) do
            table.insert(names, name)
        end
        table.sort(names)

        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Load Set for Measure " .. m)
                
                if #names == 0 then
                    rootDescription:CreateButton("No sets saved", function() end):SetEnabled(false)
                    return
                end
                
                for _, name in ipairs(names) do
                    local node = rootDescription:CreateButton(name, function()
                        local set = measureSets[name]
                        if set then
                            BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                            BeledarOrchestraDB.Overrides[m] = {}
                            for s, token in pairs(set) do
                                BeledarOrchestraDB.Overrides[m][s] = token
                            end
                            Print("Loaded assignments for measure " .. m .. " from '" .. name .. "'")
                            
                            if IsInGroup() and IsLeaderOrAssist() then
                                local channel = IsInRaid() and "RAID" or "PARTY"
                                C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_MEASURE:" .. m, channel)
                                for slot, token in pairs(set) do
                                    C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", m, slot, token), channel)
                                end
                            end
                            
                            UpdateAssignmentGrid()
                            UpdatePlayerPanel()
                            ValidateTarget()
                        end
                    end)
                    node:CreateButton("Delete", function()
                        StaticPopup_Show("BELEDAR_DELETE_SET", name, m, { measure = m, name = name })
                    end)
                end
            end)
        else
            -- Fallback for legacy clients
            local menu = {
                { text = "Load Set for Measure " .. m, isTitle = true, notCheckable = true },
            }
            if #names == 0 then
                table.insert(menu, { text = "No sets saved", notCheckable = true, disabled = true })
            else
                for _, name in ipairs(names) do
                    table.insert(menu, {
                        text = name,
                        func = function()
                            local set = measureSets[name]
                            if set then
                                BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                                BeledarOrchestraDB.Overrides[m] = {}
                                for s, token in pairs(set) do
                                    BeledarOrchestraDB.Overrides[m][s] = token
                                end
                                Print("Loaded assignments for measure " .. m .. " from '" .. name .. "'")
                                
                                if IsInGroup() and IsLeaderOrAssist() then
                                    local channel = IsInRaid() and "RAID" or "PARTY"
                                    C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_MEASURE:" .. m, channel)
                                    for slot, token in pairs(set) do
                                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", m, slot, token), channel)
                                    end
                                end
                                
                                UpdateAssignmentGrid()
                                UpdatePlayerPanel()
                                ValidateTarget()
                            end
                        end,
                        notCheckable = true,
                        hasArrow = true,
                        menuList = {
                            {
                                text = "Delete",
                                func = function()
                                    StaticPopup_Show("BELEDAR_DELETE_SET", name, m, { measure = m, name = name })
                                end,
                                notCheckable = true,
                            }
                        }
                    })
                end
            end
            if not ui.dropdownFrame then
                ui.dropdownFrame = CreateFrame("Frame", "BeledarOrchestraDropdown", UIParent, "UIDropDownMenuTemplate")
            end
            if _G.EasyMenu then
                _G.EasyMenu(menu, ui.dropdownFrame, self, 0, 0, "MENU")
            end
        end
    end)

    local btnClear = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnClear:SetSize(140, 22)
    btnClear:SetPoint("LEFT", btnLoad, "RIGHT", 4, 0)
    btnClear:SetText("Clear Manual Assigns")
    btnClear:SetScript("OnClick", function()
        BeledarOrchestraDB.Overrides = {}
        Print("Cleared all manual overrides.")
        if IsInGroup() and IsLeaderOrAssist() then
            local channel = IsInRaid() and "RAID" or "PARTY"
            C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_OVERRIDES", channel)
        end
        UpdateAssignmentGrid()
        UpdatePlayerPanel()
        ValidateTarget()
    end)

    local closeButton = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)

    EnsureMismatchWidgets()
end

CreatePlayerUI = function()
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

    local modifiedText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modifiedText:SetPoint("TOP", slotText, "BOTTOM", 0, -2)
    modifiedText:SetText("|cffffff00(Modified by leader)|r")
    modifiedText:Hide()
    ui.playerModifiedText = modifiedText

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

SLASH_BELEDARORCHESTRA1 = "/conductor"
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
            Print("Usage: /conductor measure <1-25>")
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

    Print("Commands: /conductor, /conductor show, /conductor hide, /conductor player, /conductor playershow, /conductor playerhide, /conductor measure <1-25>, /conductor reset, /conductor debug, /conductor slot")
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then
            return
        end

        BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
        BeledarOrchestraDB.SavedSets = BeledarOrchestraDB.SavedSets or {}
        
        -- Migration from flat SavedSets to measure-based SavedSets
        local needsMigration = false
        for k, v in pairs(BeledarOrchestraDB.SavedSets) do
            if type(k) == "string" and type(v) == "table" then
                for mk in pairs(v) do
                    if type(mk) == "number" then
                        needsMigration = true
                        break
                    end
                end
            end
            if needsMigration then break end
        end

        if needsMigration then
            local newSets = {}
            for name, set in pairs(BeledarOrchestraDB.SavedSets) do
                if type(name) == "string" and type(set) == "table" then
                    for m, slots in pairs(set) do
                        if type(m) == "number" then
                            newSets[m] = newSets[m] or {}
                            newSets[m][name] = slots
                        end
                    end
                end
            end
            BeledarOrchestraDB.SavedSets = newSets
            Print("Migrated assignment sets to measure-based format.")
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
        elseif action == "OVERRIDE" then
            local measure, slot, token = select(2, strsplit(":", message))
            measure = tonumber(measure)
            slot = tonumber(slot)
            if measure and slot and token then
                BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
                BeledarOrchestraDB.Overrides[measure][slot] = token
                UpdateAssignmentGrid()
                UpdatePlayerPanel()
                ValidateTarget()
            end
        elseif action == "CLEAR_OVERRIDES" then
            BeledarOrchestraDB.Overrides = {}
            UpdateAssignmentGrid()
            UpdatePlayerPanel()
            ValidateTarget()
        elseif action == "CLEAR_MEASURE" then
            local m = tonumber(value)
            if m and BeledarOrchestraDB.Overrides then
                BeledarOrchestraDB.Overrides[m] = nil
                UpdateAssignmentGrid()
                UpdatePlayerPanel()
                ValidateTarget()
            end
        elseif action == "PING" then
            SendPong()
        elseif action == "PONG" then
            local name = Ambiguate(sender, "none")
            state.activePlayers[name] = value or "Unknown"
        elseif action == "PERFORMED" then
            local measure, slot = select(2, strsplit(":", message))
            measure = tonumber(measure)
            slot = tonumber(slot)
            if measure == state.currentMeasure and slot then
                state.performedEmotes[slot] = true
                state.measureLocked = true
                UpdateAssignmentGrid()
            end
        elseif action == "DANCE_MOVING" then
            local measure, slot = select(2, strsplit(":", message))
            measure = tonumber(measure)
            slot = tonumber(slot)
            if measure == state.currentMeasure and slot then
                state.danceMoving[slot] = true
                UpdateAssignmentGrid()
            end
        elseif action == "DANCE_STOPPED" then
            local measure, slot = select(2, strsplit(":", message))
            measure = tonumber(measure)
            slot = tonumber(slot)
            if measure == state.currentMeasure and slot then
                state.danceComplete[slot] = true
                UpdateAssignmentGrid()
            end
        elseif action == "RETRY" then
            local m = tonumber(value)
            if m == state.currentMeasure then
                state.performedEmotes = {}
                state.danceMoving = {}
                state.danceComplete = {}
                state.measureLocked = false
                UpdateAssignmentGrid()
                UpdatePlayerPanel()
                ValidateTarget()
            end
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

    elseif event == "PLAYER_STARTED_MOVING" then
        local slot = GetRaidSlotForPlayer()
        local measure = state.currentMeasure
        if slot and measure and state.measureLocked then
            local token = GetMeasureEmote(measure, slot)
            if token == "DANCE" and not state.danceMoving[slot] then
                state.danceMoving[slot] = true
                if IsInGroup() then
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    C_ChatInfo.SendAddonMessage(PREFIX, string.format("DANCE_MOVING:%d:%d", measure, slot), channel)
                end
                UpdatePlayerPanel()
            end
        end

    elseif event == "PLAYER_STOPPED_MOVING" then
        local slot = GetRaidSlotForPlayer()
        local measure = state.currentMeasure
        if slot and measure and state.measureLocked then
            local token = GetMeasureEmote(measure, slot)
            if token == "DANCE" and state.danceMoving[slot] and not state.danceComplete[slot] then
                state.danceComplete[slot] = true
                if IsInGroup() then
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    C_ChatInfo.SendAddonMessage(PREFIX, string.format("DANCE_STOPPED:%d:%d", measure, slot), channel)
                end
                frame:UnregisterEvent("PLAYER_STARTED_MOVING")
                frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
                UpdatePlayerPanel()
            end
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