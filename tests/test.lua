local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function make(saved)
    local h={now=100,sent={}}
    local e=setmetatable({OctoThanksDB=saved,SlashCmdList={}}, {__index=_G})
    e.DEFAULT_CHAT_FRAME={AddMessage=function() end}
    e.GetTime=function() return h.now end
    e.UnitName=function(unit) return unit=="player" and "Self" or "Friend" end
    e.UnitIsPlayer=function(guid) return guid~="NPC" end
    e.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,event,f) h[event]=f end} end
    e.SendChatMessage=function(text,channel,_,target) h.sent[#h.sent+1]={text=text,channel=channel,target=target} end
    e.Nampower={HasMinimumVersion=function() return true end,RegisterEvent=function(_,_,f) h.aura=f end}
    local chunk=assert(loadfile("OctoThanks.lua")); setfenv(chunk,e); chunk()
    function h:cmd(text) e.SlashCmdList.OCTOTHANKS(text) end
    function h:buff(duration,guid)
        self.aura(1,guid or "FriendGuid","self",nil,nil,nil,nil,duration or 3600000)
        self.now=self.now+2; self.OnUpdate()
    end
    h.env=e; return h
end
local h=make(); h:buff(); eq(h.sent[1].channel,"SAY"); eq(h.sent[1].target,nil)
h:cmd("channel whisper"); h:buff(); eq(#h.sent,1); h.now=h.now+61; h:buff()
eq(h.sent[2].channel,"WHISPER"); eq(h.sent[2].target,"Friend")
h:cmd("channel raid"); eq(h.env.OctoThanksDB.channel,"WHISPER")
local r=make(h.env.OctoThanksDB); r:buff(); eq(r.sent[1].channel,"WHISPER")
r:cmd("channel SaY"); r.now=r.now+61; r:buff(); eq(r.sent[2].channel,"SAY"); eq(r.sent[2].target,nil)
for _,d in ipairs({0,15000,120000,120001}) do h=make(); h:buff(d); eq(#h.sent,d>120000 and 1 or 0) end
h=make(); h:buff(3600000,"player"); eq(#h.sent,0)
h=make(); h:buff(3600000,"NPC"); eq(#h.sent,0)
h=make(); h:cmd("off"); h:buff(); eq(#h.sent,0)
h=make({channel="GUILD"}); eq(h.env.OctoThanksDB.channel,"SAY")
h=make(); local replies={}; local previous
for i=1,400 do
    h.now=h.now+61; h:buff(); local text=h.sent[#h.sent].text
    assert(text~=previous); previous=text; replies[text]=true
end
local count=0; for _ in pairs(replies) do count=count+1 end; eq(count,28)
print("PASS OctoThanks channel/filter/cooldown/reload/28-reply tests")
