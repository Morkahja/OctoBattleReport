local R=OctoBattleReport
local gold={1,.76,.34}
local colors={Overview={.90,.68,.30},Damage={.93,.48,.25},Defense={.35,.64,.91},Healing={.34,.80,.57},Casts={.64,.53,.94},Effects={.90,.65,.31},Recovery={.35,.80,.78}}
local function text(parent,size,x,y,value,color)
  local f=parent:CreateFontString(nil,"OVERLAY")
  f:SetFont("Fonts\\FRIZQT__.TTF",size)
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  f:SetJustifyH("LEFT"); f:SetText(value or "")
  f:SetTextColor(unpack(color or {.85,.87,.90}))
  return f
end
local function panel(parent,x,y,w,h,name)
  local f=CreateFrame("Frame",name,parent)
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); f:SetWidth(w); f:SetHeight(h)
  f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  f:SetBackdropColor(.065,.078,.10,.98); f:SetBackdropBorderColor(.18,.20,.24,1)
  return f
end
local function button(parent,label,x,y,w,fn)
  local b=CreateFrame("Button",nil,parent)
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); b:SetWidth(w); b:SetHeight(25)
  b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  b:SetBackdropColor(.11,.13,.17,1); b:SetBackdropBorderColor(.25,.28,.32,1)
  b.label=text(b,11,0,0,label)
  b.label:ClearAllPoints(); b.label:SetPoint("CENTER",b,"CENTER",0,0)
  b:SetScript("OnClick",fn)
  b:SetScript("OnEnter",function() this:SetBackdropBorderColor(1,.76,.34,1) end)
  b:SetScript("OnLeave",function() this:SetBackdropBorderColor(.25,.28,.32,1) end)
  return b
end
function R.Number(n)
  n=n or 0
  if n>=1000000 then return string.format("%.2fm",n/1000000) end
  if n>=10000 then return string.format("%.1fk",n/1000) end
  if n~=math.floor(n) then return string.format("%.1f",n) end
  return tostring(math.floor(n+.5))
end
local function tooltip(a)
  GameTooltip:SetOwner(this,"ANCHOR_RIGHT")
  GameTooltip:AddLine(a.name,1,.78,.38)
  GameTooltip:AddLine("Events: "..R.Number(a.count).."   Amount: "..R.Number(a.amount),.85,.88,.93)
  GameTooltip:AddLine("Direct hits: "..R.Number(a.hits).."   Ticks: "..R.Number(a.ticks).."   Crits: "..R.Number(a.crits),.85,.88,.93)
  GameTooltip:AddLine("Avoided: "..R.Number(a.misses).."   Largest observed: "..R.Number(a.max),.85,.88,.93)
  if a.casts>0 then GameTooltip:AddLine("Recorded casts: "..R.Number(a.casts),.75,.70,1) end
  for outcome,n in pairs(a.outcomes or {}) do GameTooltip:AddLine(outcome..": "..R.Number(n),.70,.80,.95) end
  if R.view==-1 then GameTooltip:AddLine("Counts and amounts are per-fight averages; largest is the maximum across fights.",1,.78,.38,1) end
  if R.tab=="Recovery" then
    local f=R.GetFight(); local duration=f and (f.isAverage and f.recoveryDuration or R.Duration(f)) or 0
    GameTooltip:AddLine("Mean per update: "..R.Number(a.count>0 and a.amount/a.count or 0).."   Per 5s of fight: "..R.Number(duration>0 and a.amount*5/duration or 0),.65,.85,.82)
    GameTooltip:AddLine("Observed fight-wide rate, not an item's MP5 stat or a measured tick interval.",.65,.75,.80,1)
  end
  if a.source then GameTooltip:AddLine("Source: "..a.source,1,.78,.38) end
  if a.detail then GameTooltip:AddLine(a.detail,.65,.71,.80,1) end
  GameTooltip:Show()
