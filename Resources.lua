local R=OctoBattleReport
local names={[0]="Mana",[1]="Rage",[2]="Focus",[3]="Energy",[4]="Happiness"}
local previous
local lastManaLoss
local previousHealth
-- UnitMana uses displayed units (including rage), and follows the active pool.
-- Comparing different forms/power types would invent a large resource cost.
function R.SampleResource(reset)
  if not UnitMana or not UnitPowerType then return end
  local kind=UnitPowerType("player")
  local value=UnitMana("player")
  local maximum=UnitManaMax("player")
  if not names[kind] or type(value)~="number" or type(maximum)~="number" then previous=nil; return end
  local old=previous
  previous={kind=kind,value=value,maximum=maximum}
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then previous=nil; lastManaLoss=nil; return end
  if reset or not old or old.kind~=kind then lastManaLoss=nil; return end
  -- Capacity changes (gear, buffs, forms) are not resource spending/generation.
  if old.maximum~=maximum then lastManaLoss=nil; return end
  local change=value-old.value
  if change==0 then return end
  if kind==0 and change<0 then lastManaLoss=GetTime() end
  local recent=kind==0 and lastManaLoss and GetTime()-lastManaLoss<5
  if R.current then
    if not R.ending then
      R.Record({kind="resource",source="player",resource=names[kind],spent=math.max(0,-change),gained=math.max(0,change),recentSpend=recent})
    end
  elseif UnitAffectingCombat("player") then
    R.Record({kind="resource",source="player",resource=names[kind],spent=math.max(0,-change),gained=math.max(0,change),recentSpend=recent})
  end
end
function R.SampleHealth(reset)
  if not UnitHealth or not UnitHealthMax then return end
  local value,maximum=UnitHealth("player"),UnitHealthMax("player")
  local old=previousHealth
  previousHealth={value=value,maximum=maximum}
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then previousHealth=nil; return end
  if reset or not old or old.maximum~=maximum then return end
  if value>old.value and ((R.current and not R.ending) or (not R.current and UnitAffectingCombat("player"))) then
    R.Record({kind="recovery",source="player",amount=value-old.value})
  end
end
local frame=CreateFrame("Frame")
R.resourceEvents=frame
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_DEAD","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_MANA","UNIT_RAGE","UNIT_ENERGY","UNIT_FOCUS","UNIT_HAPPINESS","UNIT_DISPLAYPOWER","UNIT_MAXMANA","UNIT_MAXRAGE","UNIT_MAXENERGY","UNIT_MAXFOCUS"}) do frame:RegisterEvent(e) end
frame:SetScript("OnEvent",function()
  if not R.db then return end
  if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_DEAD" then R.SampleResource(true); R.SampleHealth(true)
  elseif (event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH") and arg1=="player" then R.SampleHealth(event=="UNIT_MAXHEALTH")
  elseif arg1=="player" then
    R.SampleResource(event=="UNIT_DISPLAYPOWER" or string.sub(event,1,8)=="UNIT_MAX")
  end
end)
