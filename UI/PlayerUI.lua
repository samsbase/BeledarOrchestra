local _, ns = ...

local ui = ns.ui
local state = ns.state
local EMOTES = ns.EMOTES
local Print = ns.Print

function ns.UpdatePlayerPanel()
    if not ui.playerFrame then return end

    local isTargeted = ns.IsTargetNpc("target")
    if not isTargeted then
        if ui.playerFrame:IsShown() then ui.playerFrame:Hide() end
        state.playerUIClosed = nil
        return
    end

    if not ui.playerFrame:IsShown() then
        if state.playerUIClosed then return end
        ui.playerFrame:Show()
    end

    local slot = ns.GetRaidSlotForPlayer()
    local token = "PLACEHOLDER"
    if slot and state.currentMeasure then
        token = ns.GetMeasureEmote(state.currentMeasure, slot)
    end

    local emote = EMOTES[token] or EMOTES.PLACEHOLDER

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
        elseif not state.measureStarted then
            if state.countdownEndTime then
                local remaining = state.countdownEndTime - GetTime()
                if remaining > 0 then
                    ui.playerButton:SetText(string.format("Get ready... %d", math.ceil(remaining)))
                    ui.playerButton:SetEnabled(false)
                    ui.playerButton:SetAlpha(0.8)
                else
                    -- Countdown finished but OnUpdate hasn't flipped the flag yet; do it now
                    state.measureStarted = true
                    state.countdownEndTime = nil
                    ui.playerButton:SetText(emote.display)
                    ui.playerButton:SetEnabled(true)
                    ui.playerButton:SetAlpha(1)
                end
            else
                ui.playerButton:SetText(emote.display .. " (waiting)")
                ui.playerButton:SetEnabled(false)
                ui.playerButton:SetAlpha(0.6)
            end
        else
            ui.playerButton:SetText(emote.display)
            ui.playerButton:SetEnabled(true)
            ui.playerButton:SetAlpha(1)
        end
        ui.playerButton:Show()
    end

    ui.playerFrame:Show()
end

function ns.PressPlayerEmote()
    local slot = ns.GetRaidSlotForPlayer()
    local measure = state.currentMeasure

    if not slot or not measure then
        ns.UpdatePlayerPanel()
        slot = ns.GetRaidSlotForPlayer()
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

    if not state.measureStarted then
        -- Check if countdown actually expired but flag wasn't set yet (race with OnUpdate)
        if state.countdownEndTime and (state.countdownEndTime - GetTime()) <= 0 then
            state.measureStarted = true
            state.countdownEndTime = nil
        else
            Print("Cannot emote: leader has not started the countdown yet.")
            return
        end
    end

    if state.measureLocked then
        Print("Measure already performed. Wait for a new measure or leader retry.")
        return
    end

    local token = ns.GetMeasureEmote(measure, slot)
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
        C_ChatInfo.SendAddonMessage(ns.PREFIX, string.format("PERFORMED:%d:%d", measure, slot), channel)
    end

    if token == "DANCE" then
        ns.frame:RegisterEvent("PLAYER_STARTED_MOVING")
        ns.frame:RegisterEvent("PLAYER_STOPPED_MOVING")
    end

    ns.UpdatePlayerPanel()
end

function ns.PressBow()
    DoEmote("BOW")
    if ui.bowButton and ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(ui.bowButton)
    end
end

function ns.CreatePlayerUI()
    local playerFrame = ns.CreateBackdropFrame("BeledarOrchestraPlayerFrame", UIParent, 260, 155)
    playerFrame:SetPoint("CENTER", UIParent, "CENTER", 360, -120)
    playerFrame:SetFrameStrata("MEDIUM")
    playerFrame:SetClampedToScreen(true)
    playerFrame:EnableMouse(true)
    playerFrame:Show()
    ns.MakeMovable(playerFrame)
    ui.playerFrame = playerFrame

    local title = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Beledar Assignment")

    local versionText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("TOPLEFT", playerFrame, "TOPLEFT", 8, -10)
    versionText:SetText("v" .. (C_AddOns.GetAddOnMetadata("BeledarOrchestra", "Version") or "?"))

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
    button:SetScript("OnClick", ns.PressPlayerEmote)
    button:SetText("No measure")
    button:Show()
    ui.playerButton = button

    local closeButton = CreateFrame("Button", nil, playerFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function()
        state.playerUIClosed = true
        playerFrame:Hide()
    end)

    ns.UpdatePlayerPanel()
end
