local _, ns = ...

local RAID_SLOTS = ns.RAID_SLOTS

-- Emote definitions
ns.EMOTES = {
    CHEER = { command = "CHEER", display = "/cheer", spellId = 1266756 },
    SING = { command = "SING", display = "/sing", spellId = 1266760 },
    DANCE = { command = "DANCE", display = "/dance", spellId = 1266758 },
    VIOLIN = { command = "VIOLIN", display = "/violin", spellId = 1266761 },
    APPLAUD = { command = "APPLAUD", display = "/applaud", spellId = 1266754 },
    CONGRATS = { command = "CONGRATULATE", display = "/congratulate", spellId = 1266755 },
    ROAR = { command = "ROAR", display = "/roar", spellId = 1266759 },
    BOW = { command = "BOW", display = "/bow", spellId = nil },
    PLACEHOLDER = { command = nil, display = "?", spellId = nil },
}

-- Reverse lookup: spellId -> token
ns.SPELL_ID_TO_TOKEN = {}
for token, emote in pairs(ns.EMOTES) do
    if emote.spellId then
        ns.SPELL_ID_TO_TOKEN[emote.spellId] = token
    end
end

-- Compact encoding for export/import
local ENCODE_MAP = { APPLAUD="A", BOW="B", CHEER="C", CONGRATS="G", DANCE="D", PLACEHOLDER="P", ROAR="R", SING="S", VIOLIN="V" }
local DECODE_MAP = {}
for k, v in pairs(ENCODE_MAP) do DECODE_MAP[v] = k end

function ns.ExportOverrides()
    local saved = BeledarOrchestraDB.SavedSets
    if not saved then return "" end
    local parts = {}
    local measures = {}
    for m in pairs(saved) do table.insert(measures, m) end
    table.sort(measures)
    for _, m in ipairs(measures) do
        local setTable = saved[m]
        if setTable then
            local names = {}
            for n in pairs(setTable) do table.insert(names, n) end
            table.sort(names)
            for _, setName in ipairs(names) do
                local slots = setTable[setName]
                if slots then
                    local entries = {}
                    local slotNums = {}
                    for s in pairs(slots) do table.insert(slotNums, s) end
                    table.sort(slotNums)
                    for _, s in ipairs(slotNums) do
                        local ch = ENCODE_MAP[slots[s]]
                        if ch then
                            table.insert(entries, string.format("%02d%s", s, ch))
                        end
                    end
                    if #entries > 0 then
                        local safeName = setName:gsub("~", "")
                        table.insert(parts, m .. "~" .. safeName .. ":" .. table.concat(entries))
                    end
                end
            end
        end
    end
    return table.concat(parts, ";")
end

function ns.ImportOverrides(str)
    if not str or str == "" then return false end
    local newSaved = {}
    for segment in str:gmatch("[^;]+") do
        local mStr, setName, data = segment:match("^(%d+)~(.-):(..+)$")
        local m = tonumber(mStr)
        if m and setName and setName ~= "" and data then
            newSaved[m] = newSaved[m] or {}
            newSaved[m][setName] = {}
            for slotStr, ch in data:gmatch("(%d%d)(%a)") do
                local s = tonumber(slotStr)
                local token = DECODE_MAP[ch]
                if s and s >= 1 and s <= RAID_SLOTS and token then
                    newSaved[m][setName][s] = token
                end
            end
        end
    end
    BeledarOrchestraDB.SavedSets = newSaved
    return true
end

-- Data access functions
function ns.GetMeasureEmote(measure, slot)
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

function ns.IsReady(unit, slotIndex)
    if not unit then return false end
    if not UnitIsConnected(unit) then return false end

    if ns.HasAura(unit, 1266536) then return true end

    for _, emote in pairs(ns.EMOTES) do
        if emote.spellId and ns.HasAura(unit, emote.spellId) then
            return true
        end
    end

    if ns.state.currentMeasure and slotIndex then
        local token = ns.GetMeasureEmote(ns.state.currentMeasure, slotIndex)
        local emote = ns.EMOTES[token]
        if emote and emote.spellId and ns.HasAura(unit, emote.spellId) then
            return true
        end
    end

    return false
end

function ns.GetSortedRaidMembers()
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

function ns.GetRaidSlotForPlayer()
    local members = ns.GetSortedRaidMembers()
    for visualSlot, member in ipairs(members) do
        if member.unit and UnitIsUnit(member.unit, "player") then
            return visualSlot
        end
    end
    return nil
end

function ns.BuildExpectedCounts(measure)
    local expected = {}
    if not measure then
        return expected
    end

    for slot = 1, RAID_SLOTS do
        local token = ns.GetMeasureEmote(measure, slot)
        if token and token ~= "PLACEHOLDER" then
            local emote = ns.EMOTES[token]
            if emote and emote.spellId then
                expected[emote.spellId] = (expected[emote.spellId] or 0) + 1
            end
        end
    end

    return expected
end

function ns.BuildObservedCounts()
    local observed = {}
    local anyAura = false

    for _, emote in pairs(ns.EMOTES) do
        if emote.spellId then
            local aura = C_UnitAuras.GetAuraDataBySpellID("target", emote.spellId, "HELPFUL")
            if aura then
                anyAura = true
                observed[emote.spellId] = (aura.applications or 0) > 0 and aura.applications or 1
            end
        end
    end

    return observed, anyAura
end

function ns.CountsEqual(expected, observed)
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

function ns.BuildMismatchEntries(expected, observed)
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
