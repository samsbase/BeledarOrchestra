local _, ns = ...

-- =============================================================
-- BO_DATASYNC  –  Measures broadcast & peer sync
--
-- Newer BO clients proactively push ns.MEASURES to the group
-- on login and whenever the group roster grows or the leader
-- changes (indicating a new group).  Older BO clients receive
-- and cache the data, persisting it across sessions.
--
-- Protocol prefix : BO_DATASYNC
-- Messages
--   ANN:MEASURES:<versionInt>           broadcaster announces version; data follows
--   DAT:MEASURES:<n>/<total>:<238chars> one encoded chunk
--
-- Encoding: 8 tokens → 1 char  (P S D V C A R G)
-- 25 x 40 = 1 000-char flat string → 5 chunks of ≤ 238 chars
-- =============================================================
do
    local Print = ns.Print
    local RAID_SLOTS = ns.RAID_SLOTS
    local MAX_MEASURES = ns.MAX_MEASURES

    local DS_PREFIX     = "BO_DATASYNC"
    local DS_CHUNK_SIZE = 238

    local function DS_VersionToInt(v)
        local maj, min, pat = (v or "0"):match("^(%d+)%.?(%d*)%.?(%d*)")
        return (tonumber(maj) or 0) * 10000
             + (tonumber(min) or 0) * 100
             + (tonumber(pat) or 0)
    end

    local DS_MY_VERSION = DS_VersionToInt(ns.VERSION)

    local DS_ENC = {
        PLACEHOLDER = "P", SING = "S", DANCE = "D", VIOLIN = "V",
        CHEER       = "C", APPLAUD = "A", ROAR = "R", CONGRATS = "G",
    }
    local DS_DEC = {}
    for token, ch in pairs(DS_ENC) do DS_DEC[ch] = token end

    local function DS_Encode()
        local t = {}
        for m = 1, MAX_MEASURES do
            for b = 1, RAID_SLOTS do
                local token = ns.MEASURES[m] and ns.MEASURES[m][b] or "PLACEHOLDER"
                t[#t + 1] = DS_ENC[token] or "P"
            end
        end
        return table.concat(t)
    end

    local function DS_Decode(str)
        if #str ~= MAX_MEASURES * RAID_SLOTS then return nil end
        local tbl = {}
        local idx = 1
        for m = 1, MAX_MEASURES do
            tbl[m] = {}
            for b = 1, RAID_SLOTS do
                tbl[m][b] = DS_DEC[str:sub(idx, idx)] or "PLACEHOLDER"
                idx = idx + 1
            end
        end
        return tbl
    end

    local function DS_GetChannel()
        if IsInRaid() then
            return (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE))
                   and "INSTANCE_CHAT" or "RAID"
        elseif IsInGroup() then
            return (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE))
                   and "INSTANCE_CHAT" or "PARTY"
        end
        return nil
    end

    local function DS_GetLeaderGUID()
        if IsInRaid() then
            for i = 1, RAID_SLOTS do
                if UnitIsGroupLeader("raid" .. i) then return UnitGUID("raid" .. i) end
            end
        elseif IsInGroup() then
            for i = 1, 4 do
                if UnitIsGroupLeader("party" .. i) then return UnitGUID("party" .. i) end
            end
        end
        if UnitIsGroupLeader("player") then return UnitGUID("player") end
        return nil
    end

    local ds_effectiveVersion = DS_MY_VERSION
    local ds_lastLeaderGUID   = nil
    local ds_lastGroupSize    = 0
    local ds_broadcastTimer   = nil
    local ds_buffer           = {}

    local function DS_BroadcastMeasures()
        local ch = DS_GetChannel()
        if not ch then return end
        local encoded     = DS_Encode()
        local totalChunks = math.ceil(#encoded / DS_CHUNK_SIZE)
        C_ChatInfo.SendAddonMessage(DS_PREFIX, "ANN:MEASURES:" .. DS_MY_VERSION, ch)
        for i = 1, totalChunks do
            local s = (i - 1) * DS_CHUNK_SIZE + 1
            local e = math.min(i * DS_CHUNK_SIZE, #encoded)
            C_ChatInfo.SendAddonMessage(DS_PREFIX,
                "DAT:MEASURES:" .. i .. "/" .. totalChunks .. ":" .. encoded:sub(s, e), ch)
        end
    end

    -- Expose to namespace so LeaderUI can call it from Check Versions
    ns.DS_BroadcastMeasures = DS_BroadcastMeasures

    local function DS_ScheduleBroadcast(delay)
        if ds_broadcastTimer then return end
        ds_broadcastTimer = C_Timer.NewTimer(delay, function()
            ds_broadcastTimer = nil
            DS_BroadcastMeasures()
        end)
    end

    local function DS_CancelBroadcast()
        if ds_broadcastTimer then
            ds_broadcastTimer:Cancel()
            ds_broadcastTimer = nil
        end
    end

    local function DS_Apply(decoded, rawData, boVersion, senderShort)
        ns.MEASURES = decoded
        BeledarOrchestraDB.syncedMeasures = { boVersion = boVersion, data = rawData }
        ds_effectiveVersion = boVersion
        Print("Measures updated from " .. senderShort .. ".")
    end

    local function DS_LoadSaved()
        local saved = BeledarOrchestraDB.syncedMeasures
        if not saved or type(saved.data) ~= "string" or #saved.data ~= MAX_MEASURES * RAID_SLOTS then return end
        if (saved.boVersion or 0) <= DS_MY_VERSION then return end
        local decoded = DS_Decode(saved.data)
        if decoded then
            ns.MEASURES = decoded
            ds_effectiveVersion = saved.boVersion
        end
    end

    C_ChatInfo.RegisterAddonMessagePrefix(DS_PREFIX)

    local dsFrame = CreateFrame("Frame")
    dsFrame:RegisterEvent("ADDON_LOADED")
    dsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    dsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    dsFrame:RegisterEvent("CHAT_MSG_ADDON")

    dsFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            local name = ...
            if name == ns.ADDON_NAME then
                DS_LoadSaved()
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            DS_ScheduleBroadcast(10)

        elseif event == "GROUP_ROSTER_UPDATE" then
            local inGroup = IsInRaid() or IsInGroup()
            if not inGroup then
                ds_lastLeaderGUID = nil
                ds_lastGroupSize  = 0
                return
            end
            local leaderGUID = DS_GetLeaderGUID()
            local groupSize  = GetNumGroupMembers()
            local leaderChanged = leaderGUID ~= ds_lastLeaderGUID
            local groupGrew     = groupSize > ds_lastGroupSize
            ds_lastLeaderGUID = leaderGUID
            ds_lastGroupSize  = groupSize
            if leaderChanged or groupGrew then
                DS_ScheduleBroadcast(3)
            end

        elseif event == "CHAT_MSG_ADDON" then
            local prefix, message, _, sender = ...
            if prefix ~= DS_PREFIX then return end
            local senderShort = Ambiguate(sender, "none")
            if senderShort == UnitName("player") then return end

            local msgType, rest = message:match("^([A-Z]+):(.+)$")
            if not msgType then return end

            if msgType == "ANN" then
                local dataType, verStr = rest:match("^([A-Z]+):(%d+)$")
                if dataType ~= "MEASURES" then return end
                local theirVer = tonumber(verStr) or 0
                if theirVer >= DS_MY_VERSION then
                    DS_CancelBroadcast()
                end
                if theirVer > ds_effectiveVersion and not ds_buffer[senderShort] then
                    ds_buffer[senderShort] = {
                        chunks = {},
                        total  = 5,
                        ver    = theirVer,
                        timer  = C_Timer.NewTimer(30, function()
                            ds_buffer[senderShort] = nil
                        end),
                    }
                end

            elseif msgType == "DAT" then
                local dataType, nStr, tStr, chunk = rest:match("^([A-Z]+):(%d+)/(%d+):(.+)$")
                if dataType ~= "MEASURES" then return end
                local n, total = tonumber(nStr), tonumber(tStr)
                if not n or not total then return end
                local buf = ds_buffer[senderShort]
                if not buf then return end
                buf.total     = total
                buf.chunks[n] = chunk
                local done = true
                for i = 1, buf.total do
                    if not buf.chunks[i] then done = false; break end
                end
                if done then
                    if buf.timer then buf.timer:Cancel() end
                    local boVersion = buf.ver
                    local parts = {}
                    for i = 1, total do parts[i] = buf.chunks[i] end
                    ds_buffer[senderShort] = nil
                    local rawData = table.concat(parts)
                    local decoded = DS_Decode(rawData)
                    if decoded then
                        DS_Apply(decoded, rawData, boVersion, senderShort)
                    end
                end
            end
        end
    end)
end
