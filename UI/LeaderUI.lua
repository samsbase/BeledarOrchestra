local _, ns = ...

local ui = ns.ui
local state = ns.state
local EMOTES = ns.EMOTES
local RAID_SLOTS = ns.RAID_SLOTS
local MAX_MEASURES = ns.MAX_MEASURES
local PREFIX = ns.PREFIX
local Print = ns.Print

-- Status / mismatch rendering
function ns.SetStatus(status, text, entries)
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
        if not entriesChanged then return end
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

    ns.RenderMismatchEntries(entries or {})
end

function ns.EnsureMismatchWidgets()
    if not ui.main or ui.mismatchContainer then return end

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
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)

        ui.mismatchWidgets[i] = cell
    end
end

function ns.RenderMismatchEntries(entries)
    ns.EnsureMismatchWidgets()
    if not ui.mismatchWidgets then return end

    for i, cell in ipairs(ui.mismatchWidgets) do
        local entry = entries and entries[i] or nil
        if entry then
            cell.spellId = entry.spellId
            cell.icon:SetTexture(ns.GetSpellTextureSafe(entry.spellId))
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

-- Emote dropdown
function ns.OpenEmoteDropdown(anchor, measure, slotIndex)
    local tokens = {}
    for token in pairs(EMOTES) do table.insert(tokens, token) end
    table.sort(tokens)

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
            rootDescription:CreateTitle("Assign Emote for Slot " .. slotIndex)
            for _, token in ipairs(tokens) do
                local data = EMOTES[token]
                rootDescription:CreateButton(data.display or token, function()
                    if not ns.IsLeaderOrAssist() then return end
                    BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                    BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
                    BeledarOrchestraDB.Overrides[measure][slotIndex] = token
                    if IsInGroup() then
                        local channel = IsInRaid() and "RAID" or "PARTY"
                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", measure, slotIndex, token), channel)
                    end
                    ns.UpdateAssignmentGrid()
                    ns.UpdatePlayerPanel()
                    ns.ValidateTarget()
                end)
            end
        end)
    else
        local menu = {
            { text = "Assign Emote for Slot " .. slotIndex, isTitle = true, notCheckable = true },
        }
        for _, token in ipairs(tokens) do
            local data = EMOTES[token]
            table.insert(menu, {
                text = data.display or token,
                func = function()
                    if not ns.IsLeaderOrAssist() then return end
                    BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
                    BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
                    BeledarOrchestraDB.Overrides[measure][slotIndex] = token
                    if IsInGroup() then
                        local channel = IsInRaid() and "RAID" or "PARTY"
                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", measure, slotIndex, token), channel)
                    end
                    ns.UpdateAssignmentGrid()
                    ns.UpdatePlayerPanel()
                    ns.ValidateTarget()
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

-- Assignment grid
function ns.UpdateAssignmentGrid(members)
    if not ui.assignmentSlots or not ui.main or not ui.main:IsShown() then return end
    if not state.currentMeasure then
        for i = 1, RAID_SLOTS do ui.assignmentSlots[i]:Hide() end
        return
    end

    members = members or ns.GetSortedRaidMembers()
    for i = 1, RAID_SLOTS do
        local slot = ui.assignmentSlots[i]
        local member = members[i]
        local token = ns.GetMeasureEmote(state.currentMeasure, i)
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
            slot.icon:SetTexture(ns.GetSpellTextureSafe(emote.spellId))
        else
            slot.icon:SetTexture(134400)
        end
        slot.icon:Show()

        local playerName = member and member.name or ""
        slot.text:SetText(playerName)

        if member and member.unit then
            local isConnected = UnitIsConnected(member.unit)
            local isReady = ns.IsReady(member.unit, i)
            local hasPerformed = state.performedEmotes[i]
            local isDanceSlot = (token == "DANCE")
            local danceMovingSlot = state.danceMoving[i]
            local danceCompleteSlot = state.danceComplete[i]

            if hasPerformed and isDanceSlot then
                if danceCompleteSlot then
                    slot.text:SetTextColor(0, 1, 0)
                elseif danceMovingSlot then
                    slot.text:SetTextColor(1, 0.5, 0)
                else
                    slot.text:SetTextColor(1, 0.5, 0)
                end
            elseif hasPerformed then
                slot.text:SetTextColor(0, 1, 0)
            elseif state.measureLocked then
                slot.text:SetTextColor(0.5, 0.5, 0.5)
            elseif not isConnected or not isReady then
                slot.text:SetTextColor(1, 0, 0)
            else
                slot.text:SetTextColor(1, 1, 1)
            end
        else
            slot.text:SetTextColor(1, 1, 1)
        end

        slot:Show()
    end
end

local function CreateAssignmentGrid(parent)
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
            local token = ns.GetMeasureEmote(measure, self.slotIndex)
            local emote = EMOTES[token] or EMOTES.PLACEHOLDER
            local members = ns.GetSortedRaidMembers()
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
            if ns.IsLeaderOrAssist() then
                GameTooltip:AddLine("|cff00ff00Click to change|r")
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:SetScript("OnMouseDown", function(self)
            if state.currentMeasure and ns.IsLeaderOrAssist() then
                ns.OpenEmoteDropdown(self, state.currentMeasure, self.slotIndex)
            end
        end)

        ui.assignmentSlots[i] = slot
        slot:Hide()
    end
end

-- Version grid
local function CreateVersionGrid(parent)
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

-- Measure set/retry
function ns.SetMeasure(measure, silent)
    if measure and (measure < 1 or measure > MAX_MEASURES) then
        Print("Measure must be between 1 and 25.")
        return
    end

    state.currentMeasure = measure
    state.performedEmotes = {}
    state.danceMoving = {}
    state.danceComplete = {}
    state.measureLocked = false
    state.measureStarted = false
    state.countdownEndTime = nil
    ns.frame:UnregisterEvent("PLAYER_STARTED_MOVING")
    ns.frame:UnregisterEvent("PLAYER_STOPPED_MOVING")

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

    ns.UpdateAssignmentGrid()

    if not silent then
        ns.BroadcastMeasure(measure)
    end
end

function ns.RetryMeasure()
    if not state.currentMeasure then
        Print("No measure selected.")
        return
    end
    state.performedEmotes = {}
    state.danceMoving = {}
    state.danceComplete = {}
    state.measureLocked = false
    state.measureStarted = false
    state.countdownEndTime = nil
    ns.frame:UnregisterEvent("PLAYER_STARTED_MOVING")
    ns.frame:UnregisterEvent("PLAYER_STOPPED_MOVING")

    if IsInGroup() and ns.IsLeaderOrAssist() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(PREFIX, "RETRY:" .. tostring(state.currentMeasure), channel)
    end

    ns.UpdateAssignmentGrid()
    ns.UpdatePlayerPanel()
    ns.ValidateTarget()
end

-- Validate target
function ns.ValidateTarget()
    if not ui.main or not ui.main:IsShown() then return end

    local members = ns.GetSortedRaidMembers()

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
                        elseif v == ns.VERSION then
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

    ns.UpdateAssignmentGrid(members)

    if not state.currentMeasure then
        ns.SetStatus("YELLOW", "No measure selected", {})
        return
    end

    if not ns.IsTargetNpc("target") then
        ns.SetStatus("YELLOW", "Target the Divine Flame of Beledar", {})
        return
    end

    local expected = ns.BuildExpectedCounts(state.currentMeasure)
    if next(expected) == nil then
        ns.SetStatus("YELLOW", "Selected measure only contains placeholders", {})
        return
    end

    local observed, anyAura = ns.BuildObservedCounts()
    if not anyAura then
        ns.SetStatus("RED", "No helpful auras on target", ns.BuildMismatchEntries(expected, observed))
        return
    end

    if ns.CountsEqual(expected, observed) then
        ns.SetStatus("GREEN", "Ready to bow", {})
    else
        ns.SetStatus("RED", "Aura mismatch", ns.BuildMismatchEntries(expected, observed))
    end
end

-- Static popup dialogs
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

StaticPopupDialogs["BELEDAR_IMPORT_SET"] = {
    text = "Paste exported sets string to import:",
    button1 = "Import",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 0,
    OnShow = function(self)
        local editBox = self.editBox or self.EditBox
        editBox:SetWidth(300)
    end,
    OnAccept = function(self)
        local editBox = self.editBox or self.EditBox
        local text = editBox:GetText()
        if ns.ImportOverrides(text) then
            local count = 0
            local saved = BeledarOrchestraDB.SavedSets or {}
            for _, sets in pairs(saved) do
                for _ in pairs(sets) do count = count + 1 end
            end
            Print("Imported " .. count .. " saved assignment set(s).")
        else
            Print("Invalid import string.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["BELEDAR_IMPORT_SET"].OnAccept(parent)
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

-- Main leader UI creation
function ns.CreateLeaderUI()
    local main = ns.CreateBackdropFrame("BeledarOrchestraMainFrame", UIParent, 760, 750)
    main:SetPoint("CENTER", UIParent, "CENTER", -380, 0)
    main:SetFrameStrata("MEDIUM")
    main:SetClampedToScreen(true)
    main:Hide()
    ns.MakeMovable(main)
    ui.main = main

    local title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText("Beledar Orchestra Conductor")

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

    -- Measure selection grid (5x5)
    ui.gridButtons = {}
    local gridW = 5 * 78 + 4 * 6  -- 5 buttons * 78px + 4 gaps * 6px = 414
    local gridStartX = math.floor((760 - gridW) / 2)
    local startY = -78
    local btnW, btnH, gap = 78, 36, 6
    local index = 1

    for row = 1, 5 do
        for col = 1, 5 do
            local measureIndex = index
            local btn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetPoint("TOPLEFT", gridStartX + (col - 1) * (btnW + gap), startY - (row - 1) * (btnH + gap))
            btn:SetText(measureIndex)
            btn:SetScript("OnClick", function()
                if not ns.IsLeaderOrAssist() then
                    Print("Only raid leader or assist should change measures.")
                    return
                end
                ns.SetMeasure(measureIndex)
                ns.UpdatePlayerPanel()
                ns.ValidateTarget()
            end)
            ui.gridButtons[measureIndex] = btn
            index = index + 1
        end
    end

    -- Assignments / Versions toggle buttons
    local toggleW = 120
    local toggleGap = 6
    local toggleTotalW = toggleW * 2 + toggleGap
    local toggleStartX = math.floor((760 - toggleTotalW) / 2)

    local btnAssign = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnAssign:SetSize(toggleW, 22)
    btnAssign:SetPoint("TOPLEFT", toggleStartX, -435)
    btnAssign:SetText("Assignments")
    ui.btnAssign = btnAssign

    local btnVersion = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnVersion:SetSize(toggleW, 22)
    btnVersion:SetPoint("LEFT", btnAssign, "RIGHT", toggleGap, 0)
    btnVersion:SetText("Versions")
    ui.btnVersion = btnVersion

    CreateAssignmentGrid(main)
    CreateVersionGrid(main)

    local checkButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    checkButton:SetSize(120, 22)
    checkButton:SetPoint("LEFT", btnVersion, "RIGHT", 10, 0)
    checkButton:SetText("Check Versions")
    checkButton:SetScript("OnClick", function()
        if not IsInGroup() then
            Print("You are not in a group.")
            return
        end
        ns.SendPing()
        if ns.DS_BroadcastMeasures then ns.DS_BroadcastMeasures() end
    end)
    checkButton:Hide()
    ui.checkButton = checkButton

    local function ShowMode(mode)
        if mode == "VERSION" then
            ui.assignmentContainer:Hide()
            ui.versionContainer:Show()
            ui.btnAssign:SetEnabled(true)
            ui.btnVersion:SetEnabled(false)
            if ui.checkButton then ui.checkButton:Show() end
            if ui.btnSave then ui.btnSave:Hide() end
            if ui.btnLoad then ui.btnLoad:Hide() end
            if ui.btnClear then ui.btnClear:Hide() end
            if ui.btnExport then ui.btnExport:Hide() end
            if ui.btnImport then ui.btnImport:Hide() end
        else
            ui.assignmentContainer:Show()
            ui.versionContainer:Hide()
            ui.btnAssign:SetEnabled(false)
            ui.btnVersion:SetEnabled(true)
            if ui.checkButton then ui.checkButton:Hide() end
            if ui.btnSave then ui.btnSave:Show() end
            if ui.btnLoad then ui.btnLoad:Show() end
            if ui.btnClear then ui.btnClear:Show() end
            if ui.btnExport then ui.btnExport:Show() end
            if ui.btnImport then ui.btnImport:Show() end
            ns.UpdateAssignmentGrid()
        end
    end

    btnAssign:SetScript("OnClick", function() ShowMode("ASSIGN") end)
    btnVersion:SetScript("OnClick", function() ShowMode("VERSION") end)
    ShowMode("ASSIGN")

    -- Management buttons row: Save / Load / Clear Manual Assigns
    local mgmtBtnW = 80
    local clearBtnW = 150
    local mgmtGap = 6
    local mgmtTotalW = mgmtBtnW * 2 + clearBtnW + mgmtGap * 2
    local mgmtStartX = math.floor((760 - mgmtTotalW) / 2)
    local mgmtY = 75

    local btnSave = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnSave:SetSize(mgmtBtnW, 22)
    btnSave:SetPoint("BOTTOMLEFT", mgmtStartX, mgmtY)
    btnSave:SetText("Save")
    btnSave:SetScript("OnClick", function()
        StaticPopup_Show("BELEDAR_SAVE_SET")
    end)
    ui.btnSave = btnSave

    local btnLoad = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnLoad:SetSize(mgmtBtnW, 22)
    btnLoad:SetPoint("LEFT", btnSave, "RIGHT", mgmtGap, 0)
    btnLoad:SetText("Load")
    ui.btnLoad = btnLoad
    btnLoad:SetScript("OnClick", function(self)
        local m = state.currentMeasure
        if not m then
            Print("Select a measure first to load sets for it.")
            return
        end

        local measureSets = BeledarOrchestraDB.SavedSets and BeledarOrchestraDB.SavedSets[m] or {}
        local names = {}
        for name in pairs(measureSets) do table.insert(names, name) end
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
                            if IsInGroup() and ns.IsLeaderOrAssist() then
                                local channel = IsInRaid() and "RAID" or "PARTY"
                                C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_MEASURE:" .. m, channel)
                                for slot, token in pairs(set) do
                                    C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", m, slot, token), channel)
                                end
                            end
                            ns.UpdateAssignmentGrid()
                            ns.UpdatePlayerPanel()
                            ns.ValidateTarget()
                        end
                    end)
                    node:CreateButton("Delete", function()
                        StaticPopup_Show("BELEDAR_DELETE_SET", name, m, { measure = m, name = name })
                    end)
                end
            end)
        else
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
                                if IsInGroup() and ns.IsLeaderOrAssist() then
                                    local channel = IsInRaid() and "RAID" or "PARTY"
                                    C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_MEASURE:" .. m, channel)
                                    for slot, token in pairs(set) do
                                        C_ChatInfo.SendAddonMessage(PREFIX, string.format("OVERRIDE:%d:%d:%s", m, slot, token), channel)
                                    end
                                end
                                ns.UpdateAssignmentGrid()
                                ns.UpdatePlayerPanel()
                                ns.ValidateTarget()
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
    btnClear:SetSize(clearBtnW, 22)
    btnClear:SetPoint("LEFT", btnLoad, "RIGHT", mgmtGap, 0)
    btnClear:SetText("Clear Manual Assigns")
    btnClear:SetScript("OnClick", function()
        BeledarOrchestraDB.Overrides = {}
        Print("Cleared all manual overrides.")
        if IsInGroup() and ns.IsLeaderOrAssist() then
            local channel = IsInRaid() and "RAID" or "PARTY"
            C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR_OVERRIDES", channel)
        end
        ns.UpdateAssignmentGrid()
        ns.UpdatePlayerPanel()
        ns.ValidateTarget()
    end)
    ui.btnClear = btnClear

    -- Export / Import row
    local expImpBtnW = 80
    local expImpGap = 6
    local expImpTotalW = expImpBtnW * 2 + expImpGap
    local expImpStartX = math.floor((760 - expImpTotalW) / 2)
    local expImpY = 50

    local btnExport = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnExport:SetSize(expImpBtnW, 22)
    btnExport:SetPoint("BOTTOMLEFT", expImpStartX, expImpY)
    btnExport:SetText("Export")
    ui.btnExport = btnExport
    btnExport:SetScript("OnClick", function()
        local str = ns.ExportOverrides()
        if str == "" then
            Print("No saved assignment sets to export.")
            return
        end
        if not ui.exportFrame then
            local ef = CreateFrame("Frame", "BeledarExportFrame", UIParent, "BackdropTemplate")
            ef:SetSize(420, 130)
            ef:SetPoint("CENTER")
            ef:SetFrameStrata("DIALOG")
            ef:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            ef:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
            ef:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            ef:EnableMouse(true)
            local efTitle = ef:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            efTitle:SetPoint("TOP", 0, -10)
            efTitle:SetText("Copy the export string below (Ctrl+C):")
            local scroll = CreateFrame("ScrollFrame", "BeledarExportScroll", ef, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 12, -30)
            scroll:SetPoint("BOTTOMRIGHT", -30, 36)
            local eb = CreateFrame("EditBox", "BeledarExportEditBox", scroll)
            eb:SetMultiLine(true)
            eb:SetFontObject(ChatFontNormal)
            eb:SetWidth(370)
            eb:SetAutoFocus(false)
            scroll:SetScrollChild(eb)
            ef.editBox = eb
            local closeBtn = CreateFrame("Button", nil, ef, "UIPanelButtonTemplate")
            closeBtn:SetSize(80, 22)
            closeBtn:SetPoint("BOTTOM", 0, 8)
            closeBtn:SetText("Close")
            closeBtn:SetScript("OnClick", function() ef:Hide() end)
            local efClose = CreateFrame("Button", nil, ef, "UIPanelCloseButton")
            efClose:SetPoint("TOPRIGHT", 0, 0)
            ui.exportFrame = ef
        end
        ui.exportFrame.editBox:SetText(str)
        ui.exportFrame:Show()
        ui.exportFrame.editBox:HighlightText()
        ui.exportFrame.editBox:SetFocus()
    end)

    local btnImport = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    btnImport:SetSize(expImpBtnW, 22)
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", expImpGap, 0)
    btnImport:SetText("Import")
    btnImport:SetScript("OnClick", function()
        StaticPopup_Show("BELEDAR_IMPORT_SET")
    end)
    ui.btnImport = btnImport

    -- Action buttons row: Lock in (Bow) / Start / Retry
    local actionBtnW = 110
    local actionGap = 8
    local actionTotalW = actionBtnW * 3 + actionGap * 2
    local actionStartX = math.floor((760 - actionTotalW) / 2)

    local bowButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    bowButton:SetSize(actionBtnW, 36)
    bowButton:SetPoint("BOTTOMLEFT", actionStartX, 12)
    bowButton:SetText("Lock in (Bow)")
    bowButton:SetScript("OnClick", ns.PressBow)
    ui.bowButton = bowButton

    local startButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    startButton:SetSize(actionBtnW, 36)
    startButton:SetPoint("LEFT", bowButton, "RIGHT", actionGap, 0)
    startButton:SetText("Start")
    startButton:SetScript("OnClick", function()
        if not ns.IsLeaderOrAssist() then
            Print("Only raid leader or assist can start.")
            return
        end
        if not state.currentMeasure then
            Print("Select a measure first.")
            return
        end
        local dur = state.countdownDuration
        state.countdownEndTime = GetTime() + dur
        state.measureStarted = false
        C_PartyInfo.DoCountdown(10)
        if IsInGroup() then
            local channel = IsInRaid() and "RAID" or "PARTY"
            C_ChatInfo.SendAddonMessage(PREFIX, "START:" .. tostring(state.currentMeasure) .. ":" .. tostring(dur), channel)
        end
        ns.UpdatePlayerPanel()
        ns.UpdateAssignmentGrid()
        Print("Measure " .. state.currentMeasure .. " countdown started! (" .. dur .. "s)")
    end)
    ui.startButton = startButton

    local retryButton = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    retryButton:SetSize(actionBtnW, 36)
    retryButton:SetPoint("LEFT", startButton, "RIGHT", actionGap, 0)
    retryButton:SetText("Retry")
    retryButton:SetScript("OnClick", function()
        if not ns.IsLeaderOrAssist() then
            Print("Only raid leader or assist can retry.")
            return
        end
        ns.RetryMeasure()
    end)
    ui.retryButton = retryButton

    local addonStatusText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addonStatusText:SetPoint("BOTTOMLEFT", 20, 52)
    addonStatusText:SetWidth(720)
    addonStatusText:SetJustifyH("CENTER")
    addonStatusText:SetText("")
    ui.addonStatusText = addonStatusText

    local closeButton = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)

    ns.EnsureMismatchWidgets()
end
