"""Replay real 1.12 combat strings through the addon using Lupa's Lua 5.1 runtime.
Run: python tests/test_report.py (install lupa or use tests/runtime).
GlobalStrings.lua fixture: MOUZU/Blizzard-WoW-Interface, 1.12.1/FrameXML.
"""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests' / 'runtime'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
now=100; fighting=false; SlashCmdList={}; frames={}
function GetTime() return now end
function date() return "12:00" end
function UnitName(u) if u=="player" then return "Tester" else return "Wolf" end end
function UnitAffectingCombat() return fighting end
function getglobal(n) return _G[n] end
function GetCVar() return "0" end
DEFAULT_CHAT_FRAME={AddMessage=function() end}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:SetWidth(v) assert(v>0); self.width=v end
function methods:SetHeight(v) assert(v>0); self.height=v end
function methods:SetText(v) self.text=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:GetLeft() return 10 end
function methods:GetTop() return 600 end
function methods:CreateFontString() return CreateFrame("FontString") end
function methods:CreateTexture() return CreateFrame("Texture") end
for _,name in ipairs({"SetPoint","SetJustifyH","SetTextColor","SetFont","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetFrameStrata","SetMovable","EnableMouse","SetClampedToScreen","ClearAllPoints","RegisterForDrag","SetTexture","SetVertexColor","SetAllPoints","EnableMouseWheel","StartMoving","StopMovingOrSizing","SetOwner","AddLine"}) do
  methods[name]=function() end
end
function CreateFrame(kind,name,parent)
  local f=setmetatable({scripts={},events={},shown=true},{__index=methods})
  table.insert(frames,f); return f
end
UIParent=CreateFrame("Frame"); GameTooltip=CreateFrame("Frame")
''')
lua.execute((ROOT / 'tests' / 'GlobalStrings.lua').read_text(encoding='utf-8-sig'))
for filename in ['Core.lua', 'Average.lua', 'Resources.lua', 'Parser.lua', 'UI.lua']:
    lua.execute((ROOT / filename).read_text())
lua.execute('''
R=OctoBattleReport
function emit(ev,a,b,c,d,e,g,h)
  event=ev; arg1=a; arg2=b; arg3=c; arg4=d; arg5=e; arg6=g; arg7=h
  R.events.scripts.OnEvent()
end
emit("ADDON_LOADED","OctoBattleReport")
emit("PLAYER_LOGIN")
function parse(msg,kind,spell,amount,source,target)
  local e=R.Parse(msg)
  assert(e,"Not parsed: "..msg)
  assert(e.kind==kind, msg.." kind")
  assert(e.spell==spell, msg.." spell: "..tostring(e.spell))
  assert(e.amount==amount, msg.." amount: "..tostring(e.amount))
  if source then assert(e.source==source,msg.." source "..tostring(e.source)) end
  if target then assert(e.target==target,msg.." target "..tostring(e.target)) end
  return e
end
parse("You hit Wolf for 100.","damage","Melee",100,"player","Wolf")
parse("Wolf hits you for 50.","damage","Melee",50,"Wolf","player")
parse("Your Lightning Bolt crits Wolf for 245 Nature damage.","damage","Lightning Bolt",245,"player","Wolf")
parse("Your Hellfire hits you for 12 Fire damage.","damage","Hellfire",12,"player","player")
parse("Mage's Fireball hits Tester for 100 Fire damage.","damage","Fireball",100,"Mage","player")
parse("Wolf suffers 13 Nature damage from your Sting.","damage","Sting",13,"player","Wolf")
parse("You suffer 14 Shadow damage from Mage's Pain.","damage","Pain",14,"Mage","player")
parse("Your Heal heals you for 40.","heal","Heal",40,"player","player")
parse("Your Heal critically heals Friend for 45.","heal","Heal",45,"player","Friend")
parse("Friend's Heal heals you for 50.","heal","Heal",50,"Friend","player")
parse("You gain 30 health from Friend's Renew.","heal","Renew",30,"Friend","player")
parse("You gain 30 health from Renew.","heal","Renew",30,"Unknown","player")
parse("Friend gains 20 health from your Renew.","heal","Renew",20,"player","Friend")
parse("You reflect 15 Nature damage to Wolf.","damage","Damage shield",15,"player","Wolf")
parse("You fall and lose 16 health.","damage","FALLING",16,"Environment","player")
parse("You gain 22 Mana from Restore Mana.","effect","Restore Mana",22,"Unknown","player")
parse("Wolf's Link causes you 12 damage.","damage","Link",12,"Wolf","player")
for _,reason in ipairs({"dodged","parried","resisted","blocked","evaded"}) do
  local e=R.Parse("Wolf's Strike was "..reason..".")
  assert(e and e.kind=="miss" and e.source=="Wolf" and e.target=="player")
