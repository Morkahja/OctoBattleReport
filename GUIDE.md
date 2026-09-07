# Octo Battle Report

A lightweight personal fight report for the original WoW 1.12 client, including Turtle WoW. Standalone: ShaguDPS can stay installed, but is not a dependency and is not modified.

## Open the report

Restart the game after first installation and enable **Octo Battle Report** in the character-selection AddOns list. Click the movable **Battle Report** button or type `/obr` (also `/battlereport`). Drag the window by its header. Escape closes it.

Recording happens even when the window is closed. Leave it open to watch counters update five times per second. **Live / Latest** follows the current fight, or shows the latest completed one. The left arrow decreases the saved-fight number; the right arrow increases it. Fight 1 is newest, up to fight 100 (oldest retained). Reports and positions are saved per character on normal logout/reload.

## Views

- **Overview:** damage dealt/taken and healing with rates, direct attempts, hits, crits, periodic ticks, dodges, parries, blocks, healing received and reported mitigation.
- **Damage:** ability bars with event counts, totals and shares. Hover for direct hits, periodic ticks, criticals, avoided outcomes and largest hit.
- **Defense:** incoming abilities grouped by attacker, with damage and avoidance details.
- **Healing:** healing done and received. A self-heal contributes to both summary totals but appears once in the breakdown.
- **Casts:** spell counts and associated damage, separate from hit/tick counts. The capture mode is shown below the table.
- **Effects:** aura gains/refreshes, debuffs, resource gains, extra-attack grants and identifiable item-triggered spells. Hover to see what each observation means and any known source.
- **Recovery:** observed health and resource gains, update counts, largest update, mean gain per update and fight-wide recovery per five seconds. Named heals and resource restorations appear as separate log observations.

Orange and blue activity bars show damage dealt and taken over time. The chart keeps at most 60 time bins, combining adjacent bins during long encounters. Its label shows the seconds represented by each bin. Bars sort by total or count; use the mouse wheel or lower arrows to browse longer lists.

## Resource use (1.1)

Below the summary cards, **Resources Used** on the left shows observed mana, rage and energy consumption; **Resources Recovered** on the right shows mana restored, rage generated and energy regenerated. Both have separate headings and extra vertical space (1.3.1). Recovery includes observed ability/item gains as well as passive generation. These are independent gross totals, not a net balance; Average shows their per-fight averages. Other resource types remain available in Overview and Recovery. Hits, crits and ticks sit at the bottom of **Damage Dealt**; dodges, parries and blocks sit in **Damage Taken / Avoidance**.

Resource usage adds decreases in the player's active resource pool during combat; later gains do not subtract from the total. For example, spending 100 mana, recovering 50, and spending another 100 reports 200 used. Overview includes individual resource rows; their hover details show observed gains. Hover the resource summary for the measurement explanation.

These are observed decreases, **not exact spell-cost accounting**: hostile drains also count, and spending combined with regeneration in one client update may be undercounted. Only the active pool is tracked, so hidden mana spending while in another form may be missed. Changes of power type, maximum capacity, and death/world-entry resets establish a new baseline instead of inventing a cost. Updates after the combat-end event are excluded, including subsequent rage decay. Mana decreases in the two seconds before combat are buffered to catch an opening spell; a nearby out-of-combat mana expense can therefore be included. Resource tracking is standalone and does not require Nampower.

Fights saved before resource tracking was introduced show that data as unavailable; totals are captured for new fights after `/reload`.

## Recovery details (1.3)

Recovery records positive changes to health and the active resource pool during combat, including gains between casts. Out-of-combat regeneration and updates after the combat-end event are excluded. Positive updates can combine regeneration, potions, abilities and item effects; damage or resource costs arriving in the same update can mask a gain. At full health/mana, unused regeneration is not visible. An observed update is not necessarily one regeneration tick.

Mana gains are also split by whether they occurred less than five seconds after the last observed mana decrease. This is a timing proxy, not definitive detection of the five-second rule or casting: decreases can include drains. The addon does not assume that a mana gain came from MP5, spirit/willpower or a particular talent. The five-second rate in the tooltip is amount recovered divided by combat time, multiplied by five; it is not an equipment stat or a measured tick interval.

Health gains include both regeneration and healing. Named heals (including vampirism when the log names it) appear as **Heal log** rows; named resource restoration appears as **Resource log** rows. These overlap observed gains and must not be added together. Unnamed health increases cannot reliably be assigned specifically to willpower or vampirism. Logged amounts may include overhealing or overflow, while observed changes show only the visible net increase. Death, resurrection baselines and maximum-pool changes do not invent recovery events.

Recovery details require new fights; old reports are not retroactively reconstructed.

## Average and reset (1.3)

