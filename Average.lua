local R=OctoBattleReport
local scalars={"damage","taken","healing","received","attacks","hits","ticks","crits","incoming","incomingHits","blocked","absorbed","resisted","Dodge","Parry","Block","Miss","Resist","Absorb","Immune","Evade"}
local groups={"abilities","defense","heals","effects","casts","recovery"}
local values={"count","amount","hits","ticks","crits","casts","misses"}
function R.ResetAverage()
  R.db.averageAfter=R.db.serial
  if R.current then R.current.excludeAverage=true end
  R.average=nil; R.view=-1; R.offset=0
end
function R.GetAverage()
  if R.average then return R.average end
  local result=R.New(0)
  result.isAverage=true; result.fights=0; result.resourceCoverage=0; result.recoveryCoverage=0
  result.meanDPS=0
  result.recoveryDuration=0
  result.title="Average per completed fight"
  result.stamp="Per character"
  result.castMode="Per-fight average; cast coverage depends on each fight's capture mode"
  for _,f in ipairs(R.history) do
    if (f.id or 0)>(R.db.averageAfter or 0) and not f.excludeAverage then
      result.fights=result.fights+1
      result.duration=result.duration+f.duration
      result.meanDPS=result.meanDPS+f.damage/math.max(.1,f.duration)
      for _,key in ipairs(scalars) do result[key]=(result[key] or 0)+(f[key] or 0) end
      if f.resources then
        result.resourceCoverage=result.resourceCoverage+1
        for name,a in pairs(f.resources) do
          local r=result.resources[name] or {spent=0,gained=0}; result.resources[name]=r
          r.spent=r.spent+a.spent; r.gained=r.gained+a.gained
        end
      end
      if f.recovery then result.recoveryCoverage=result.recoveryCoverage+1; result.recoveryDuration=result.recoveryDuration+f.duration end
      for _,group in ipairs(groups) do
        for name,a in pairs(f[group] or {}) do
          local r=R.Row(result[group],name)
          for _,key in ipairs(values) do r[key]=r[key]+(a[key] or 0) end
          r.max=math.max(r.max,a.max or 0)
          r.detail=a.detail; r.source=a.source
          for reason,n in pairs(a.outcomes or {}) do r.outcomes[reason]=(r.outcomes[reason] or 0)+n end
        end
      end
    end
  end
  local n=math.max(1,result.fights)
  for _,key in ipairs(scalars) do result[key]=(result[key] or 0)/n end
  result.duration=result.duration/n; result.meanDPS=result.meanDPS/n
  result.recoveryDuration=result.recoveryDuration/math.max(1,result.recoveryCoverage)
  for _,a in pairs(result.resources) do
    a.spent=a.spent/math.max(1,result.resourceCoverage); a.gained=a.gained/math.max(1,result.resourceCoverage)
  end
  for _,group in ipairs(groups) do
    local divisor=group=="recovery" and math.max(1,result.recoveryCoverage) or n
    for _,a in pairs(result[group]) do
      for _,key in ipairs(values) do a[key]=a[key]/divisor end
      for reason,value in pairs(a.outcomes) do a.outcomes[reason]=value/divisor end
    end
  end
  R.average=result
  return result
end
function R.Browse(direction)
  local count=table.getn(R.history)
  if count==0 then R.view=0 else R.view=math.max(1,math.min(count,math.max(1,R.view)+direction)) end
  R.offset=0
end
