-- OctoThanks
-- Small Vanilla 1.12 addon for OctoWow/Turtle-style clients.
-- It says thanks by default, with optional whisper or THANK emote modes.

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
    "That buff is the bee's knees! Cheers, mate!",
    "You're a diamond geezer - cheers for the buff!",
    "That buff's proper mint. Nice one!",
    "Cheers, my china plate! Lovely buff.",
    "That's a bit of all right! Ta for the buff!",
    "Respect, fam - appreciate the buff!",
    "Big up yourself! Thanks for looking out.",
    "That buff's fire, no cap. Appreciate you!",
    "You're a real one. Thanks for the buff!",
    "Buff game on point! Much love!",
    "Now we're cooking! Thanks for the sweet buff!",
    "That's smooth, cool cat. Thanks for the buff!",
    "Right on! That buff's got me grooving.",
    "Groovy stuff! Appreciate the magical hookup!",
    "Cheers, legend! That buff's a beaut.",
    "Good on ya, mate! Thanks for the buff!",
    "Sweet as! Chur for the buff!",
    "Shot, bru! That's a lekker buff!",
    "That's class! Cheers a million for the buff!",
    "Beauty, eh? Thanks a bunch for the buff!",
}
local DEFAULT_COOLDOWN = 60
local DEFAULT_DELAY = 5
local MIN_BUFF_DURATION = 120
local POSITIVE_EMOTES = {"SALUTE", "BOW", "WAVE", "CHEER", "APPLAUD"}

local db = OctoThanksDB or {}
OctoThanksDB = db

if db.enabled == nil then db.enabled = true end
-- Whisper is the safe default. Preserve an explicit SAY or EMOTE choice.
if db.channel ~= "SAY" and db.channel ~= "WHISPER" and db.channel ~= "EMOTE" then db.channel = "WHISPER" end
if db.message == nil then db.message = DEFAULT_MESSAGE end
if db.cooldown == nil then db.cooldown = DEFAULT_COOLDOWN end
-- The previous release used one second as its implicit default. Migrate that
-- old implicit value to the new five-second default; users can change it back.
if db.delay == nil or db.delay == 1 then db.delay = DEFAULT_DELAY end
if db.includeGroup == nil then db.includeGroup = true end
if db.skipGroupWhispers == nil then db.skipGroupWhispers = false end
if db.emoteStyle ~= "RANDOM" and db.emoteStyle ~= "THANK" then db.emoteStyle = "THANK" end
if type(db.ignoredBuffs) ~= "table" then db.ignoredBuffs = {} end

local frame = CreateFrame("Frame", "OctoThanksFrame")
local pending = {}
local lastThanked = {}
local auraEventsAvailable = false
local lastMessageIndex
local lastEmote

if math and math.randomseed then
    math.randomseed((GetTime and GetTime() or 1) * 1000)
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffOctoThanks|r: " .. message)
end

local function Trim(value)
    return string.gsub(value or "", "^%s*(.-)%s*$", "%1")
end

local function NormalizeIgnoredBuff(value)
    value = Trim(value)
    if value == "" then return nil end
    local id = tonumber(value)
    if id then return "id:" .. math.floor(id), tostring(math.floor(id)) end
    return "name:" .. string.lower(value), value
end

local function IsIgnoredBuff(spellId, spellName)
    if type(spellId) == "number" and db.ignoredBuffs["id:" .. spellId] then return true end
    if type(spellName) == "string" and db.ignoredBuffs["name:" .. string.lower(spellName)] then return true end
    return false
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

local function ShouldSkipGroupWhisper(name, groupEvent)
    return db.channel == "WHISPER" and db.skipGroupWhispers
        and (groupEvent or IsGroupMember(name))
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

local function ChooseEmote()
    if db.emoteStyle ~= "RANDOM" then return "THANK" end
    local index
    repeat
        index = math.random(1, table.getn(POSITIVE_EMOTES))
    until table.getn(POSITIVE_EMOTES) == 1 or POSITIVE_EMOTES[index] ~= lastEmote
    lastEmote = POSITIVE_EMOTES[index]
    return lastEmote
end

local function SendThankYou(name, spellName, groupEvent)
    if not db.enabled or not IsUsablePlayerName(name)
        or ShouldSkipGroupWhisper(name, groupEvent) then
        return
    end

    local now = GetTime()
    if lastThanked[name] and now - lastThanked[name] < db.cooldown then
        return
    end

    lastThanked[name] = now
    if db.channel == "EMOTE" then
        if type(DoEmote) ~= "function" or not pcall(DoEmote, ChooseEmote(), name) then
            Print("Thank emote unavailable or blocked by client.")
        end
        return
    end
    local target = db.channel == "WHISPER" and name or nil
    SendChatMessage(BuildMessage(spellName), db.channel, nil, target)
