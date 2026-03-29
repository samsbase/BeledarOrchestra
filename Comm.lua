local _, ns = ...

local PREFIX = ns.PREFIX
local state = ns.state
local Print = ns.Print

function ns.BroadcastMeasure(measure)
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "MEASURE:" .. tostring(measure or 0), channel)
end

function ns.SendPing()
    if not IsInGroup() then return end
    state.activePlayers = {}
    state.lastPingTime = GetTime()
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PING", channel)
    Print("Sent version check to group...")
end

function ns.SendPong()
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(PREFIX, "PONG:" .. ns.VERSION, channel)
end

function ns.HandleAddonMessage(message, sender)
    local action, value = strsplit(":", message)

    if action == "MEASURE" then
        local n = tonumber(value)
        if n == 0 then n = nil end
        ns.SetMeasure(n, true)
        ns.UpdatePlayerPanel()
        ns.ValidateTarget()

    elseif action == "OVERRIDE" then
        local measure, slot, token = select(2, strsplit(":", message))
        measure = tonumber(measure)
        slot = tonumber(slot)
        if measure and slot and token then
            BeledarOrchestraDB.Overrides = BeledarOrchestraDB.Overrides or {}
            BeledarOrchestraDB.Overrides[measure] = BeledarOrchestraDB.Overrides[measure] or {}
            BeledarOrchestraDB.Overrides[measure][slot] = token
            ns.UpdateAssignmentGrid()
            ns.UpdatePlayerPanel()
            ns.ValidateTarget()
        end

    elseif action == "CLEAR_OVERRIDES" then
        BeledarOrchestraDB.Overrides = {}
        ns.UpdateAssignmentGrid()
        ns.UpdatePlayerPanel()
        ns.ValidateTarget()

    elseif action == "CLEAR_MEASURE" then
        local m = tonumber(value)
        if m and BeledarOrchestraDB.Overrides then
            BeledarOrchestraDB.Overrides[m] = nil
            ns.UpdateAssignmentGrid()
            ns.UpdatePlayerPanel()
            ns.ValidateTarget()
        end

    elseif action == "PING" then
        ns.SendPong()

    elseif action == "PONG" then
        local name = Ambiguate(sender, "none")
        state.activePlayers[name] = value or "Unknown"

    elseif action == "PERFORMED" then
        local measure, slot = select(2, strsplit(":", message))
        measure = tonumber(measure)
        slot = tonumber(slot)
        if measure == state.currentMeasure and slot then
            state.performedEmotes[slot] = true
            ns.UpdateAssignmentGrid()
        end

    elseif action == "DANCE_MOVING" then
        local measure, slot = select(2, strsplit(":", message))
        measure = tonumber(measure)
        slot = tonumber(slot)
        if measure == state.currentMeasure and slot then
            state.danceMoving[slot] = true
            ns.UpdateAssignmentGrid()
        end

    elseif action == "DANCE_STOPPED" then
        local measure, slot = select(2, strsplit(":", message))
        measure = tonumber(measure)
        slot = tonumber(slot)
        if measure == state.currentMeasure and slot then
            state.danceComplete[slot] = true
            ns.UpdateAssignmentGrid()
        end

    elseif action == "RETRY" then
        local m = tonumber(value)
        if m == state.currentMeasure then
            state.performedEmotes = {}
            state.danceMoving = {}
            state.danceComplete = {}
            state.measureLocked = false
            state.measureStarted = false
            state.countdownEndTime = nil
            ns.frame:UnregisterEvent("PLAYER_STARTED_MOVING")
            ns.frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
            ns.UpdateAssignmentGrid()
            ns.UpdatePlayerPanel()
            ns.ValidateTarget()
        end

    elseif action == "START" then
        local m, dur = select(2, strsplit(":", message))
        m = tonumber(m)
        dur = tonumber(dur) or state.countdownDuration
        if m == state.currentMeasure then
            state.countdownEndTime = GetTime() + dur
            state.measureStarted = false
            ns.UpdatePlayerPanel()
            ns.UpdateAssignmentGrid()
        end
    end
end