end
assert(R.Parse("Friend hits Wolf for 20.")==nil)
assert(R.Parse("Friend gains Flurry.")==nil)
-- Localized indexed placeholders and punctuation must remain literal.
COMBATHITSELFOTHER="%2$d damage to %1$s."
R.BuildRules()
parse("45 damage to Wolf.","damage","Melee",45,"player","Wolf")
COMBATHITSELFOTHER="You hit %s for %d."
R.BuildRules()
assert(R.Parse("You hit Wolf for 100X")==nil)
-- Opening hits, both full and partial avoidance, ticks, heals, effect counts.
emit("CHAT_MSG_COMBAT_SELF_HITS","You hit Wolf for 100.")
assert(R.current and R.current.damage==100)
fighting=true; emit("PLAYER_REGEN_DISABLED")
emit("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS","Wolf hits you for 40. (20 blocked) (5 absorbed) (3 resisted)")
emit("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES","Wolf attacks. You dodge.")
emit("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES","Wolf attacks. You parry.")
emit("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES","Wolf attacks. You block.")
emit("CHAT_MSG_COMBAT_SELF_MISSES","You miss Wolf.")
emit("CHAT_MSG_SPELL_SELF_DAMAGE","Your Strike was dodged by Wolf.")
emit("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE","Wolf suffers 13 Nature damage from your Sting.")
emit("CHAT_MSG_SPELL_SELF_BUFF","Your Heal heals you for 40.")
emit("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS","You gain Flurry.")
emit("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS","You gain 2 extra attacks through Windfury Attack.")
local f=R.current
assert(f.damage==113 and f.taken==40 and f.healing==40 and f.received==40)
assert(f.attacks==3 and f.hits==1 and f.ticks==1)
assert(f.Dodge==1 and f.Parry==1 and f.Block==2)
assert(f.blocked==20 and f.absorbed==5 and f.resisted==3)
assert(f.effects.Flurry.count==1 and f.effects["Windfury Attack"].amount==2)
assert(f.abilities.Strike.misses==1)
assert(f.abilities.Strike.outcomes.Dodge==1)
R.db.sources.Spark="Test enchantment"
emit("CHAT_MSG_SPELL_SELF_DAMAGE","Your Spark hits Wolf for 9 Fire damage.")
assert(f.effects["Spark [damage]"].source=="Test enchantment" and f.effects["Spark [damage]"].amount==9)
-- Cast-time fallback rejects interrupted casts and does not count every tick.
emit("SPELLCAST_START","Heal",2000); now=102; emit("SPELLCAST_STOP")
assert(f.casts.Heal.count==1)
emit("SPELLCAST_START","Fireball",3000); now=103; emit("SPELLCAST_INTERRUPTED"); emit("SPELLCAST_STOP")
assert(not f.casts.Fireball)
-- Stop grace period; resume combat does not split the encounter.
fighting=false; emit("PLAYER_REGEN_ENABLED"); now=103.5; R.Tick(now); assert(R.current)
fighting=true; emit("PLAYER_REGEN_DISABLED"); now=104; R.Tick(now); assert(R.current==f)
fighting=false; emit("PLAYER_REGEN_ENABLED"); now=105.1; R.Tick(now)
assert(not R.current and R.history[1]==f and f.duration==4)
-- Out-of-combat heals do not overwrite last fight. Opening buffered cast is retained.
now=107; emit("CHAT_MSG_SPELL_SELF_BUFF","Your Heal heals you for 500.")
assert(not R.current and f.healing==40)
now=111; R.Record({kind="cast",source="player",spell="Bolt"})
now=111.5; emit("CHAT_MSG_COMBAT_SELF_HITS","You hit Wolf for 2.")
assert(R.current.casts.Bolt.count==1 and R.current.healing==0)
-- Nampower's server event confirms requests once; proc events never become casts.
GetSpellRecField=function(id) return "Bolt" end
GetCVar=function() return "1" end
emit("PLAYER_LOGIN")
emit("SPELL_CAST_EVENT",1,123,1)
emit("SPELL_GO_SELF",0,123,"playerguid","targetguid",0,3,0)
emit("SPELL_GO_SELF",0,123,"playerguid","targetguid",0,3,0)
assert(R.current.casts.Bolt.count==2)
emit("SPELL_GO_SELF",456,124,"playerguid","targetguid",0,1,0)
assert(R.current.effects["Bolt [item trigger]"].source=="Item #456")
-- Bounded history, timeline, and every UI tab with actual data.
for _,tab in ipairs({"Overview","Damage","Defense","Healing","Casts","Effects"}) do R.tab=tab; R.Refresh() end
local current=R.current
for i=1,10000 do now=112+i; R.Record({kind="damage",source="player",target="Wolf",spell="Melee",amount=1}) end
local bins=0; for _ in pairs(current.timeline) do bins=bins+1 end
assert(bins<=60 and current.damage==10002)
R.Finish(now)
for i=1,9 do now=now+5; R.Start(now); R.Record({kind="damage",source="player",target="Wolf",amount=1}); R.Finish(now+1) end
assert(table.getn(R.history)==11)
R.view=5; R.Refresh(); R.view=0; R.Refresh()
print("PASS: parser, attribution, mitigation, casts, buffering, fight lifecycle, bounded history/timeline, and UI smoke tests")
''')
lua.execute('''
-- Resource events use the stock displayed pool, not raw tenths of rage.
powerKind=0; powerValue=1000; powerMaximum=1000; dead=false
function UnitPowerType() return powerKind end
function UnitMana() return powerValue end
function UnitManaMax() return powerMaximum end
function UnitIsDeadOrGhost() return dead end
function powerEvent(ev,unit)
  event=ev or "UNIT_MANA"; arg1=unit or "player"
  R.resourceEvents.scripts.OnEvent()
