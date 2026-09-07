local R=OctoBattleReport
local rules={}
local trailers={}
-- Compile the client's localized printf strings, retaining positional captures.
local function compile(fmt)
  local pat, order, i, n="", {}, 1, 0
  while i<=string.len(fmt) do
    local c=string.sub(fmt,i,i)
    if c=="%" then
      local tail=string.sub(fmt,i)
      local a,b,index,kind=string.find(tail,"^%%(%d+)%$([sd])")
      if not a then a,b,kind=string.find(tail,"^%%([sd])") end
      if a then
        n=n+1; order[n]=tonumber(index) or n
        pat=pat..(kind=="d" and "(%d+)" or "(.-)"); i=i+b
      else pat=pat.."%%"; i=i+1 end
    else
      if string.find(c,"[%^%$%(%)%%%.%[%]%*%+%-%?]") then pat=pat.."%" end
      pat=pat..c; i=i+1
    end
  end
  return pat,order
end
R.Compile=compile
local function add(key,kind,source,target,spell,value,tick,outcome)
  local fmt=getglobal(key)
  if type(fmt)~="string" then return end
  local p,o=compile(fmt)
  table.insert(rules,{key=key,pattern="^"..p.."$",order=o,kind=kind,source=source,target=target,
    spell=spell,value=value,tick=tick,outcome=outcome,crit=string.find(key,"CRIT")~=nil})
end
local function resolve(v,c) return type(v)=="number" and c[v] or v end
function R.BuildRules()
  rules={}
  trailers={}
  for key,field in pairs({BLOCK_TRAILER="blocked",ABSORB_TRAILER="absorbed",RESIST_TRAILER="resisted",GLANCING_TRAILER="glancing",CRUSHING_TRAILER="crushing",VULNERABLE_TRAILER="vulnerable"}) do
    local fmt=getglobal(key)
    if fmt then table.insert(trailers,{pattern=compile(fmt),field=field}) end
  end
  for _,suffix in ipairs({"SELFSELF","SELFOTHER","OTHERSELF","OTHEROTHER"}) do
    local out=string.sub(suffix,1,4)=="SELF"
    local inc=string.sub(suffix,-4)=="SELF"
    local s=out and "player" or 1
    local t=inc and "player" or (out and 1 or 2)
    for _,prefix in ipairs({"COMBATHIT","COMBATHITSCHOOL","COMBATHITCRIT","COMBATHITCRITSCHOOL"}) do
      add(prefix..suffix,"damage",s,t,"Melee",(out or inc) and 2 or 3)
    end
    for _,prefix in ipairs({"SPELLLOG","SPELLLOGSCHOOL","SPELLLOGCRIT","SPELLLOGCRITSCHOOL","HEALEDCRIT","HEALED"}) do
      local spell=out and 1 or 2
      local target=inc and "player" or (out and 2 or 3)
      local value=(out and inc) and 2 or ((out or inc) and 3 or 4)
      add(prefix..suffix,string.find(prefix,"HEALED") and "heal" or "damage",s,target,spell,value)
    end
    for prefix,reason in pairs({MISSED="Miss",VSDODGE="Dodge",VSPARRY="Parry",VSBLOCK="Block",VSABSORB="Absorb",VSEVADE="Evade",IMMUNE="Immune"}) do
      add(prefix..suffix,"miss",s,t,"Melee",nil,nil,reason)
    end
    for prefix,reason in pairs({SPELLMISS="Miss",SPELLDODGED="Dodge",SPELLPARRIED="Parry",SPELLBLOCKED="Block",SPELLRESIST="Resist",SPELLEVADED="Evade",SPELLIMMUNE="Immune",SPELLLOGABSORB="Absorb"}) do
      add(prefix..suffix,"miss",s,inc and "player" or (out and 2 or 3),out and 1 or 2,nil,nil,reason)
    end
  end
  add("PERIODICAURADAMAGESELFOTHER","damage","player",1,4,2,true)
  add("PERIODICAURADAMAGESELFSELF","damage","player","player",3,1,true)
  add("PERIODICAURADAMAGEOTHERSELF","damage",3,"player",4,1,true)
  add("PERIODICAURADAMAGEOTHEROTHER","damage",4,1,5,2,true)
  add("PERIODICAURAHEALSELFOTHER","heal","player",1,3,2,true)
  -- This string does not identify the caster: record only healing received.
  add("PERIODICAURAHEALOTHERSELF","heal",2,"player",3,1,true)
  add("PERIODICAURAHEALSELFSELF","heal","Unknown","player",2,1,true)
  add("PERIODICAURAHEALOTHEROTHER","heal",3,1,4,2,true)
  add("DAMAGESHIELDSELFOTHER","damage","player",3,"Damage shield",1)
  add("DAMAGESHIELDOTHERSELF","damage",1,"player","Damage shield",2)
  add("DAMAGESHIELDOTHEROTHER","damage",1,4,"Damage shield",2)
  add("SPELLSPLITDAMAGEOTHERSELF","damage",1,"player",2,3)
  add("SPELLSPLITDAMAGESELFOTHER","damage","player",2,1,3)
  for _,kind in ipairs({"DROWNING","FALLING","FATIGUE","FIRE","LAVA","SLIME"}) do
    add("VSENVIRONMENTALDAMAGE_"..kind.."_SELF","damage","Environment","player",kind,1)
  end
  add("POWERGAINSELFSELF","effect","Unknown","player",3,1)
  add("SPELLEXTRAATTACKSSELF","effect","player","player",2,1)
  add("SPELLEXTRAATTACKSSELF_SINGULAR","effect","player","player",2,1)
  add("AURAADDEDSELFHELPFUL","effect","player","player",1)
  add("AURAADDEDSELFHARMFUL","effect","player","player",1)
  -- Spell hits also fit the broad "%s hits ..." melee templates.
  -- Preserve specificity ordering and try all spell templates first.
  local ordered={}
  for _,r in ipairs(rules) do if r.spell~="Melee" then table.insert(ordered,r) end end
  for _,r in ipairs(rules) do if r.spell=="Melee" then table.insert(ordered,r) end end
  rules=ordered
