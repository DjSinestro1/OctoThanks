-- OctoThanks
-- Small Vanilla 1.12 addon for OctoWow/Turtle-style clients.
-- It whispers a thank-you to players who cast a helpful buff on you.

local DEFAULT_MESSAGE = "Thanks for the buff!"
local DEFAULT_MESSAGES = {
    "Ayyy, that is nice! Appreciate you and your buffs!",
    "Much appreciated! You are a buffing legend.",
    "Ayy, thank you! That buff is going to help a lot.",
    "Thanks for the buff! I owe you one.",
    "Nice! Appreciate you looking out for me.",
    "Thank you kindly for the buff!",
    "You are awesome—thanks for the buff!",
    "Ayyy, appreciate the buffs! You rock.",
}
local DEFAULT_COOLDOWN = 60
local DEFAULT_DELAY = 1
local MIN_BUFF_DURATION = 120

local db = OctoThanksDB or {}
OctoThanksDB = db

if db.enabled == nil then db.enabled = true end
if db.message == nil then db.message = DEFAULT_MESSAGE end
if db.cooldown == nil then db.cooldown = DEFAULT_COOLDOWN end
if db.delay == nil then db.delay = DEFAULT_DELAY end
if db.includeGroup == nil then db.includeGroup = true end

local frame = CreateFrame("Frame", "OctoThanksFrame")
local pending = {}
local lastThanked = {}
local auraEventsAvailable = false
local lastMessageIndex

if math and math.randomseed then
    math.randomseed((GetTime and GetTime() or 1) * 1000)
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffOctoThanks|r: " .. message)
end

local function Trim(value)
    return string.gsub(value or "", "^%s*(.-)%s*$", "%1")
end

local function EscapePattern(value)
    return string.gsub(value, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

-- Converts the localized SPELLLOGOTHERSELF format into a Lua pattern.
-- On an English client this is usually "%s casts %s on you.".
local function ParseSpellLogMessage(message)
    local template = SPELLLOGOTHERSELF
    if not template or not message then
        return nil, nil
    end

    local firstStart, firstEnd = string.find(template, "%%s")
    if not firstStart then
        return nil, nil
    end

    local secondStart, secondEnd = string.find(template, "%%s", firstEnd + 1)
    if not secondStart then
        return nil, nil
    end

    local before = string.sub(template, 1, firstStart - 1)
    local between = string.sub(template, firstEnd + 1, secondStart - 1)
    local after = string.sub(template, secondEnd + 1)
    local pattern = "^" .. EscapePattern(before) .. "(.+)"
        .. EscapePattern(between) .. "(.+)" .. EscapePattern(after) .. "$"

    local caster, spellName = string.match(message, pattern)
    if caster then
        return caster, spellName
    end

    -- English fallback for clients or server patches that do not expose the
    -- expected localized global string.
    return string.match(message, "^(.+) casts (.+) on you%.$")
end

local function IsGroupMember(name)
    if GetNumPartyMembers then
        local count = GetNumPartyMembers()
        local i
        for i = 1, count do
            if UnitName("party" .. i) == name then
                return true
            end
        end
    end

    if GetNumRaidMembers then
        local count = GetNumRaidMembers()
        local i
        for i = 1, count do
            if UnitName("raid" .. i) == name then
                return true
            end
        end
    end

    return false
end

local function IsUsablePlayerName(name)
    if not name or name == "" then
        return false
    end

    if name == UnitName("player") then
        return false
    end

    if IsGroupMember(name) and not db.includeGroup then
        return false
    end

    -- Standard spell-chat events are already limited to friendly players.
    return true
end

local function BuildMessage(spellName)
    local message = db.message
    -- Existing users have the old default saved. Treat it as the rotating
    -- default, while preserving any custom message they explicitly chose.
    if not message or message == "" or message == DEFAULT_MESSAGE then
        local index
        repeat
            index = math.random(1, table.getn(DEFAULT_MESSAGES))
        until table.getn(DEFAULT_MESSAGES) == 1 or index ~= lastMessageIndex
        lastMessageIndex = index
        message = DEFAULT_MESSAGES[index]
    end
    if string.find(message, "%%s") and spellName then
        message = string.gsub(message, "%%s", spellName, 1)
    end
    return message
end

local function SendThankYou(name, spellName)
    if not db.enabled or not IsUsablePlayerName(name) then
        return
    end

    local now = GetTime()
    if lastThanked[name] and now - lastThanked[name] < db.cooldown then
        return
    end

    lastThanked[name] = now
    SendChatMessage(BuildMessage(spellName), "WHISPER", nil, name)
end

local function QueueThankYou(name, spellName)
    if not db.enabled or not IsUsablePlayerName(name) then
        return
    end

    local now = GetTime()
    if lastThanked[name] and now - lastThanked[name] < db.cooldown then
        return
    end

    pending[name] = {
        spellName = spellName,
        sendAt = now + db.delay,
    }
end

frame:SetScript("OnUpdate", function()
    local now = GetTime()
    local name, item

    for name, item in pairs(pending) do
        if now >= item.sendAt then
            pending[name] = nil
            SendThankYou(name, item.spellName)
        end
    end
end)

local function HandleSpellChat(message)
    -- Chat messages do not include duration. Prefer Nampower's aura event
    -- when available so short HoTs such as Renew cannot trigger a reply.
    if auraEventsAvailable then
        return
    end
    local caster, spellName = ParseSpellLogMessage(message)
    if caster then
        QueueThankYou(caster, spellName)
    end
end

frame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
frame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"
        or event == "CHAT_MSG_SPELL_PARTY_BUFF" then
        HandleSpellChat(arg1)
    end
end)