end

local function QueueThankYou(name, spellName, spellId, groupEvent)
    if not db.enabled or not IsUsablePlayerName(name)
        or IsIgnoredBuff(spellId, spellName) then
        return
    end

    local now = GetTime()
    if lastThanked[name] and now - lastThanked[name] < db.cooldown then
        return
    end

    pending[name] = {
        spellName = spellName,
        groupEvent = groupEvent,
        sendAt = now + db.delay,
    }
end

frame:SetScript("OnUpdate", function()
    local now = GetTime()
    local name, item

    for name, item in pairs(pending) do
        if now >= item.sendAt then
            pending[name] = nil
            SendThankYou(name, item.spellName, item.groupEvent)
        end
    end
end)

local function HandleSpellChat(message, groupEvent)
    -- Chat messages do not include duration. Prefer Nampower's aura event
    -- when available so short HoTs such as Renew cannot trigger a reply.
    if auraEventsAvailable then
        return
    end
    local caster, spellName = ParseSpellLogMessage(message)
    if caster then
        QueueThankYou(caster, spellName, nil, groupEvent)
    end
end

frame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
frame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"
        or event == "CHAT_MSG_SPELL_PARTY_BUFF" then
        HandleSpellChat(arg1, event == "CHAT_MSG_SPELL_PARTY_BUFF")
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
            QueueThankYou(casterName, spellName, spellId, IsGroupMember(casterName))
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
    elseif command == "channel" or command == "mode" then
        local channel = string.upper(rest)
        if channel == "SAY" or channel == "WHISPER" or channel == "EMOTE" then
            if db.channel ~= channel then pending = {} end
            db.channel = channel
            Print("thank-you channel: " .. string.lower(channel) .. ".")
        else
            Print("Use /ot mode say | whisper | emote")
        end
    elseif command == "message" and rest ~= "" then
        if rest == "default" or rest == "random" then
            db.message = DEFAULT_MESSAGE
            Print("message rotation restored (28 variations).")
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
    elseif command == "groupwhisper" and (rest == "on" or rest == "off") then
        db.skipGroupWhispers = rest == "off"
        pending = {}
        Print("group whispers: " .. (db.skipGroupWhispers and "off" or "on") .. ".")
    elseif command == "emotes" and (rest == "random" or rest == "thank") then
        db.emoteStyle = rest == "random" and "RANDOM" or "THANK"
        pending = {}
        Print("emote style: " .. rest .. ".")
    elseif command == "ignore" then
        local action, value = string.match(rest, "^(%S+)%s*(.-)%s*$")
        action = string.lower(action or "")
        if action == "add" then
            local key, label = NormalizeIgnoredBuff(value)
            if key then db.ignoredBuffs[key] = label; Print("ignoring buff: " .. label .. ".")
            else Print("Use /ot ignore add <spell name or spell ID>.") end
        elseif action == "remove" then
            local key, label = NormalizeIgnoredBuff(value)
            if key and db.ignoredBuffs[key] then db.ignoredBuffs[key] = nil; Print("no longer ignoring: " .. label .. ".")
            else Print("That buff is not in the ignore list.") end
        elseif action == "clear" then
            db.ignoredBuffs = {}; Print("buff ignore list cleared.")
        elseif action == "list" then
            local count = 0
            for _, label in pairs(db.ignoredBuffs) do count = count + 1; Print("ignored: " .. label) end
            if count == 0 then Print("buff ignore list is empty.") end
        else Print("Use /ot ignore add|remove|list|clear <spell name or spell ID>.") end
    elseif command == "gui" or command == "options" then
        if OpenOctoThanksOptions then OpenOctoThanksOptions() end
    else
        Print("/ot on | off")
        Print("/ot mode say | whisper | emote   (default: whisper; channel is an alias)")
        Print("/ot message default   (restore rotating messages)")
        Print("/ot message <text>   (use one fixed message; %s = spell name)")
        Print("Use %s in the message to include the spell name.")
        Print("/ot cooldown <seconds>   /ot delay <seconds>")
        Print("/ot group on | off   /ot groupwhisper on | off")
        Print("/ot emotes thank | random   /ot ignore add|remove|list|clear <name or ID>")
        Print("/ot gui   (also available from the minimap button)")
        Print("Current: " .. (db.enabled and "enabled" or "disabled")
            .. ", channel " .. string.lower(db.channel)
            .. ", cooldown " .. db.cooldown .. "s, delay " .. db.delay .. "s")
    end