end
function R.CreateUI()
  local w=panel(UIParent,0,0,720,652,"OctoBattleReportWindow")
  if UISpecialFrames then table.insert(UISpecialFrames,"OctoBattleReportWindow") end
  R.window=w
  w:SetFrameStrata("DIALOG"); w:SetMovable(true); w:EnableMouse(true); w:SetClampedToScreen(true)
  w:ClearAllPoints()
  if R.db.x and R.db.y then w:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",R.db.x,R.db.y)
  else w:SetPoint("CENTER",UIParent,"CENTER",0,0) end
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart",function() this:StartMoving() end)
  w:SetScript("OnDragStop",function() this:StopMovingOrSizing(); R.db.x=this:GetLeft(); R.db.y=this:GetTop() end)
  w:SetBackdropColor(.035,.045,.065,.98)
  text(w,19,22,-20,"OCTO  /  BATTLE REPORT",gold)
  w.subtitle=text(w,11,23,-48,"Your fight, at a glance.",{.55,.61,.69})
  button(w,"X",674,-16,26,function() w:Hide() end)
  button(w,"Live / Latest",22,-72,104,function() R.view=0; R.offset=0; R.Refresh() end)
  w.previous=button(w,"<",134,-72,28,function() R.Browse(-1); R.Refresh() end)
  w.next=button(w,">",170,-72,28,function() R.Browse(1); R.Refresh() end)
  w.status=text(w,10,209,-79,"Waiting for combat",gold); w.status:SetWidth(273)
  w.averageButton=button(w,"Average",489,-72,86,function() R.view=-1; R.offset=0; R.Refresh() end)
  w.resetAverage=button(w,"Reset average",583,-72,115,function() R.ResetAverage(); R.Refresh() end)
  w.cards={}
  for i,label in ipairs({"DAMAGE DEALT","DAMAGE TAKEN / AVOIDANCE","HEALING DONE"}) do
    local c=panel(w,22+(i-1)*229,-110,218,84)
    text(c,9,12,-11,label,{.57,.63,.71})
    c.value=text(c,24,12,-29,"0",i==1 and colors.Damage or (i==2 and colors.Defense or colors.Healing))
    c.sub=text(c,10,112,-46,"0 / sec",{.65,.70,.76})
    c.footer=text(c,9,12,-65,"",{.72,.76,.82}); c.footer:SetWidth(196); c.footer:SetHeight(12)
    w.cards[i]=c
  end
  for i,label in ipairs({"RESOURCES USED","RESOURCES RECOVERED"}) do
    local section=CreateFrame("Frame",nil,w)
    section:SetPoint("TOPLEFT",w,"TOPLEFT",22+(i-1)*350,-210)
    section:SetWidth(326); section:SetHeight(48); section:EnableMouse(true)
    section.recovered=i==2
    text(section,10,0,-2,label,i==2 and colors.Recovery or gold)
    local values=text(section,11,0,-25,""); values:SetWidth(326); values:SetHeight(16)
    if i==1 then w.metrics=values else w.recovered=values end
    section:SetScript("OnEnter",function()
      GameTooltip:SetOwner(this,"ANCHOR_RIGHT")
      GameTooltip:AddLine(this.recovered and "Resources recovered (observed)" or "Resources used (observed)",1,.78,.38)
      GameTooltip:AddLine(this.recovered and "Adds positive updates: mana restored, rage generated and energy regenerated, including ability/item gains. Spending does not subtract from this total." or "Adds resource decreases during the fight; gains do not subtract from the total. Includes drains.",.75,.80,.86,1)
      GameTooltip:AddLine("Simultaneous gains and costs can mask each other. Active resource pool only. Average shows per-fight values; see Recovery for details and other resource types.",.75,.80,.86,1)
      GameTooltip:Show()
    end)
    section:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  w.chart=panel(w,22,-274,676,65)
  w.chart.label=text(w.chart,9,8,-6,"ACTIVITY  |  damage dealt / taken",{.52,.58,.66})
  w.chart.average=text(w.chart,12,8,-31,"",{.75,.80,.87})
  w.bars={}
  for i=1,60 do
    local pair={}
    for j=1,2 do
      local b=w.chart:CreateTexture(nil,"ARTWORK")
      b:SetTexture("Interface\\Buttons\\WHITE8X8"); b:SetVertexColor(unpack(j==1 and colors.Damage or colors.Defense))
      b:SetPoint("BOTTOMLEFT",w.chart,"BOTTOMLEFT",8+(i-1)*11+(j-1)*4,5)
      b:SetWidth(4); b:SetHeight(1); pair[j]=b
    end
    w.bars[i]=pair
  end
  w.tabs={}
  for i,name in ipairs({"Overview","Damage","Defense","Healing","Casts","Effects","Recovery"}) do
    local b=button(w,name,22+(i-1)*97,-353,94,function() R.tab=this.tab; R.offset=0; R.Refresh() end)
    b.tab=name; w.tabs[name]=b
  end
  w.heading=text(w,10,23,-391,"ABILITY / EFFECT",{.57,.63,.71})
  w.column=text(w,10,447,-391,"",{.57,.63,.71})
  w.rows={}
  for i=1,7 do
    local b=CreateFrame("Button",nil,w)
    b:SetPoint("TOPLEFT",w,"TOPLEFT",22,-410-(i-1)*27); b:SetWidth(676); b:SetHeight(24)
    b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.bg:SetAllPoints(b); b.bg:SetVertexColor(.09,.11,.14,1)
    b.bar=b:CreateTexture(nil,"BORDER"); b.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.bar:SetPoint("TOPLEFT",b,"TOPLEFT",0,0); b.bar:SetHeight(24)
    b.name=text(b,11,8,-6,""); b.name:SetWidth(407); b.name:SetHeight(14)
    b.value=text(b,11,425,-6,""); b.value:SetWidth(239); b.value:SetHeight(14); b.value:SetJustifyH("RIGHT")
    b:SetScript("OnEnter",function() if this.data then tooltip(this.data) end end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    w.rows[i]=b
  end
  w.empty=text(w,12,34,-426,"Fight reports appear here after your first encounter.",{.62,.67,.74})
  w.empty:SetWidth(640)
  w.note=text(w,10,23,-608,""); w.note:SetWidth(500); w.note:SetHeight(32)
  w.page=text(w,10,525,-616,"",{.57,.63,.71})
  button(w,"<",612,-606,26,function() R.offset=math.max(0,R.offset-7); R.Refresh() end)
  button(w,">",646,-606,26,function() R.offset=math.min(math.max(0,(R.rowCount or 0)-7),R.offset+7); R.Refresh() end)
  w:EnableMouseWheel(true)
  w:SetScript("OnMouseWheel",function() R.offset=math.max(0,math.min(math.max(0,(R.rowCount or 0)-7),R.offset-arg1)); R.Refresh() end)
  w.sort=button(w,"Sort: total",577,-385,120,function() R.sortCount=not R.sortCount; R.offset=0; R.Refresh() end)
  -- A small movable launcher keeps the report one click away.
  local launch=button(UIParent,"Battle Report",0,0,112,function() if w:IsShown() then w:Hide() else w:Show(); R.Refresh() end end)
  launch:ClearAllPoints()
  if R.db.lx and R.db.ly then launch:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",R.db.lx,R.db.ly)
  else launch:SetPoint("TOP",UIParent,"TOP",0,-90) end
  launch:SetMovable(true); launch:SetClampedToScreen(true); launch:RegisterForDrag("LeftButton")
  launch:SetScript("OnDragStart",function() this:StartMoving() end)
  launch:SetScript("OnDragStop",function() this:StopMovingOrSizing(); R.db.lx=this:GetLeft(); R.db.ly=this:GetTop() end)
  R.launcher=launch
  if R.db.hideLauncher then launch:Hide() end
  w:Hide()
end
function R.Refresh()
  local w,f=R.window,R.GetFight()
  if not w then return end
  for name,b in pairs(w.tabs) do b.label:SetTextColor(unpack(name==R.tab and gold or {.67,.72,.79})) end
  local seconds=f and R.Duration(f) or 0
  w.subtitle:SetText(f and f.title or "Your fight, at a glance.")
  w.status:SetText(f and string.format("%s  |  %s  |  %d:%02d",f==R.current and "LIVE" or ("SAVED "..(R.view==0 and 1 or R.view).."/"..table.getn(R.history)),f.stamp,math.floor(seconds/60),math.floor(math.mod(seconds,60))) or "Waiting for combat")
  if R.view==-1 then
    w.resetAverage:Show()
    w.status:SetText(string.format("%d / 100 fights  |  avg %d:%02d",f.fights,math.floor(seconds/60),math.floor(math.mod(seconds,60))))
    w.subtitle:SetText("Per-fight averages; rates use total combat time. Completed fights only.")
  else w.resetAverage:Hide() end
  local values={f and f.damage or 0,f and f.taken or 0,f and f.healing or 0}
  for i,c in ipairs(w.cards) do
    c.value:SetText(R.Number(values[i])); c.sub:SetText(R.Number(seconds>0 and values[i]/seconds or 0).." / sec")
  end
  w.cards[1].footer:SetText(string.format("%s hits   %s crits   %s ticks",R.Number(f and f.hits),R.Number(f and f.crits),R.Number(f and f.ticks)))
  w.cards[2].footer:SetText(string.format("%s dodges   %s parries   %s blocks",R.Number(f and f.Dodge),R.Number(f and f.Parry),R.Number(f and f.Block)))
  w.cards[3].footer:SetText(R.Number(f and f.received).." healing received")
  local resourceText,recoveredText="",""
  if f and not f.resources then
    resourceText="Not recorded for this older fight."
    recoveredText=resourceText
  elseif f and f.isAverage and f.fights>0 and f.resourceCoverage==0 then
    resourceText="Not recorded in these fights."
    recoveredText=resourceText
  else
    for _,name in ipairs({"Mana","Rage","Energy"}) do
      local a=f and f.resources and f.resources[name]
      local gap=name=="Mana" and "" or "   "
      resourceText=resourceText..gap..name..": "..R.Number(a and a.spent)
      recoveredText=recoveredText..gap..name..": "..R.Number(a and a.gained)
    end
  end
  w.metrics:SetText(resourceText)
  w.recovered:SetText(recoveredText)
  local peak=1
  w.chart.label:SetText("ACTIVITY  |  orange: dealt / blue: taken  |  "..(f and f.binWidth or 1).." sec per bar")
  if f and f.isAverage then
    w.chart.label:SetText("AVERAGE PER FIGHT  |  rates = total / total time  |  reset keeps individual reports")
    w.chart.average:SetText(R.Number(f.fights*seconds).." sec combat   |   "..R.Number(f.damage*f.fights).." total damage   |   "..R.Number(f.taken*f.fights).." total taken")
    w.chart.average:Show()
  else w.chart.average:Hide() end
  if f then for _,b in pairs(f.timeline) do peak=math.max(peak,b.damage,b.taken) end end
  for i,pair in ipairs(w.bars) do
    local b=f and f.timeline[i]
    for j,bar in ipairs(pair) do
      local n=b and (j==1 and b.damage or b.taken) or 0
      if n>0 then bar:SetHeight(math.max(1,40*n/peak)); bar:Show() else bar:Hide() end
    end
  end
  local rows={}
  local tab=R.tab
  local count=R.sortCount or tab=="Casts" or tab=="Effects"
  w.sort.label:SetText(count and "Sort: count" or "Sort: total")
  w.heading:SetText(tab=="Defense" and "INCOMING ABILITY / SOURCE" or "ABILITY / EFFECT")
  w.column:SetText("")
  local note="Hover for details. Wheel or arrows to browse."
  if f and (not f.isAverage or f.fights>0) then
    if tab=="Overview" then
      local function metric(name,n,detail)
        local a={name=name,count=n,amount=n,hits=0,ticks=0,crits=0,max=0,casts=0,misses=0,detail=detail}
        table.insert(rows,a)
      end
      if f.isAverage then
        metric("Average fight duration (seconds)",f.duration,"Arithmetic mean of completed fight durations.")
        metric("Mean of individual fight DPS",f.meanDPS,"Each fight contributes equally. Card rates use total damage divided by total combat time.")
      end
      if f.resources then
        for _,name in ipairs({"Mana","Rage","Energy","Focus","Happiness"}) do
          local a=f.resources[name]
          if a then metric(name.." used (observed)",a.spent,"Observed gains: "..R.Number(a.gained)..". Decreases include drains; simultaneous gains may mask costs. Active pool only; form/capacity/death resets excluded.") end
        end
      end
      metric("Direct attack attempts",f.attacks,"Melee and direct spell outcomes, including avoided attacks. Multi-target hits count separately; these are not casts.")
      metric("Damage events received",f.incomingHits,"Includes direct hits and periodic damage ticks.")
      metric("Healing received",f.received,"Logged healing; the old log does not reliably expose overhealing.")
      metric("Damage blocked",f.blocked,"Partial-block amount reported in the log. Full blocks are counted above.")
      metric("Damage absorbed",f.absorbed,"Reported partial absorbs. Fully absorbed hits may have no amount.")
      metric("Damage resisted",f.resisted,"Reported partial resistance; armor reduction is not exposed.")
      metric("Avoided incoming attacks",(f.Dodge or 0)+(f.Parry or 0)+(f.Miss or 0)+(f.Resist or 0)+(f.Absorb or 0)+(f.Immune or 0)+(f.Evade or 0),"Dodge, parry, miss, full resist/absorb, immune and evade. See Defense for source details.")
      note="Personal combat only; pets and totems are not attributed to you."
    else
      local source=tab=="Damage" and f.abilities or tab=="Defense" and f.defense or tab=="Healing" and f.heals or tab=="Casts" and f.casts or tab=="Recovery" and (f.recovery or {}) or f.effects
      for _,a in pairs(source) do table.insert(rows,a) end
      table.sort(rows,function(a,b)
        local av,bv=count and a.count or a.amount,count and b.count or b.amount
        if av==bv then return a.name<b.name end
        return av>bv
      end)
      if tab=="Recovery" then note="Overlapping observations, not additive. Hover for averages and recovery rates."
      elseif tab=="Casts" then note=f.castMode..". Hits and ticks are separate in Damage."
      elseif tab=="Effects" then note="Gains / refreshes are observations, not guaranteed procs. /obr source to label."
      elseif tab=="Defense" then note="Avoided: "..R.Number(f.Miss).." miss / "..R.Number(f.Resist).." resist / "..R.Number(f.Absorb).." absorb / "..R.Number(f.Immune).." immune"
      elseif tab=="Healing" then note="Logged healing, including possible overhealing. Self-heals enter both summary totals." end
    end
  end
  if f and f.isAverage then note="Per fight. Resource coverage: "..f.resourceCoverage.."/"..f.fights.."; recovery: "..f.recoveryCoverage.."/"..f.fights..". Recovery rows overlap." end
  R.rowCount=table.getn(rows)
  R.offset=math.min(R.offset,math.max(0,R.rowCount-7))
  local maxValue=1
  local rowTotal=0
  for _,a in ipairs(rows) do maxValue=math.max(maxValue,count and a.count or a.amount); rowTotal=rowTotal+a.amount end
  for i,b in ipairs(w.rows) do
    local a=rows[i+R.offset]
    if a then
      b.data=a; b:Show()
      b.name:SetText(a.name)
      if tab=="Overview" then b.value:SetText(R.Number(a.amount))
      elseif tab=="Casts" then b.value:SetText(R.Number(a.count).." casts  |  "..R.Number(f.abilities[a.name] and f.abilities[a.name].amount or 0).." dmg")
      elseif tab=="Effects" then b.value:SetText(R.Number(a.count).." events"..(a.source and "  |  "..a.source or "  |  source unknown"))
      elseif tab=="Recovery" then b.value:SetText(R.Number(a.count).." updates  |  "..R.Number(a.amount).." recovered")
      else b.value:SetText(R.Number(a.count).." events   |   "..R.Number(a.amount).."   |   "..string.format("%.0f%%",100*a.amount/math.max(1,rowTotal))) end
      b.bar:SetWidth(math.max(1,676*(count and a.count or a.amount)/maxValue))
      local c=colors[tab]; b.bar:SetVertexColor(c[1],c[2],c[3],.21)
    else b.data=nil; b:Hide() end
  end
  if R.rowCount==0 then
    w.empty:SetText(not f and "No fight recorded yet. Leave this window open or come back after combat." or tab=="Casts" and "No casts recorded. See the capture mode below; instant casts need Nampower events." or "No personal events recorded in this category.")
    w.empty:Show()
    if f and f.isAverage and f.fights==0 then w.empty:SetText("No completed fights in this average period yet.")
    elseif f and tab=="Recovery" and not f.recovery then w.empty:SetText("Recovery details were not recorded for this older fight.") end
  else w.empty:Hide() end
  w.note:SetText(note)
  w.page:SetText(R.rowCount>0 and ((R.offset+1).."-"..math.min(R.offset+7,R.rowCount).." / "..R.rowCount) or "")
end
SLASH_OCTOBATTLEREPORT1="/obr"
SLASH_OCTOBATTLEREPORT2="/battlereport"
SlashCmdList["OCTOBATTLEREPORT"]=function(msg)
  if not R.db then return end
  local _,_,effect,source=string.find(msg,"^source%s+(.+)%s*=%s*(.+)$")
  if effect then
    effect=string.gsub(effect,"%s+$",""); source=string.gsub(source,"%s+$","")
    R.db.sources[effect]=source
    DEFAULT_CHAT_FRAME:AddMessage("Octo Battle Report: labeled "..effect.." as "..source.." for future observations.")
  elseif msg=="source" then
    DEFAULT_CHAT_FRAME:AddMessage("Use /obr source Effect name = Item or enchantment name. Labels describe the source; they do not prove proc counts.")
  elseif msg=="button" then
    R.db.hideLauncher=not R.db.hideLauncher
    if R.db.hideLauncher then R.launcher:Hide() else R.launcher:Show() end
  elseif msg=="position" then
    R.window:ClearAllPoints(); R.window:SetPoint("CENTER",UIParent,"CENTER",0,0)
    R.launcher:ClearAllPoints(); R.launcher:SetPoint("TOP",UIParent,"TOP",0,-90)
    R.db.x=nil; R.db.y=nil; R.db.lx=nil; R.db.ly=nil
  elseif msg=="last" then R.view=1; R.offset=0; R.window:Show(); R.Refresh()
  else
    if R.window:IsShown() then R.window:Hide() else R.window:Show(); R.Refresh() end
  end
end