end
function R.Parse(message)
  if type(message)~="string" then return end
  local extra={}
  for _,trailer in ipairs(trailers) do
    local a,b,v=string.find(message,trailer.pattern)
    if a then extra[trailer.field]=tonumber(v) or 1; message=string.gsub(message,trailer.pattern,"") end
  end
  for _,r in ipairs(rules) do
    local a,b,c1,c2,c3,c4,c5=string.find(message,r.pattern)
    if a then
      local raw={c1,c2,c3,c4,c5}; local c={}
      for i,j in ipairs(r.order) do c[j]=raw[i] end
      local s,t=resolve(r.source,c),resolve(r.target,c)
      local player=UnitName("player")
      if s==player then s="player" end
      if t==player then t="player" end
      if s~="player" and t~="player" then return end
      return {kind=r.kind,source=s,target=t,spell=resolve(r.spell,c),amount=tonumber(resolve(r.value,c)) or 0,
        gainResource=r.key=="POWERGAINSELFSELF" and c[2] or nil,
        tick=r.tick,crit=r.crit,outcome=r.outcome,blocked=extra.blocked,absorbed=extra.absorbed,resisted=extra.resisted,
        detail=r.kind=="effect" and r.value and (r.source=="Unknown" and "Resource gains; total = resource restored" or "Extra-attack grants; amount = attacks granted") or nil}
    end
  end
end
local frame=CreateFrame("Frame")
R.events=frame
local channels={"CHAT_MSG_COMBAT_SELF_HITS","CHAT_MSG_COMBAT_SELF_MISSES","CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS","CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES","CHAT_MSG_COMBAT_MISC_INFO",
  "CHAT_MSG_SPELL_SELF_DAMAGE","CHAT_MSG_SPELL_SELF_BUFF","CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF","CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
  "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE","CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS","CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE","CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
  "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE","CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF"}