-- Nampower's aura event gives us the caster directly and catches buffs that
-- do not produce the normal spell-chat message. It is optional.
if Nampower and Nampower.RegisterEvent and Nampower.HasMinimumVersion
    and Nampower:HasMinimumVersion(2, 20, 0) then
    auraEventsAvailable = true
    Nampower:RegisterEvent("AURA_CAST_ON_SELF", function(spellId, casterGuid,
        targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue,
        durationMs)
        -- Nampower reports aura duration in milliseconds. Require strictly
        -- more than two minutes.
        if not durationMs or durationMs <= (MIN_BUFF_DURATION * 1000) then
            return
        end
        local casterName = casterGuid and UnitName(casterGuid)
        local spellName

        if GetSpellRecField then
            spellName = GetSpellRecField(spellId, "name")
        end

        -- UnitIsPlayer accepts Nampower GUID unit tokens. If it is not
        -- available for this client, the classic chat-event fallback remains.
        if casterName and UnitIsPlayer and UnitIsPlayer(casterGuid) then
            QueueThankYou(casterName, spellName)
        end
    end)

    if GetCVar and SetCVar and GetCVar("NP_EnableAuraCastEvents") ~= "1" then
        SetCVar("NP_EnableAuraCastEvents", "1")
        Print("Nampower aura detection enabled; reload your UI once to activate it.")
    end
end

local function SetEnabled(value)
    db.enabled = value
    Print(db.enabled and "enabled." or "disabled.")
end

SLASH_OCTOTHANKS1 = "/octothanks"
SLASH_OCTOTHANKS2 = "/ot"
SlashCmdList["OCTOTHANKS"] = function(message)
    local command, rest = string.match(message or "", "^(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    rest = Trim(rest)

    if command == "on" then
        SetEnabled(true)
    elseif command == "off" then
        SetEnabled(false)
    elseif command == "message" and rest ~= "" then
        if rest == "default" or rest == "random" then
            db.message = DEFAULT_MESSAGE
            Print("message rotation restored (8 variations).")
        else
            db.message = rest
            Print("message set to: " .. db.message)
        end
    elseif command == "cooldown" and tonumber(rest) then
        db.cooldown = math.max(0, tonumber(rest))
        Print("cooldown set to " .. db.cooldown .. " seconds.")
    elseif command == "delay" and tonumber(rest) then
        db.delay = math.max(0, tonumber(rest))
        Print("delay set to " .. db.delay .. " seconds.")
    elseif command == "group" and (rest == "on" or rest == "off") then
        db.includeGroup = rest == "on"
        Print(db.includeGroup and "group buffs included." or "group buffs ignored.")
    else
        Print("/ot on | off")
        Print("/ot message default   (restore rotating messages)")
        Print("/ot message <text>   (use one fixed message; %s = spell name)")
        Print("Use %s in the message to include the spell name.")
        Print("/ot cooldown <seconds>   /ot delay <seconds>")
        Print("/ot group on | off")
        Print("Current: " .. (db.enabled and "enabled" or "disabled")
            .. ", cooldown " .. db.cooldown .. "s, delay " .. db.delay .. "s")
    end
end

Print("loaded. Type /ot for settings.")