end
R.pending={}; fighting=false; powerEvent("PLAYER_LOGIN")
powerValue=900; powerEvent() -- opening cast before combat
now=now+.2; fighting=true; R.Start(now)
local f=R.current
assert(f.resources.Mana.spent==100)
powerValue=950; powerEvent()
powerValue=850; powerEvent()
assert(f.resources.Mana.spent==200 and f.resources.Mana.gained==50)
powerEvent() -- duplicate notification
assert(f.resources.Mana.spent==200)
powerValue=800; powerEvent("UNIT_MANA","party1")
assert(f.resources.Mana.spent==200)
powerEvent()
assert(f.resources.Mana.spent==250)
-- Max-pool changes must not be treated as costs; subsequent costs still count.
powerMaximum=700; powerValue=700; powerEvent("UNIT_MAXMANA")
powerValue=650; powerEvent()
assert(f.resources.Mana.spent==300)
powerKind=1; powerMaximum=100; powerValue=60; powerEvent("UNIT_DISPLAYPOWER")
powerValue=35; powerEvent("UNIT_RAGE")
assert(f.resources.Rage.spent==25)
powerValue=45; powerEvent("UNIT_RAGE")
assert(f.resources.Rage.gained==10)
powerKind=3; powerValue=100; powerEvent("UNIT_ENERGY") -- changed type even before display event
powerValue=60; powerEvent("UNIT_ENERGY")
assert(f.resources.Energy.spent==40)
dead=true; powerValue=0; powerEvent("PLAYER_DEAD"); powerEvent("UNIT_ENERGY")
assert(f.resources.Energy.spent==40)
dead=false; powerValue=100; powerEvent("PLAYER_ENTERING_WORLD")
local activity=f.last
now=now+1; powerValue=80; powerEvent("UNIT_ENERGY")
assert(f.last==activity and f.resources.Energy.spent==60)
R.Refresh()
assert(string.find(R.window.metrics.text,"Mana: 300"))
assert(string.find(R.window.metrics.text,"Rage: 25"))
assert(string.find(R.window.metrics.text,"Energy: 60"))
assert(string.find(R.window.cards[1].footer.text,"hits"))
assert(string.find(R.window.cards[2].footer.text,"dodges"))
-- End-of-combat decay cannot inflate totals; gains never reduce gross usage.
fighting=false; emit("PLAYER_REGEN_ENABLED")
powerValue=70; powerEvent("UNIT_ENERGY")
assert(f.resources.Energy.spent==60)
R.Finish(now)
assert(R.history[1]==f) -- resource-only fight persists
powerKind=1; powerValue=20; powerEvent("UNIT_DISPLAYPOWER")
powerValue=10; powerEvent("UNIT_RAGE")
assert(table.getn(R.pending)==0) -- no idle rage-decay buffering
R.view=1; R.Refresh()
f.resources=nil; R.Refresh() -- old saved report migration / rendering
assert(string.find(R.window.metrics.text,"older fight"))
print("PASS: mana/rage/energy, opener buffering, gains, duplicate/non-player events, forms, capacity, death, combat-end exclusion, saved resource-only fights and old-report UI")
''')
lua.execute('''
-- Recovery is combat-only; health observations and named heals overlap but are not summed.
R.history={}; R.db.history=R.history; R.average=nil; R.db.averageAfter=0; R.pending={}
now=20000; fighting=false; dead=false
health=500; healthMax=1000
function UnitHealth() return health end
function UnitHealthMax() return healthMax end
powerKind=0; powerValue=500; powerMaximum=1000
powerEvent("PLAYER_ENTERING_WORLD")
health=520; powerEvent("UNIT_HEALTH"); powerValue=520; powerEvent()
assert(not R.current)
fighting=true; R.Start(now)
local f=R.current
powerValue=420; powerEvent()
now=now+2; powerValue=440; powerEvent()
now=now+4; powerValue=470; powerEvent()
assert(f.recovery["Mana recovered (observed)"].amount==50)
assert(f.recovery["Mana recovered (observed)"].count==2)
assert(f.recovery["Mana gains within 5s of a decrease"].amount==20)
assert(f.recovery["Mana gains outside 5s of a decrease"].amount==30)
health=530; powerEvent("UNIT_HEALTH")
emit("CHAT_MSG_SPELL_SELF_BUFF","Your Vampirism heals you for 25.")
health=555; powerEvent("UNIT_HEALTH")
assert(f.recovery["Health recovered (observed)"].amount==35)
assert(f.recovery["Heal log: Vampirism"].amount==25 and f.received==25)
emit("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS","You gain 22 Mana from Restore Mana.")
assert(f.recovery["Resource log: Restore Mana (Mana)"].amount==22)
assert(f.recovery["Mana recovered (observed)"].amount==50) -- never double-count named log gains
healthMax=1200; health=755; powerEvent("UNIT_MAXHEALTH")
assert(f.recovery["Health recovered (observed)"].amount==35)
dead=true; health=0; powerEvent("PLAYER_DEAD")
dead=false; health=600; powerEvent("UNIT_HEALTH")
assert(f.recovery["Health recovered (observed)"].amount==35)
fighting=false; emit("PLAYER_REGEN_ENABLED"); health=620; powerEvent("UNIT_HEALTH")
powerValue=500; powerEvent()
assert(f.recovery["Health recovered (observed)"].amount==35)
assert(f.recovery["Mana recovered (observed)"].amount==50)
R.Finish(now)
R.tab="Recovery"; R.Refresh()
assert(R.rowCount>=5)
-- Two controlled reports: zero-use fights belong in each ability's denominator.
R.history={}; R.db.history=R.history; R.average=nil
now=21000; R.Start(now); R.Record({kind="damage",source="player",target="Hyena",spell="Frostbite",amount=100})
R.Record({kind="cast",source="player",spell="Frostbite"}); R.Finish(now+10)
now=22000; R.Start(now); R.Record({kind="damage",source="player",target="Hyena",spell="Melee",amount=600}); R.Finish(now+30)
local avg=R.GetAverage()
assert(avg.fights==2 and avg.damage==350 and avg.duration==20)
assert(avg.damage/avg.duration==17.5 and avg.meanDPS==15)
assert(avg.casts.Frostbite.count==.5 and avg.abilities.Frostbite.amount==50)
assert(R.history[2].casts.Frostbite.count==1) -- inputs immutable
R.view=0; R.Browse(1); assert(R.view==2)
R.Browse(-1); assert(R.view==1)
R.Browse(-1); assert(R.view==1)
R.view=-1
for _,tab in ipairs({"Overview","Damage","Defense","Healing","Casts","Effects","Recovery"}) do R.tab=tab; R.Refresh() end
-- Reset preserves history, excludes in-progress fight, persists cutoff.
now=23000; R.Start(now); R.Record({kind="damage",source="player",target="Hyena",amount=50})
R.ResetAverage(); assert(table.getn(R.history)==2 and R.GetAverage().fights==0)
R.Finish(now+5); assert(R.GetAverage().fights==0 and R.view==-1)
now=24000; R.Start(now); R.Record({kind="damage",source="player",target="Hyena",amount=70}); R.Finish(now+7)
assert(R.GetAverage().fights==1 and R.GetAverage().damage==70)
R.Init(); R.average=nil; assert(R.GetAverage().fights==1)
-- Rolling bound and non-equivalent rate definitions.
for i=1,105 do
  now=now+20; R.Start(now); R.Record({kind="damage",source="player",target="Hyena",amount=i}); R.Finish(now+10)
end
assert(table.getn(R.history)==100 and R.GetAverage().fights==100)
R.view=100; R.Browse(1); assert(R.view==100)
R.ResetAverage(); R.tab="Overview"; R.Refresh(); assert(R.rowCount==0)
print("PASS: recovery totals/timing/source separation, regeneration exclusions, average denominators, immutable reports, arrow direction, reset/cutoff persistence and 100-fight rolling bound")
''')
