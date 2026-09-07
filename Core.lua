OctoBattleReport = { pending = {}, view = 0, tab = "Overview", offset = 0 }
local R = OctoBattleReport
local function row(t, name)
  if not t[name] then
    t[name] = { name=name, count=0, amount=0, hits=0, ticks=0, crits=0, max=0, casts=0, misses=0, outcomes={} }
  end
  return t[name]
end
R.Row = row
function R.Init()
  if type(OctoBattleReportDB) ~= "table" then OctoBattleReportDB = {} end
  R.db = OctoBattleReportDB
  if R.db.quickReport==nil then R.db.quickReport=true end
  R.db.history = R.db.history or {}
  R.db.sources = R.db.sources or {}
  R.history = R.db.history
  R.db.serial=R.db.serial or 0
  for i=table.getn(R.history),1,-1 do
    if not R.history[i].id then R.db.serial=R.db.serial+1; R.history[i].id=R.db.serial end
  end
end
function R.New(now)
  return { start=now, last=now, duration=0, title="Personal combat", stamp=date("%H:%M"),
    damage=0, taken=0, healing=0, received=0, attacks=0, hits=0, ticks=0, crits=0,
    incoming=0, incomingHits=0, blocked=0, absorbed=0, resisted=0,
    abilities={}, defense={}, heals={}, effects={}, casts={}, enemies={}, resources={}, recovery={},
    timeline={}, binWidth=1, castMode=R.enhanced and "Server-confirmed casts" or "Cast-time completions only" }
end
function R.Start(now)
  if R.EndPrompt then R.EndPrompt() end
  if R.current then R.ending=nil; return end
  R.current=R.New(now)
  if R.view~=-1 then R.view=0; R.offset=0 end
  local pending=R.pending
  R.pending={}
  for _, e in ipairs(pending) do
    if now-e.time <= 2 then R.Record(e, true) end
  end
end
function R.Finish(now, silent)
  local f=R.current
  if not f then return end
  f.duration=math.max(0.1, (now or f.last)-f.start)
  local spent=0
  for _,a in pairs(f.resources or {}) do spent=spent+a.spent end
  if f.damage+f.taken+f.healing+f.received+f.attacks+f.incoming+spent > 0 or next(f.casts) then
    R.db.serial=R.db.serial+1; f.id=R.db.serial
    table.insert(R.history, 1, f)
    while table.getn(R.history)>100 do table.remove(R.history) end
    R.average=nil
  end
  R.current=nil; R.ending=nil; R.pending={}
  if R.view~=-1 then R.view=0 end
  if f.id and not silent and R.ShowPrompt then R.ShowPrompt(f) end
end
function R.Timeline(f, e)
  local age=math.max(0,e.time-f.start)
  while math.floor(age/f.binWidth)>=60 do
    local merged={}
    for i,b in pairs(f.timeline) do
      local j=math.floor((i-1)/2)+1
      merged[j]=merged[j] or {damage=0,taken=0}
      merged[j].damage=merged[j].damage+b.damage
      merged[j].taken=merged[j].taken+b.taken
    end
    f.timeline=merged; f.binWidth=f.binWidth*2
  end
  local i=math.floor(age/f.binWidth)+1
  f.timeline[i]=f.timeline[i] or {damage=0,taken=0}
  if e.source=="player" then f.timeline[i].damage=f.timeline[i].damage+(e.amount or 0) end
  if e.target=="player" then f.timeline[i].taken=f.timeline[i].taken+(e.amount or 0) end