**Average** summarizes the latest **100 completed fights** retained for this character, or fewer if that is all that exists. Live combat is excluded. Existing retained reports are included on upgrade; new fights gradually build the sample. Amounts and counts (including ability casts, incoming attacks and avoidance) are arithmetic averages per fight. A fight without a particular ability contributes zero for that ability. Fractional counts are displayed to one decimal place. Largest-hit tooltip values remain the largest observed hit across the sample.

The duration is mean fight length. Card rates are **total amount / total combat time**, so longer fights receive their proper weight. Overview additionally shows the arithmetic mean of individual fight DPS. For example, 100 damage in 10 seconds and 600 in 30 seconds give 350 damage per fight, 20 seconds per fight, 17.5 overall DPS and 15 mean individual-fight DPS.

Resource and recovery averages use only reports that captured those fields; the footer states their coverage. Recovery rate tooltips use the durations of recovery-covered fights. Source identification and cast-capture limitations from each original report still apply.

**Reset average**, visible only in Average, immediately starts a new measurement period without deleting individual reports. The cutoff is saved per character. If a fight is in progress during reset, that fight remains individually available but is excluded from the new average; the next fight starts the new sample. The rolling history remains capped at 100. Average stays selected as new fights complete.

## Cast and proc accuracy

The addon parses the client's localized combat-log templates. The interface itself is English. It records **your character**, not group members, pets or separately named totems. Multi-target hits and periodic ticks are outcomes, not separate casts.

When Nampower's `GetSpellRecField` API is present and `NP_EnableSpellGoEvents` is already enabled at login, the addon matches accepted `SPELL_CAST_EVENT` requests to `SPELL_GO_SELF` confirmations. This supports instant and on-next-swing abilities as well as cast-time spells. It does not change Nampower settings or hook your casting functions. The installed SuperCleveRoidMacros normally enables these events. After changing event settings, reload the UI.

Without those events, **only named cast-time completions** from the original client are counted. Instant casts and channels are incomplete in this fallback. Damage/healing outcomes still appear. Interrupted casts are excluded where the client reports them.

The old combat log does not always reveal which weapon, enchantment or item caused an effect, or distinguish an aura refresh from a new proc. Effects therefore show **observations**, not invented proc totals. Nampower item-triggered events with an item ID show its cached item name, falling back to the ID. Server item triggers, aura gains and mapped damage events are separate entries and should not be added together as unique activations. Damage-only weapon/enchantment effects remain visible under Damage even when their item source is unknown.

You can label an exact effect name for future observations:

```
/obr source Fiery Weapon = Fiery Weapon enchantment
```

This labels both aura observations and a separate damage-event row when that exact ability deals damage. It is a user-supplied attribution, not automatic proof of its source. Resource-gain totals and extra attacks granted are available in the effect tooltip.

Logged healing can include overhealing. Only explicitly logged blocked/absorbed/resisted amounts are totaled; full avoidance may lack an amount, and armor mitigation is not available. Unknown custom server message formats cannot be counted reliably. Players with the same combat-log name cannot be distinguished by the text parser.

## Fight boundaries and commands

Combat begins on the player's combat-state event or the first personal damage/avoidance event. The report includes up to two seconds of buffered opening casts/effects/heals. Leaving combat closes the fight after a one-second grace period to catch trailing log events; immediately re-entering combat continues the same report. Personal damage outside the normal combat state closes after three seconds of inactivity. A death alone does not split a fight until combat ends. Reloading during combat saves a partial report and starts a new segment afterward.

- `/obr last`: last completed fight.
- `/obr button`: hide/show the launcher.
- `/obr position`: restore window and launcher positions.
- `/obr source`: explain effect source labels.

No full combat log, party meter, external libraries, network access, chat broadcasts or changes to ShaguDPS. Storage is limited to 100 aggregate reports plus the active report; the timeline and opening buffer are bounded. Average is cached and rebuilt only after a completed report or reset.

## Validation

`tests/test_report.py` replays original 1.12 strings through a Lua 5.1 runtime and a mocked WoW frame API. It covers personal attribution, direct/periodic damage, critical and periodic heals, mitigation, spell avoidance, resource/environmental events, positional format strings, cast fallback and Nampower confirmation, fight boundaries, storage limits, source labels and all UI tabs. Addon code uses Lua 5.0-compatible syntax/API conventions, including `this`, `event`, `arg1`, `table.getn` and `math.mod`.

For tests, install Python `lupa` and place the original fixture at `tests/GlobalStrings.lua` from [the archived Blizzard 1.12.1 UI](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/GlobalStrings.lua). The runtime and fixture are excluded from the release. The installed ShaguDPS parser documentation and SuperCleveRoidMacros Nampower integration were also consulted.

The automated frame checks are smoke tests, not an in-game rendering test. First in-game check: fight one mob, use a spell, take a hit, end combat, and compare the report with the combat log. Then check a familiar weapon/item proc and verify its effect name and source label.
