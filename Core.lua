local ADDON_NAME, ns = ...

-- Saved variables (initialized in ADDON_LOADED)
BeledarOrchestraDB = BeledarOrchestraDB or {}

-- Constants
ns.PREFIX = "BeledarOrch"
ns.TARGET_NPC_ID = 255888
ns.UPDATE_INTERVAL = 0.2
ns.MAX_MEASURES = 25
ns.RAID_SLOTS = 40
ns.ZONE_ID = 2215

ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"
ns.ADDON_NAME = ADDON_NAME

-- Shared state
ns.state = {
    currentMeasure = nil,
    status = "YELLOW",
    mismatchText = "No measure selected",
    lastUpdate = 0,
    activePlayers = {},
    lastPingTime = 0,
    performedEmotes = {},
    danceMoving = {},
    danceComplete = {},
    measureLocked = false,
    measureStarted = false,
    countdownEndTime = nil,
    countdownDuration = 10,
    lastCompletedMeasure = nil,
}

-- Shared UI table
ns.ui = {}

-- Main event frame
ns.frame = CreateFrame("Frame")

-- Utility functions
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBeledar Orchestra:|r " .. tostring(msg))
end

function ns.GetNpcID(unit)
    local id = UnitCreatureID(unit)
    -- Secret while unit identity is restricted (12.0+); comparing it would error.
    if id and not issecretvalue(id) then return tonumber(id) end
    return nil
end

-- DoEmote is only a deprecation fallback since 12.0 (absent when loadDeprecationFallbacks is off).
function ns.DoEmote(command)
    return C_ChatInfo.PerformEmote(command)
end

-- ActionButton_Show/HideOverlayGlow were removed; the alert manager works on any frame.
function ns.SetButtonGlow(button, on)
    if not button then return end
    if on then
        ActionButtonSpellAlertManager:ShowAlert(button)
    else
        ActionButtonSpellAlertManager:HideAlert(button)
    end
end

function ns.IsTargetNpc(unit)
    return ns.GetNpcID(unit) == ns.TARGET_NPC_ID
end

function ns.IsLeaderOrAssist()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function ns.GetAuraData(unit, spellId, filter)
    if not unit or not spellId then return nil end
    filter = filter or "HELPFUL"
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then break end

        local auraSpellId = aura.spellId
        -- Secret while aura access is restricted (12.0+); comparing it would error.
        if auraSpellId and not issecretvalue(auraSpellId) and auraSpellId == spellId then
            return aura
        end
    end
    return nil
end

function ns.HasAura(unit, spellId)
    return ns.GetAuraData(unit, spellId) ~= nil
end

function ns.MakeMovable(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

function ns.CreateBackdropFrame(name, parent, width, height)
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

function ns.GetSpellNameSafe(spellId)
    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellId)
        if n then return n end
    end
    return tostring(spellId)
end

function ns.GetSpellTextureSafe(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local t = C_Spell.GetSpellTexture(spellId)
        if t then return t end
    end
    return 134400
end