end

local optionsFrame

local function OptionsLabel(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then label:SetWidth(width) end
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function OptionsButton(parent, text, x, y, width, height, handler)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetWidth(width or 100)
    button:SetHeight(height or 24)
    button:SetText(text)
    button:SetScript("OnClick", handler)
    return button
end

local function OptionsCheck(parent, text, x, y, handler)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetScript("OnClick", handler)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)
    return check
end

local function OptionsEdit(parent, x, y, width, height)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetWidth(width)
    edit:SetHeight(height or 24)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontHighlight")
    return edit
end

local function RefreshOptions()
    if not optionsFrame then return end
    optionsFrame.enabled:SetChecked(db.enabled)
    optionsFrame.grouped:SetChecked(db.includeGroup)
    optionsFrame.groupWhisper:SetChecked(db.skipGroupWhispers)
    optionsFrame.randomEmotes:SetChecked(db.emoteStyle == "RANDOM")
    optionsFrame.delay:SetText(tostring(db.delay))
    optionsFrame.cooldown:SetText(tostring(db.cooldown))
    optionsFrame.message:SetText(db.message == DEFAULT_MESSAGE and "" or (db.message or ""))
    optionsFrame.modeText:SetText("Mode: " .. string.lower(db.channel))
    optionsFrame.status:SetText("Saved automatically. Current mode: " .. string.lower(db.channel)
        .. "; delay: " .. db.delay .. "s; cooldown: " .. db.cooldown .. "s.")
    local ignored = {}
    for _, label in pairs(db.ignoredBuffs or {}) do ignored[#ignored + 1] = label end
    table.sort(ignored, function(a, b) return string.lower(a) < string.lower(b) end)
    optionsFrame.ignoreList:SetText(#ignored == 0 and "Ignored buffs: none" or "Ignored buffs: " .. table.concat(ignored, ", "))
end

local function CommitOptionsNumber(edit, minimum, maximum, field, label)
    local value = tonumber(edit:GetText())
    if not value or value < minimum or value > maximum then
        RefreshOptions()
        Print("Use " .. minimum .. "-" .. maximum .. " for " .. label .. ".")
        return
    end
    db[field] = field == "delay" and math.floor(value * 10 + 0.5) / 10 or math.floor(value)
    pending = {}
    RefreshOptions()
end

local function CreateOptions()
    local f = CreateFrame("Frame", "OctoThanksOptions", UIParent)
    f:SetWidth(500)
    f:SetHeight(610)
    f:SetPoint("CENTER")
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if type(f.SetBackdrop) == "function" then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = {left = 11, right = 11, top = 11, bottom = 11},
        })
        if f.SetBackdropColor then f:SetBackdropColor(0, 0, 0, 0.95) end
    else
        local background = f:CreateTexture(nil, "BACKGROUND")
        background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
        background:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
        background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
        f.background = background
    end
    f:SetScript("OnMouseDown", function() f:StartMoving() end)
    f:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -18)
    title:SetText("OctoThanks")
    local version = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
    version:SetText("OctoWoW/TurtleWoW options")

    OptionsButton(f, "X", 452, -18, 28, 24, function() f:Hide() end)
    f.status = OptionsLabel(f, "", 20, -62, 450)
    f.enabled = OptionsCheck(f, "Enable automatic thank-yous", 20, -92, function(button)
        db.enabled = button:GetChecked() and true or false
        pending = {}
        RefreshOptions()
    end)
    f.grouped = OptionsCheck(f, "Allow thank-yous while grouped", 20, -124, function(button)
        db.includeGroup = button:GetChecked() and true or false
        pending = {}
        RefreshOptions()
    end)
    f.groupWhisper = OptionsCheck(f, "Do not whisper party/raid buff casters", 20, -156, function(button)
        db.skipGroupWhispers = button:GetChecked() and true or false
        pending = {}
        RefreshOptions()
    end)
    f.randomEmotes = OptionsCheck(f, "Use random positive emotes instead of THANK", 20, -188, function(button)
        db.emoteStyle = button:GetChecked() and "RANDOM" or "THANK"
        pending = {}
        RefreshOptions()
    end)

    f.modeText = OptionsLabel(f, "", 20, -225, 180)
    OptionsButton(f, "Whisper", 210, -218, 90, 24, function()
        if db.channel ~= "WHISPER" then pending = {} end
        db.channel = "WHISPER"
        RefreshOptions()
    end)
    OptionsButton(f, "Say", 310, -218, 90, 24, function()
        if db.channel ~= "SAY" then pending = {} end
        db.channel = "SAY"
        RefreshOptions()
    end)
    OptionsButton(f, "Emote", 410, -218, 75, 24, function()
        if db.channel ~= "EMOTE" then pending = {} end
        db.channel = "EMOTE"
        RefreshOptions()
    end)

    OptionsLabel(f, "Reply delay (seconds)", 20, -266, 170)
    f.delay = OptionsEdit(f, 190, -258, 70, 24)
    f.delay:SetScript("OnEnterPressed", function(edit)
        CommitOptionsNumber(edit, 0, 60, "delay", "delay")
        edit:ClearFocus()
    end)
    OptionsLabel(f, "Cooldown per caster (seconds)", 280, -266, 170)
    f.cooldown = OptionsEdit(f, 450, -258, 35, 24)
    f.cooldown:SetScript("OnEnterPressed", function(edit)
        CommitOptionsNumber(edit, 0, 3600, "cooldown", "cooldown")
        edit:ClearFocus()
    end)

    OptionsLabel(f, "Custom whisper (blank restores rotating replies; %s = buff name)", 20, -306, 450)
    f.message = OptionsEdit(f, 20, -330, 350, 24)
    OptionsButton(f, "Save message", 380, -330, 105, 24, function()
        local text = Trim(f.message:GetText())
        if text == "" or string.lower(text) == "random" or string.lower(text) == "default" then
            db.message = DEFAULT_MESSAGE
        elseif string.len(text) <= 255 and not string.find(text, "[\r\n|]") then
            db.message = text
        else
            Print("Message must be 1-255 characters and contain no line breaks or |.")
        end
        RefreshOptions()
    end)

    OptionsLabel(f, "Ignored buffs (enter a spell name or spell ID)", 20, -374, 400)
    f.ignoreInput = OptionsEdit(f, 20, -398, 230, 24)
    OptionsButton(f, "Add", 260, -398, 65, 24, function()
        local key, label = NormalizeIgnoredBuff(f.ignoreInput:GetText())
        if key then db.ignoredBuffs[key] = label; f.ignoreInput:SetText(""); pending = {}; RefreshOptions()
        else Print("Enter a spell name or spell ID first.") end
    end)
    OptionsButton(f, "Remove", 330, -398, 70, 24, function()
        local key, label = NormalizeIgnoredBuff(f.ignoreInput:GetText())
        if key and db.ignoredBuffs[key] then db.ignoredBuffs[key] = nil; f.ignoreInput:SetText(""); pending = {}; RefreshOptions()
        else Print("That buff is not in the ignore list.") end
    end)
    OptionsButton(f, "Clear", 405, -398, 80, 24, function()
        db.ignoredBuffs = {}
        pending = {}
        RefreshOptions()
    end)
    f.ignoreList = OptionsLabel(f, "", 20, -432, 465)
    f.ignoreList:SetHeight(55)

    OptionsButton(f, "Reset defaults", 20, -520, 120, 26, function()
        db.enabled = true
        db.channel = "WHISPER"
        db.includeGroup = true
        db.skipGroupWhispers = false
        db.emoteStyle = "THANK"
        db.delay = DEFAULT_DELAY
        db.cooldown = DEFAULT_COOLDOWN
        db.message = DEFAULT_MESSAGE
        db.ignoredBuffs = {}
        pending = {}
        RefreshOptions()
    end)
    OptionsButton(f, "Close", 385, -520, 100, 26, function() f:Hide() end)
    f:SetScript("OnShow", RefreshOptions)
    return f
end

OpenOctoThanksOptions = function()
    if not optionsFrame then optionsFrame = CreateOptions() end
    RefreshOptions()
    optionsFrame:Show()
end

local minimapButton
local minimap = Minimap or MinimapCluster
if minimap then
    minimapButton = CreateFrame("Button", "OctoThanksMinimapButton", minimap)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetPoint("TOPRIGHT", minimap, "TOPRIGHT", -4, -4)
    minimapButton:SetNormalTexture("Interface\\AddOns\\OctoThanks\\OctoThanksIcon-150")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetScript("OnClick", function()
        if OpenOctoThanksOptions then OpenOctoThanksOptions() end
    end)
    minimapButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("OctoThanks")
        GameTooltip:AddLine("Click to open options.", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    minimapButton:Show()
end

Print("loaded. Type /ot for settings or /ot gui for the options window.")