for _,unit in ipairs({"PARTY","FRIENDLYPLAYER","HOSTILEPLAYER"}) do
  table.insert(channels,"CHAT_MSG_COMBAT_"..unit.."_HITS")
  table.insert(channels,"CHAT_MSG_COMBAT_"..unit.."_MISSES")
  table.insert(channels,"CHAT_MSG_SPELL_"..unit.."_DAMAGE")
  table.insert(channels,"CHAT_MSG_SPELL_"..unit.."_BUFF")
  table.insert(channels,"CHAT_MSG_SPELL_PERIODIC_"..unit.."_DAMAGE")
  table.insert(channels,"CHAT_MSG_SPELL_PERIODIC_"..unit.."_BUFFS")
end
for _,e in ipairs(channels) do frame:RegisterEvent(e) end
for _,e in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_LOGOUT","SPELLCAST_START","SPELLCAST_STOP","SPELLCAST_FAILED","SPELLCAST_INTERRUPTED"}) do frame:RegisterEvent(e) end
local pendingCast, requests={},{}
local function itemName(id)
  if not id or id<=0 then return nil end
  return (GetItemInfo and GetItemInfo(id)) or ("Item #"..id)
end
frame:SetScript("OnEvent",function()
  if event=="ADDON_LOADED" and arg1=="OctoBattleReport" then
    R.Init(); R.BuildRules(); R.CreateUI()
  elseif event=="PLAYER_LOGIN" then
    if GetSpellRecField and GetCVar("NP_EnableSpellGoEvents")=="1" then
      R.enhanced=true
      frame:RegisterEvent("SPELL_CAST_EVENT"); frame:RegisterEvent("SPELL_GO_SELF")
    end
  elseif not R.db then return
  elseif event=="PLAYER_REGEN_DISABLED" then R.Start(GetTime())
  elseif event=="PLAYER_REGEN_ENABLED" then R.ending=GetTime()
  elseif event=="PLAYER_LOGOUT" then R.Finish(GetTime(),true)
  elseif event=="SPELL_CAST_EVENT" then
    if arg1==1 then requests[arg2]=GetTime() else requests[arg2]=nil end
    for id,t in pairs(requests) do if GetTime()-t>60 then requests[id]=nil end end
  elseif event=="SPELL_GO_SELF" then
    local name=GetSpellRecField(arg2,"name") or ("Spell "..tostring(arg2))
    if requests[arg2] and GetTime()-requests[arg2]<60 then
      requests[arg2]=nil
      R.Record({kind="cast",source="player",spell=name,item=itemName(arg1)})
    elseif arg1 and arg1>0 then
      R.Record({kind="effect",source="player",spell=name.." [item trigger]",item=itemName(arg1),detail="Item-triggered spell (server event), separate from aura gains."})
    end
  elseif event=="SPELLCAST_START" then pendingCast={name=arg1,finish=GetTime()+(arg2 or 0)/1000}
  elseif event=="SPELLCAST_FAILED" or event=="SPELLCAST_INTERRUPTED" then pendingCast={}
  elseif event=="SPELLCAST_STOP" then
    if not R.enhanced and pendingCast.name and GetTime()>=pendingCast.finish-.1 then
      R.Record({kind="cast",source="player",spell=pendingCast.name})
    end
    pendingCast={}
  elseif string.sub(event,1,9)=="CHAT_MSG_" then
    local e=R.Parse(arg1)
    if e then R.Record(e) end
  end
end)
local elapsed=0
frame:SetScript("OnUpdate",function()
  elapsed=elapsed+arg1
  if elapsed<.2 then return end
  elapsed=0
  if not R.db then return end
  R.Tick(GetTime())
  if R.window and R.window:IsShown() then R.Refresh() end
end)
