local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function make(saved)
    saved = saved or {}
    local useDefaultDelay = saved.__defaultDelay
    saved.__defaultDelay = nil
    if not useDefaultDelay and saved.delay == nil then saved.delay = 2 end
    local h={now=100,sent={},emotes={}}
    local e=setmetatable({OctoThanksDB=saved,SlashCmdList={}}, {__index=_G})
    e.DEFAULT_CHAT_FRAME={AddMessage=function() end}
    e.GetTime=function() return h.now end
    e.GetNumPartyMembers=function() return h.partyName and 1 or 0 end
    e.GetNumRaidMembers=function() return 0 end
    e.UnitName=function(unit)
        if unit=="player" then return "Self" end
        if unit=="party1" and h.partyName then return h.partyName end
        return "Friend"
    end
    e.UnitIsPlayer=function(guid) return guid~="NPC" end
    e.GetSpellRecField=function() return "Blessing of Might" end
    e.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,event,f) h[event]=f end} end
    e.SendChatMessage=function(text,channel,_,target) h.sent[#h.sent+1]={text=text,channel=channel,target=target} end
    e.DoEmote=function(token,target)
        h.emotes[#h.emotes+1]={token=token,target=target}
        if h.emoteError then error("blocked") end
    end
    e.Nampower={HasMinimumVersion=function() return true end,RegisterEvent=function(_,_,f) h.aura=f end}
    local chunk=assert(loadfile("OctoThanks.lua")); setfenv(chunk,e); chunk()
    function h:cmd(text) e.SlashCmdList.OCTOTHANKS(text) end
    function h:buff(duration,guid)
        self.aura(1,guid or "FriendGuid","self",nil,nil,nil,nil,duration or 3600000)
        self.now=self.now+2; self.OnUpdate()
    end
    h.env=e; return h
end
local h=make(); eq(h.env.OctoThanksDB.channel,"WHISPER"); h:buff(); eq(h.sent[1].channel,"WHISPER"); eq(h.sent[1].target,"Friend")
h:cmd("channel whisper"); h:buff(); eq(#h.sent,1); h.now=h.now+61; h:buff()
eq(h.sent[2].channel,"WHISPER"); eq(h.sent[2].target,"Friend")
h:cmd("channel raid"); eq(h.env.OctoThanksDB.channel,"WHISPER")
local r=make(h.env.OctoThanksDB); r:buff(); eq(r.sent[1].channel,"WHISPER")
r:cmd("channel SaY"); r.now=r.now+61; r:buff(); eq(r.sent[2].channel,"SAY"); eq(r.sent[2].target,nil)
for _,d in ipairs({0,15000,120000,120001}) do h=make(); h:buff(d); eq(#h.sent,d>120000 and 1 or 0) end
h=make(); h:buff(3600000,"player"); eq(#h.sent,0)
h=make(); h:buff(3600000,"NPC"); eq(#h.sent,0)
h=make(); h:cmd("off"); h:buff(); eq(#h.sent,0)
h=make({channel="GUILD"}); eq(h.env.OctoThanksDB.channel,"WHISPER")
h=make({channel="SAY"}); eq(h.env.OctoThanksDB.channel,"SAY"); h:buff(); eq(h.sent[1].channel,"SAY")
h=make({channel="WHISPER"}); eq(h.env.OctoThanksDB.channel,"WHISPER"); h:buff(); eq(h.sent[1].channel,"WHISPER")
h=make({channel="EMOTE"}); eq(h.env.OctoThanksDB.channel,"EMOTE"); h:buff(); eq(#h.emotes,1)
h=make(); local replies={}; local previous
for i=1,400 do
    h.now=h.now+61; h:buff(); local text=h.sent[#h.sent].text
    assert(text~=previous); previous=text; replies[text]=true
end
local count=0; for _ in pairs(replies) do count=count+1 end; eq(count,28)
print("PASS OctoThanks channel/filter/cooldown/reload/28-reply tests")
h=make(); h:cmd("mode EmOtE"); eq(h.env.OctoThanksDB.channel,"EMOTE")
h=make(h.env.OctoThanksDB); h:buff(); eq(#h.sent,0); eq(#h.emotes,1)
eq(h.emotes[1].token,"THANK"); eq(h.emotes[1].target,"Friend")
h:buff(); eq(#h.emotes,1)
h:cmd("mode whisper"); h:buff(); eq(#h.sent,0)
h.now=h.now+61; h:buff(); eq(h.sent[1].channel,"WHISPER")
h:cmd("mode say"); h.now=h.now+61; h:buff(); eq(h.sent[2].channel,"SAY")
h=make(); h.aura(1,"FriendGuid","self",nil,nil,nil,nil,3600000)
h:cmd("channel emote"); h.now=h.now+2; h.OnUpdate(); eq(#h.sent,0); eq(#h.emotes,0)
for _,d in ipairs({0,15000,120000,120001}) do
    h=make({channel="EMOTE"}); h:buff(d); eq(#h.emotes,d>120000 and 1 or 0); eq(#h.sent,0)
end
h=make({channel="EMOTE"}); h:buff(3600000,"player"); eq(#h.emotes,0)
h=make({channel="EMOTE"}); h:buff(3600000,"NPC"); eq(#h.emotes,0)
h=make({channel="EMOTE"}); h:cmd("off"); h:buff(); eq(#h.emotes,0)
h=make({channel="EMOTE"}); h.emoteError=true; h:buff(); h:buff(); eq(#h.emotes,1); eq(#h.sent,0)
h=make({channel="EMOTE"}); h.env.DoEmote=nil; h:buff(); eq(#h.sent,0)
print("PASS OctoThanks optional targeted emote/filter/cooldown/mode/reload tests")
h=make({__defaultDelay=true}); eq(h.env.OctoThanksDB.delay,5)
h=make({delay=5}); h:buff(); eq(#h.sent,0); h.now=h.now+3; h.OnUpdate(); eq(#h.sent,1)
h=make({skipGroupWhispers=true}); h.partyName="Friend"; h:buff(); eq(#h.sent,0); h.partyName=nil; h.now=h.now+61; h:buff(); eq(#h.sent,1)
h=make(); h:cmd("ignore add Blessing of Might"); h:buff(); eq(#h.sent,0); h:cmd("ignore remove Blessing of Might"); h:cmd("ignore add 1"); h.now=h.now+61; h:buff(); eq(#h.sent,0)
h=make({channel="EMOTE",emoteStyle="RANDOM"}); h:buff(); local allowed={SALUTE=true,BOW=true,WAVE=true,CHEER=true,APPLAUD=true}; assert(allowed[h.emotes[1].token]); eq(h.emotes[1].target,"Friend")
print("PASS OctoThanks delay/group-ignore/ignored-buff/random-emote tests")