end
function R.Record(e, buffered)
  e.time=e.time or GetTime()
  local hostile=e.kind=="damage" or e.kind=="miss"
  if not R.current then
    if hostile or UnitAffectingCombat("player") then R.Start(e.time)
    elseif not buffered then
      table.insert(R.pending,e)
      while table.getn(R.pending)>24 or (R.pending[1] and e.time-R.pending[1].time>2) do table.remove(R.pending,1) end
      return
    else return end
  end
  local f=R.current
  -- Passive resource ticks must not keep an out-of-combat segment alive.
  if e.kind~="resource" and e.kind~="recovery" then f.last=math.max(f.last,e.time) end
  local out=e.source=="player"
  local incoming=e.target=="player"
  local amount=e.amount or 0
  local name=e.spell or "Melee"
  if hostile then
    local enemy=out and e.target or e.source
    if enemy and enemy~="player" then
      f.enemies[enemy]=(f.enemies[enemy] or 0)+amount
      if f.title=="Personal combat" then f.title=enemy end
    end
    if out then
      local a=row(f.abilities,name)
      a.count=a.count+1; a.amount=a.amount+amount; a.max=math.max(a.max,amount)
      if e.tick then a.ticks=a.ticks+1; f.ticks=f.ticks+1
      else f.attacks=f.attacks+1 end
      if e.kind=="miss" then
        a.misses=a.misses+1; a.outcomes[e.outcome]=(a.outcomes[e.outcome] or 0)+1
      else
        if not e.tick then a.hits=a.hits+1; f.hits=f.hits+1 end
        if e.crit then a.crits=a.crits+1; f.crits=f.crits+1 end
        f.damage=f.damage+amount
      end
    end
    if incoming then
      if not e.tick then f.incoming=f.incoming+1 end
      f.taken=f.taken+amount
      if e.kind=="damage" then f.incomingHits=f.incomingHits+1 end
      local a=row(f.defense,name.." - "..(e.source=="player" and "You" or (e.source or "Environment")))
      a.count=a.count+1; a.amount=a.amount+amount; a.max=math.max(a.max,amount)
      if e.tick then a.ticks=a.ticks+1 elseif e.kind=="damage" then a.hits=a.hits+1 end
      if e.crit then a.crits=a.crits+1 end
      if e.kind=="miss" then
        a.misses=a.misses+1
        a.outcomes[e.outcome]=(a.outcomes[e.outcome] or 0)+1
        f[e.outcome]=(f[e.outcome] or 0)+1
      end
      for _, key in ipairs({"blocked","absorbed","resisted"}) do f[key]=f[key]+(e[key] or 0) end
      if e.blocked and e.blocked>0 then f.Block=(f.Block or 0)+1 end
    end
    if e.kind=="damage" then
      R.Timeline(f,e)
      if out and R.db.sources[name] then
        local a=row(f.effects,name.." [damage]")
        a.count=a.count+1; a.amount=a.amount+amount; a.source=R.db.sources[name]
        a.detail="User-labeled damage events. Multiple hits or ticks can belong to a single proc."
      end
    end
  elseif e.kind=="heal" then
    if out then f.healing=f.healing+amount end
    if incoming then f.received=f.received+amount end
    if incoming then
      local r=row(f.recovery,"Heal log: "..name)
      r.count=r.count+1; r.amount=r.amount+amount; r.max=math.max(r.max,amount)
      if e.tick then r.ticks=r.ticks+1 end
      r.detail="Named healing received, including vampirism when named by the log. May include overhealing. Overlaps observed health recovery; do not add them together."
    end
    local a=row(f.heals,(out and "Done: " or "Received: ")..name)
    a.amount=a.amount+amount; a.count=a.count+1; a.max=math.max(a.max,amount)
    if e.tick then a.ticks=a.ticks+1 else a.hits=a.hits+1 end
    if e.crit then a.crits=a.crits+1 end
  elseif e.kind=="resource" then
    local a=f.resources[e.resource]
    if not a then a={spent=0,gained=0}; f.resources[e.resource]=a end
    a.spent=a.spent+(e.spent or 0); a.gained=a.gained+(e.gained or 0)
    if (e.gained or 0)>0 then
      local r=row(f.recovery,e.resource.." recovered (observed)")
      r.count=r.count+1; r.amount=r.amount+e.gained; r.max=math.max(r.max,e.gained)
      r.detail="Positive resource updates, including regeneration and spell/item gains. Updates can combine several sources; these are not guaranteed individual regeneration ticks."
      if e.resource=="Mana" then
        local label=e.recentSpend and "Mana gains within 5s of a decrease" or "Mana gains outside 5s of a decrease"
        local b=row(f.recovery,label)
        b.count=b.count+1; b.amount=b.amount+e.gained; b.max=math.max(b.max,e.gained)
        b.detail="Subset of observed mana recovery. Uses the last observed mana decrease, including drains, as a timing proxy. Does not identify MP5, spirit/willpower, talents or actual casting."
      end
    end
  elseif e.kind=="recovery" then
    local a=row(f.recovery,"Health recovered (observed)")
    a.count=a.count+1; a.amount=a.amount+amount; a.max=math.max(a.max,amount)
    a.detail="Positive health updates: regeneration plus healing, including vampirism. Named heals are shown separately from the combat log, not added again. Concurrent damage may mask recovery."
  elseif e.kind=="cast" then
    local a=row(f.casts,name); a.count=a.count+1; a.casts=a.casts+1
    if e.item then a.source=e.item end
  elseif e.kind=="effect" then
    if e.gainResource then
      local r=row(f.recovery,"Resource log: "..name.." ("..e.gainResource..")")
      r.count=r.count+1; r.amount=r.amount+amount; r.max=math.max(r.max,amount)
      r.detail="Named resource restoration from the combat log. Overlaps observed resource gains; do not add both totals. May include recovery lost at the resource cap."
    end
    local a=row(f.effects,name); a.count=a.count+1; a.amount=a.amount+amount
    a.detail=e.detail or "Aura gains / refreshes (not necessarily a proc)"
    a.source=e.item or R.db.sources[name] or a.source
  end
end
function R.GetFight()
  if R.view==-1 then return R.GetAverage() end
  if R.view==0 then return R.current or R.history[1] end
  return R.history[R.view]
end
function R.Duration(f)
  return f==R.current and math.max(.1,(R.ending or GetTime())-f.start) or f.duration
end
function R.Tick(now)
  if R.current and not UnitAffectingCombat("player") then
    if R.ending and now-R.ending>=1 then R.Finish(R.ending)
    elseif not R.ending and now-R.current.last>=3 then R.Finish(R.current.last) end
  end
end
