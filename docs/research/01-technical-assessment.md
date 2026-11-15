# PyroEncyclopedia: Technical Assessment and Proposed Architecture

Status: research only. Nothing is implemented yet.
Date: 2026-11-15
Proof of concept item: **Spider's Silk (3182)**

---

## 1. Summary

> **Update (round 2, section 4b):** a third library, **LibItemDB** (MIT, same author as LibProfessionDB), fills most of the gaps listed below for WoW Forever. It has stats and properties for all 24,473 Forever items, drop **chances** per creature, vendor prices, chest and gathering-node sources, boss loot for Classic instances, and reputation/PvP rewards. The recommended stack is now **QuestieDB + LibProfessionDB + LibItemDB**. Pyro's job is to merge the three into one tooltip and one window. The gaps still open after round 2 are listed in section 4c.

The original round-1 finding: you can build PyroEncyclopedia on **QuestieDB + LibProfessionDB as runtime dependencies**, without copying or changing either database. Between them they cover most of what an item page needs for WoW Forever. Three gaps stand out:

1. **Most reverse lookups don't exist upstream.** Examples: "what consumes this item", "what does this NPC drop or sell", "which quests need this item". Pyro has to build these indexes itself at runtime from the public APIs. All of them are cheap except NPC → loot, which is large and should be built only when needed.
2. **Some data isn't in either source:** drop rates (except for about 2,000 quest-objective items), skinning, pickpocket, fishing and disenchant loot, vendor prices and stock (except Forever's Merchant's Favor recipe vendors), and reliable sources for some Forever-new recipes.
3. **Forever support works but isn't yet proven in a live client.** Both libraries target Interface `16001`. QuestieDB's own documentation says that Forever's live client acceptance (native file selection and TOC-suffix recognition) is still **pending**. LibProfessionDB matches the interface number exactly, so if Forever bumps it, LibProfessionDB loads no data.

The Spider's Silk walkthrough (section 5) checks this against the real data shipped today: 25 dropping NPCs across 8 zones, no vendors, quests or containers, **22 recipes that consume it** (17 of them Forever-only), and nothing that produces it.

---

## 2. What was inspected

| | QuestieDB | LibProfessionDB |
| --- | --- | --- |
| Where | github.com/Questie/QuestieDB, `master` @ `4dbb824` (2026-11-14), release **v1.1.1** | CurseForge project 1558781, file `ProfessionDB-v1.10.0` (2026-11-14), LibStub **MINOR 14** |
| Addon folder / global | `QuestieDB` / `LibQuestieDB`, plus `QuestDB`, `NpcDB`, `ItemDB`, `ObjectDB` | `ProfessionDB` / `LibStub("LibProfessionDB-1.0")` |
| Forever TOC | `QuestieDB_Forever.toc` plus a byte-identical `QuestieDB_Camelot.toc` alias (generated Baked build); Source mode uses `[ExcludeLoadGameType vanilla, tbc, wrath, cata, mists]` | `ProfessionDB_Camelot.toc` only, `## Interface: 16001` |
| Forever data basis | Era data converted to Forever coordinates, plus a generated "delta-base" from Forever snapshots, player-trace corrections and hand-written fixes | Forever's own DBC data (wago build `1.60.1.70938`, product `wowf`) |
| License | **Complicated.** Historically unlicensed; the Questie team allows forks and copying under GPLv3 but "cannot promise all contributors are" fine with it, so treat it as all rights reserved when in doubt. The Questie name and logo are excluded. | **MIT** |
| Hard dependencies | none | **Ace3, VersionCheck-1.0** (only for its guild version check, but listed as required in the TOC) |
| Release cadence | Very fast: 6 releases between 11 and 14 November 2026 | About weekly to monthly |

Method: I read QuestieDB's consumer API docs (`docs/api.md`), its schemas (`src/meta/*.lua`), its Forever docs, and the raw Forever data and generated correction files. I read LibProfessionDB's README, its library source and its Forever data tree. The Spider's Silk numbers come from **static text extraction** of the shipped data files. Upstream code was not executed (running the bundled `lua.exe` was blocked, which is the right call for downloaded code). As a result, QuestieDB figures reflect the raw data plus a grep of the correction layers, not the fully corrected API output. Section 9 lists what to confirm in-game.

---

## 3. QuestieDB findings

### 3.1 API surface (contract 4)

- `ItemDB/NpcDB/ObjectDB/QuestDB.Get(id, field)`, plus a named getter per field (`ItemDB.npcDrops(3182)`), `GetAll(id, {fields})`, `GetAllIds()`, `Exists(id)`, and `IdsByName(exactName)`.
- `LibQuestieDB.RequireContract(n)` to check the version range. Use `RequireContract(4)` if you need `Enum.npcFlags` or `Enum.classKeys`.
- `LibQuestieDB.Support.Get("ZoneDB" | "DropDB" | "QuestXP" | "QuestieDB")` returns whole-table reference data. Some of it, including drop tables and zone maps, comes back as **Lua source strings that you `loadstring`**.
- `LibQuestieDB.l10n.SetLocale()` switches between 9 Baked locales for names. You can also add dynamic corrections through `GetRegistrar(owner)`, though Pyro shouldn't need to.
- Gotchas:
  - Numeric getters return `0`, not `nil`.
  - Empty tables come back as `nil`, except for quest `startedBy`, `finishedBy` and `objectives`.
  - **Every table read allocates a fresh deep copy.** That matters for bulk scans (section 7).
  - `IdsByName` is exact-match only.

### 3.2 Schemas relevant to an item encyclopedia

| Entity | Useful fields |
| --- | --- |
| Item (16) | `name, npcDrops, objectDrops, itemDrops (containers), startQuest, questRewards, vendors, relatedQuests, teachesSpell, itemLevel, requiredLevel, class, subClass, flags` |
| Npc (15) | `name, subName, minLevel, maxLevel, rank, spawns {[zone]={{x,y}}}, waypoints, zoneID, questStarts, questEnds, factionID, friendlyToFaction, npcFlags` (health was removed) |
| Object (7) | `name, spawns, zoneID, questStarts, questEnds, factionID, waypoints` |
| Quest (36) | `name, startedBy {npc,obj,item}, finishedBy, objectives {creature, object, item, rep, killcredit, spell}, sourceItemId, requiredSourceItems, requiredSkill, preQuest*, …` |

The item → source direction is **already stored on the item** (`npcDrops`, `objectDrops`, `itemDrops`, `vendors`, `questRewards`). The other direction is not stored anywhere: NPC → items dropped or sold, object → loot, container → contents, and quest → reward items. Those need generated indexes.

### 3.3 Forever coverage (raw data plus generated delta-base)

| Entity | Raw rows | Added by Forever delta-base | Total |
| --- | ---: | ---: | ---: |
| Items | 14,889 | 8,862 | **23,751** |
| NPCs | 10,119 | 5,432 | **15,551** |
| Objects | 6,645 | 563 | **7,208** |
| Quests | 4,244 | 1,408 | **5,652** |

Quality notes from spot checks:

- The item table is **not** limited to quest items: armor 7,219, weapons 2,122, quest items 2,251, misc 971, recipes 875 and so on. **10,144 of the 14,889** raw items (68%) have at least one source field: `npcDrops` 4,010, `objectDrops` 2,905, containers 2,052, `questRewards` 2,138, `vendors` 1,751. The npcDrops lists total about 155k item–NPC pairs; the longest single list is 1,759 NPCs.
- Dungeon boss loot is present (for example, Cruel Barb from VanCleef; Runeblade of Baron Rivendare). **Raid boss loot is not**: Arcanist Boots and Choker of the Fire Lord have no source. **Random world-drop items aren't either**: Hand of Edward the Odd and Staff of Jordan have no source, and Ivycloth Pants lists only chests.
- **Skinning loot is missing.** Light Leather (2318) has no NPC sources at all.
- **Gathering nodes are covered** as objects (Copper Vein 1731 → Copper Ore). Herbs work the same way.
- **Drop rates** exist only in `Support DropDB`, for 2,032 items, all of them quest objectives. Spider's Silk isn't among them.
- `vendors` is filled in widely (for example, Coarse Thread lists dozens of NPCs). There are **no prices, stock limits or faction restrictions**.
- The delta-base comment says outright that it "does not supply complete objectives, restrictions or other gameplay behavior" for new Forever content.

---

## 4. LibProfessionDB findings

### 4.1 API surface (MINOR 14)

- `GetRecipe(profId, spellId)` returns `{ name, difficulty, reagents = {[itemId]=qty}, craftedItemId, itemId (recipe scroll), requiredSkill, … }`.
- `Iterate(profId?)`, `GetRecipes(profId)` (the raw table, read-only), `GetReagents`, `GetCraftedItemID`, and `Search({query})` (matches recipe names and effect text).
- `GetRecipeItem(spellId)` returns the teaching item, and `GetRecipeItems()` returns the full spell → item map.
- `GetRecipeSources(spellId)` returns `{trainer, vendor, quest, container, drop}`. Each list is **capped at 12 entries; use `.total` for the real count.** `GetVendorCost`, `GetSourceFaction` and `GetSourceName` cover English names only.
- `IsBorrowed(spellId, field)`: on Forever, sources, requiredSkill and hidden flags are **borrowed from Vanilla** and should be shown as unconfirmed.
- `IsHiddenRecipe` flags recipes that were never obtainable. `GetAcquireMethod` flags recipes learned automatically with the profession.

### 4.2 Forever coverage

- 2,517 recipes across 12 professions. The Forever `_core` data is about 950 KB of Lua source, plus about 195 KB for the enUS names.
- Every reagent lookup is **recipe → items only**. There's no item → recipes index for consumers or producers. Pyro has to build both (section 6.2).
- Forever's own vendor data covers 7 **Alliance** Merchant's Favor vendors (314 recipes, with prices). **Horde vendors haven't been captured.** Some Forever-new recipes have no source at all (see 5.3).
- Game detection is an **exact match on `16001`**. Any other 16000–19999 client gets `"Unknown"` and no data loads.

---

## 4b. LibItemDB findings (round 2)

Inspected: CurseForge project 1558208, file `ItemDB-v1.9.0` (2026-11-12). Folder `ItemDB`, `LibStub("LibItemDB-1.0")`, **MIT**. It ships `ItemDB_Camelot.toc` with `## Interface: 16001`. Required dependencies: **Ace3, VersionCheck-1.0, LibAceGUIWidgets**. It has a SavedVariables table, `LibItemDB_PriceDB`.

**Forever data** (built from Forever's own client data via wago, build 1.60.1.70888–70938):

| Data | Coverage on Forever | Origin |
| --- | --- | --- |
| Name, quality, class, subclass, slot, item level, required level, stats, use and proc effects, sets, class/race/faction restrictions | **24,473 items**, names in 12 languages | Forever client data; stats from WoWSims Forever (MIT) |
| `GetItemPlaces(id)`: creature drops **with chance**, vendors, objects/nodes (with `profession`), each with uiMapID and up to 3 map points | **6,443 items**, 4,716 places (10,971 drop, 6,226 vendor and 4,242 object rows) | CMaNGOS **Classic** world DB (GPL-3.0) filtered to Forever's items and placed on Forever's maps. **Not observed on Forever.** |
| `GetSources(id)`: boss drops by instance | 1,238 items, 27 Classic instances, plus 33 items from 3 new Forever dungeons (unconfirmed community list) | WoWSims and AtlasLoot data; "imenso" community list |
| Reputation and PvP reward gear | yes | AtlasLoot Classic tables |
| Vendor buy and sell price | yes, plus prices captured live when you open a merchant | Forever client data, emulator `npc_vendor` |
| `GetReagentUses(id)`: which professions use it | yes (profession level only, not individual recipes) | own data |
| Name search, `BuildWhereSearchRows(text)` (substring, cap 100) | yes | own data |
| Per-boss drop rate (`GetDropRate`) | **no** on Forever | |
| Skinning/gathering as a source; quest rewards; world-drop pools | **no** on Forever ("Crafted and chests only" for origins) | |

API behaviour that matters for Pyro:

- `GetItemPlaces` is **capped**: at most 8 drops (highest chance first), 8 vendors, 6 objects. Shared world-drop pools (random greens and world epics) name no creature. It returns fresh tables on every call.
- `BuildWhereRows(id, faction)` returns ready-made display rows, already including localized zone names.
- LibItemDB already ships its **own UI**:
  - a "Where to get it" window, opened with **Alt+click** on any item by default;
  - a reagent "Used by" tooltip line;
  - a price window, `/itemdb`.

  Pyro should either reuse these or turn them off in LibItemDB's settings, so there are no duplicate tooltip lines and no Alt+click conflict.
- Size: Forever `_core` is 3.4 MB of Lua source plus 0.8 MB of enUS names, all loaded at login. Heap use hasn't been measured.

**Test items, checked in the shipped data:**

| Item | QuestieDB | LibItemDB |
| --- | --- | --- |
| Spider's Silk 3182 | 25 droppers, no rates | top 8 droppers **with chance** (Plains Creeper 18.8%, Elder Moss Creeper 15.4%, Wildthorn Lurker 14.4% …) |
| Choker of the Fire Lord 18814 (raid) | no source | Ragnaros (11502) |
| Arcanist Boots 16800 (MC tier) | no source | **no source** |
| Hand of Edward the Odd 2243 (world epic) | no source | 3 creatures at 10% |
| Light Leather 2318 | chests only | chests at 18%, crafted; **skinning missing** |
| Silky Boots 253891 (Forever-new) | delta-base entry | crafted (Tailoring) |

## 4c. Other candidate sources evaluated

| Candidate | Forever? | Licence | Usable as a Pyro dependency? | Verdict |
| --- | --- | --- | --- | --- |
| **LibItemDB** | yes (own data tree) | MIT | yes, LibStub API | **Adopt** (section 4b) |
| AtlasLootClassic Continued (Okrah) / AtlasLoot Classic Forever (Sliccer) | yes; new Forever raids and dungeons are **placeholders** | GPL-2.0 | no documented API for other addons; its internal tables could change | Not needed: LibItemDB already includes AtlasLoot's facts. Revisit for new Forever raid loot. |
| AllTheThings | no Forever build found | MIT | — | No |
| CMaNGOS `classic-db` | Classic 1.12, not Forever | GPL-3.0 | offline input only, not an addon | The **only** route to skinning, pickpocket, fishing and disenchant tables. That would mean building Pyro's own generated data file, which breaks the "no copied data" rule; keep it as a later option. |
| VMaNGOS / AzerothCore | Classic / Wrath | GPL-2.0 | offline only | Same as CMaNGOS; CMaNGOS is already what LibItemDB uses |
| Wowhead (Forever) | yes, most complete | ToS: not for bulk extraction | no | No offline route |
| WarcraftDB / Lexicon client (Warcraft Tavern) | yes, crowd-sourced | no public export or licence found | no | Watch only |

**Gaps still open after round 2:**

- skinning, pickpocket, fishing and disenchant yields;
- MC tier pieces (at least the one checked);
- loot from new Forever raids and dungeons, beyond 33 unconfirmed items;
- per-boss drop rates on Forever;
- vendor stock limits;
- creature type and abilities;
- everything Forever changed on the server side, since all world placement and loot data is **Classic-derived and not verified on Forever**.

---

## 5. Proof of concept: Spider's Silk (3182)

### 5.1 Item record (QuestieDB, Forever raw)

`{'Spider's Silk', npcDrops={25 ids}, objectDrops=nil, itemDrops=nil, startQuest=0, questRewards=nil, itemLevel=20, requiredLevel=0, class=7 (Trade Goods), subClass=0, vendors=nil, relatedQuests=nil}`

No Forever correction layer touches item 3182. The greps hit only *quest* 3182, "Proof of Deed".

### 5.2 Acquisition: NPC drops (`ItemDB.npcDrops` → `NpcDB.*`)

| Zone (spawn AreaID) | NPCs (level) |
| --- | --- |
| Duskwood (10) | Venom Web Spider 217 (19–20), Pygmy Venom Web Spider 539 (18–19), Green Recluse 569 (21–22), Naraxis 574 (27, rare), Black Widow Hatchling 930 (24–25), Carrion Recluse 949 (25–26) |
| Redridge Mountains (44) | Greater Tarantula 505 (19–20), Chatter 616 (23, rare) |
| Wetlands (11) | Leech Stalker 1111 (21–22), Leech Widow 1112 (24), Cave Stalker 4040 (21–22) |
| Hillsbrad Foothills (267) / Alterac Mountains (36) | Elder/Giant/Forest Moss Creeper 2348/2349/2350 (20–27), Creepthess 14279 (24) |
| Arathi Highlands (45) | Plains Creeper 2563 (32–33), Giant Plains Creeper 2565 (35–36) |
| Ashenvale (331) | Wildthorn Stalker/Venomspitter/Lurker 3819/3820/3821 (20–29) |
| Stonetalon Mountains (406) | Deepmoss Creeper/Webspinner/Venomspitter 4005/4006/4007 (16–20), Besseleth 11921 (21) |
| *(no spawns)* | Deepmoss Matriarch 4264 (22). This is an event-spawned NPC; the UI must handle "no known location". |

Drop rates: **not available.** Item 3182 isn't in DropDB.
Vendors, containers and objects: none. Quests: none. A scan of quest objectives, `sourceItemId`, `requiredSourceItems` and item starters found no reference to item 3182.

### 5.3 Recipes that consume Spider's Silk (generated reverse index over LibProfessionDB)

| Prof | Spell | Recipe | Qty | Crafts | Req. skill | Source |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| LW 165 | 3770 | Toughened Leather Gloves | 2 | 4253 | 110 | trainer (29), *borrowed* |
| Tailoring 197 | 3855 | Spidersilk Boots | 4 | 4320 | 125 | trainer (33), *borrowed* |
| Tailoring 197 | 3856 | Spider Silk Slippers | 1 | 4321 | 115 | drop (876 NPCs), 3 containers, *borrowed* |
| Tailoring 197 | 6690 | Lesser Wizard's Robe | 2 | 5766 | 135 | trainer, *borrowed* |
| Tailoring 197 | 6692 | Robes of Arcana | 2 | 5770 | 125 | drop (4 NPCs), *borrowed* |
| LW 165 | 1255034–1255080 (8 recipes) | Skulker's Leather Waistguard / Gauntlets / Boots / Bracers / Shoulders / Shoes / Gloves / Belt | 1–8 | 2524xx–2525xx | 150–250 | 5 sold by **Daniel Stitchsong (256734)** for 60–90 Merchant's Favor; 3 have **no known source** |
| Tailoring 197 | 1257371–1257420 (9 recipes) | Silky Boots / Gloves / Sash / Circlet / Gown / Leggings, Filigreed Silky Gown / Leggings / Circlet | 1–8 | 2538xx–2539xx | 60–125 | 6 sold by **Mivin Shadowweave (256735**, Redridge, Alliance) for 30 Merchant's Favor; 3 have **no known source** |

Cross-references that work:

- The Forever-new crafted items (for example 253891 Silky Boots) and the vendors 256734 and 256735 exist only in QuestieDB's **Forever delta-base**. LibProfessionDB's `SourceNames` doesn't list those vendors, so **QuestieDB is the name, zone and location source for ProfessionDB's NPC ids.**
- All 5 classic crafted items are in QuestieDB's raw item table.

### 5.4 Recipes that produce Spider's Silk

None. No `craftedItemId = 3182`, and it isn't a recipe-teaching item.

---

## 6. Proposed architecture

**Product goal (confirmed 2026-11-15):** look up any item in-game without opening Wowhead. That means two surfaces:

1. a **mouse-over tooltip** showing a short, user-chosen set of facts;
2. a **full window** with everything known, plus search.

**Round-2 change:** add **ItemDBProvider** (LibItemDB) next to the two providers below. It becomes the source for item properties, stats, drop chances, vendor prices and name search, with QuestieDB as the fallback. Each fact is merged by item id, and the source with the most detail wins:

| Fact | Primary | Fallback / merge |
| --- | --- | --- |
| Name, quality, stats, item level, restrictions | LibItemDB | client item APIs |
| Creature drops | LibItemDB `GetItemPlaces` (chance, top 8) | QuestieDB `npcDrops` (complete list, no chance) → "and N more" |
| Boss loot | LibItemDB `GetSources` | — |
| Vendors | LibItemDB (price) | QuestieDB `vendors` (complete list) |
| Objects, chests, nodes | LibItemDB (chance, profession) | QuestieDB `objectDrops` |
| Quest reward / objective / starts quest | QuestieDB | — |
| Recipes using / producing / taught | LibProfessionDB (via Pyro index) | LibItemDB `GetReagentUses` (profession names only) |
| NPC page (levels, spawns, quests) | QuestieDB | LibItemDB place points |

**Tooltip budget:** the tooltip runs on every hover, so it may only use O(1) lookups: QuestieDB named getters, LibItemDB getters, and Pyro's prebuilt recipe index. No scans, no allocation-heavy calls such as `GetItemPlaces`, and no `GetRecipeSources`. Cache the last item id's lines. The default lines would be the best drop with its chance, vendor price, and "Used in N recipes" with professions. All of these toggle in options.

```
┌──────────────────────── PyroEncyclopedia ────────────────────────┐
│  UI layer        item page · NPC page · search · tooltip hook   │
│                         │                                        │
│  Query service   Pyro:GetItemReport(id) → normalized report      │
│                  (sections + provenance + confidence flags)      │
│                         │                                        │
│  Index service   lazy, coroutine-built reverse indexes           │
│                  (in-memory; optional SavedVariables cache)      │
│                         │                                        │
│  Providers       QuestieProvider │ ProfessionProvider │ Client    │
│  (adapters)      LibQuestieDB    │ LibProfessionDB-1.0│ C_Item/C_Map│
└──────────────────────────────────────────────────────────────────┘
```

### 6.1 Providers (the only code that touches upstream APIs)

- **QuestieProvider:** check `LibQuestieDB` exists and `RequireContract(4)` passes, then read through named getters. It normalizes the quirks: treat `0` as absent, and treat nil as an empty list. Read-only: no registrars or corrections.
- **ProfessionProvider:** `LibStub("LibProfessionDB-1.0", true)`, check `IsReady()` and `GetGameVersion() == "Forever"`, and detect each newer function before calling it (`GetRecipeSources`, `IsBorrowed`, `GetVendorCost`).
- **ClientProvider:** `C_Item.GetItemInfoInstant` (synchronous: icon, class) and `Item:CreateFromItemID():ContinueOnItemLoad` (quality, link, tooltip) for presentation data. `C_Map.GetMapInfo` turns zone ids into **localized** names, using QuestieDB's `ZoneDB` `areaIdToUiMapId`.
- Each provider reports a capability flag, so the UI can degrade gracefully (for example, "Recipe data unavailable: ProfessionDB not loaded").

### 6.2 Generated reverse indexes (built at runtime, never shipped)

| Index | Built from | Size estimate | When |
| --- | --- | --- | --- |
| `reagentOf[item] → {spell}` | `ProfessionDB:Iterate()` over 2,517 recipes | < 200 KB | first item page |
| `producedBy[item] → {spell}` | same pass | < 50 KB | same pass |
| `teaches[item] → spell` | `GetRecipeItems()` reversed, plus QuestieDB `teachesSpell` | < 50 KB | same pass |
| `questNeeds[item] → {quest, why}` | `QuestDB` scan (5,652 quests: objectives[3], `sourceItemId`, `requiredSourceItems`, `startedBy[3]`) | < 200 KB | first item page (yielding) |
| `npcLoot[npc] → {item}`, `npcSells[npc]`, `objectLoot[obj]`, `containerHas[item]` | `ItemDB` scan over about 23.7k items | **multi-MB** (155k+ drop pairs) | **only when an NPC/object page is first opened**, or by user opt-in |
| `nameIndex` (prefix/substring search) | `ItemDB.name` over all ids | 1–2 MB | first search |

Rules for the index service:

- Build inside a coroutine that yields every N ids, driven by an `OnUpdate` time budget of about 5–8 ms per frame. This avoids frame stalls; QuestieDB documents a 23 ms pass for 6.6k names.
- Use packed numeric arrays, not nested `{id=…}` tables, to keep heap low.
- Store the **optional** SavedVariables cache with a key built from QuestieDB version and contract, ProfessionDB version, `GetBuildInfo()` and locale, and discard it on any mismatch. It never contains upstream rows, only id-to-id relations. Even so, it is derived data, which matters if Pyro is ever distributed (see 8).

### 6.3 Item report shape

```lua
report = {
  item     = { id, name, icon, quality, class, subClass, itemLevel },
  sources  = {
    drops      = { {npcId, name, minLevel, maxLevel, rank, zones={areaId…}, rate=nil|pct}, total = n },
    objects    = { … }, containers = { … }, vendors = { … },
    questRewards = { … }, recipes = { … }   -- produced by
  },
  usedIn   = { recipes = { {profId, spellId, qty, craftedItemId, sources, borrowed} }, quests = { … } },
  teaches  = spellId|nil, startsQuest = questId|nil,
  gaps     = { "dropRates", "skinning", … },   -- explicit "we don't know" markers
  provenance = { drops = "QuestieDB", usedIn = "ProfessionDB", … },
}
```

Every section carries provenance and a confidence label: own data, borrowed (Vanilla), or missing. That lets the UI say "unconfirmed" or "unknown" instead of showing nothing.

### 6.4 TOC (proposed)

```
## Interface: 16001
## Title: PyroEncyclopedia
## Dependencies: QuestieDB
## OptionalDeps: ProfessionDB
## SavedVariables: PyroEncyclopediaDB
```

I recommend making ProfessionDB **optional** so a QuestieDB-only setup still works. The 16001 value is unverified; check it with `/dump select(4, GetBuildInfo())`. If Forever needs a suffixed TOC, ship both `PyroEncyclopedia.toc` and `PyroEncyclopedia_Camelot.toc`.

---

## 7. Memory and performance

| Component | Estimate | Basis |
| --- | --- | --- |
| QuestieDB Baked, at rest | about 6.4 MB Lua heap, plus client metadata store | QuestieDB measured this for Vanilla; Forever is unmeasured |
| QuestieDB worst-case cache | up to about 38 MB if every field of every entity is read; `InvalidateCache()` brings it back to about 8 MB | QuestieDB's own measurement |
| QuestieDB **Source** mode | much larger: raw Lua strings (6.1 MB of Forever data files) plus live corrections | **Avoid. Install the Baked release zip.** |
| ProfessionDB Forever | about 1.2 MB of source parsed at load; heap unmeasured (probably a few MB) | file sizes |
| Pyro small indexes | < 0.5 MB | estimate |
| Pyro NPC-loot index | a few MB | 155k+ pairs; estimate |

Two consequences:

- Because QuestieDB copies on every read, a full `ItemDB` scan allocates heavily. Run scans only in yielding coroutines, read only the fields you need with named getters, and call `collectgarbage("step")` between batches.
- Don't hold report objects across pages. Rebuild them on demand; they're cheap.

---

## 8. Licensing implications

- **Runtime dependency** (Pyro calls their APIs, and you install both addons yourself) works for a private addon under both licenses. Nothing upstream gets redistributed.
- **LibProfessionDB is MIT.** You could even vendor it, but the plan is not to.
- **QuestieDB:** shipping copies, extracts, or **pre-generated indexes derived from its data** would mean redistributing content that is GPLv3 at best and all rights reserved at worst. That's why the indexes are built at runtime. If Pyro ever goes public, depend on QuestieDB rather than bundling it, and don't use the "Questie" name or logo.

---

## 9. Risks and open checks (do these in-game before implementing)

1. Run `/dump select(4, GetBuildInfo())` on Forever and confirm `16001`. If it differs, ProfessionDB loads **no data**, and QuestieDB's TOC would need updating.
2. Confirm which QuestieDB mode loaded with `/dump LibQuestieDB.readMode` (expect `"baked"`) and `/dump LibQuestieDB.ModeIndicator.GetStatus()`. QuestieDB itself lists Forever TOC recognition as **unverified**.
3. Confirm `/dump LibStub("LibProfessionDB-1.0"):GetGameVersion()` returns `"Forever"` and `:Count()` returns 2517.
4. Re-run the Spider's Silk queries through the real APIs: `/dump ItemDB.npcDrops(3182)` (expect 25), plus `NpcDB.spawns(4264)` (expect nil).
5. Measure `GetAddOnMemoryUsage` for QuestieDB and ProfessionDB after `UpdateAddOnMemoryUsage()`.
6. QuestieDB's release cadence (several per day) means data can shift. Pin a known-good version during development, and key caches on its version.

---

## 10. Coverage matrix

> **Round-2 overrides** (LibItemDB added). Where these differ from the round-1 rows below, these win:
>
> | # | Feature | New status |
> | --- | --- | --- |
> | 1a | NPC drops | ✅ LibItemDB places with **chance** (top 8, Classic-derived), plus the full QuestieDB list. World epics partly covered. |
> | 1b | Drop rates | ✅⚠ per creature, from CMaNGOS Classic; per-boss on Forever ❌ |
> | 1e | Vendor price | ✅ LibItemDB buy/sell price, plus live merchant capture; stock limits ❌ |
> | 1f | Skinning / pickpocket / fishing / disenchant | ❌ still missing (only via a CMaNGOS-generated file) |
> | — | Raid / dungeon boss loot | ✅⚠ LibItemDB: 27 Classic instances; new Forever raids ❌; some tier pieces ❌ |
> | — | Reputation / PvP rewards | ✅ LibItemDB |
> | 6a | Item stats, quality, effects, sets, restrictions, offline | ✅ LibItemDB, no client cache needed |
> | 6b | Name search | ✅ LibItemDB `BuildWhereSearchRows` (substring, cap 100) |
> | 7d | Creature type / abilities | ❌ unchanged |
>
> Round-1 matrix:

Legend: ✅ **Direct** (public API) · 🔁 **Generated** (Pyro runtime reverse index over public APIs) · 🖥 **Client API** · ⚠ **Partial** · ❌ **Needs an additional source**

| # | Feature | Status | Source / method | Notes for Forever |
| --- | --- | --- | --- | --- |
| 1a | Item → NPC drops | ✅⚠ | `ItemDB.npcDrops` | 27% of raw items have it; dungeon bosses yes; raid bosses and random world drops missing |
| 1b | Drop rates | ❌⚠ | `Support DropDB` covers quest-objective items only (2,032) | Needs a new source (for example a CMaNGOS/Wowhead-derived table) |
| 1c | Lootable objects / chests / gathering nodes | ✅ | `ItemDB.objectDrops` → `ObjectDB.spawns` | Mining and herb nodes covered |
| 1d | Containers (item contains item) | ✅ | `ItemDB.itemDrops` | |
| 1e | Vendors | ✅⚠ | `ItemDB.vendors` → `NpcDB` | No price, stock or currency, except ProfessionDB `GetVendorCost` for Forever recipe vendors |
| 1f | Skinning / pickpocket / fishing / disenchant / mining yields | ❌ | none | Light Leather has no sources |
| 1g | Item starts a quest | ✅ | `ItemDB.startQuest` | |
| 2 | Recipes **consuming** item | 🔁 | `ProfessionDB:Iterate()` → reagent index | 22 for Spider's Silk |
| 3a | Recipes **producing** item | 🔁 | same pass, `craftedItemId` | |
| 3b | Recipe acquisition (trainer, vendor, drop, quest) | ✅⚠ | `GetRecipeSources` (capped, `.total`) | Forever: Vanilla values *borrowed*; Horde Merchant's Favor vendors and some new recipes missing |
| 3c | Item teaches recipe | 🔁✅ | `GetRecipeItems()` reversed; `ItemDB.teachesSpell` | |
| 4a | Quest rewards item | ✅⚠ | `ItemDB.questRewards` | Choice vs. fixed reward isn't distinguished |
| 4b | Quest objective / required item | 🔁⚠ | `QuestDB.objectives[3]`, `sourceItemId`, `requiredSourceItems`; `ItemDB.relatedQuests` | Delta-base says new Forever quest objectives are incomplete |
| 4c | Quest givers / turn-ins (names, locations) | ✅ | `QuestDB.startedBy/finishedBy` → `NpcDB`/`ObjectDB` | |
| 5a | NPC name, subName, levels, rank, faction | ✅ | `NpcDB.*` | 15.5k NPCs incl. Forever-new |
| 5b | NPC coordinates / zones | ✅ | `NpcDB.spawns`, `zoneID` | Some converted points unverified (QuestieDB audit) |
| 5c | Localized zone names | 🖥 | `ZoneDB` areaId → uiMapId → `C_Map.GetMapInfo` | |
| 6a | Item name, icon, quality, stats, tooltip | 🖥⚠ | `C_Item.GetItemInfoInstant` / async item load | Quality and stats need the client cache (async) |
| 6b | Search by partial name | 🔁 | Pyro name index (QuestieDB `IdsByName` is exact-only) | |
| 6c | Recipe/NPC names localized | ✅⚠ | QuestieDB: 9 locales; ProfessionDB: recipe names in 12 | ProfessionDB source NPC names are English only |
| 7a | NPC page: what it drops | 🔁 | reverse of `ItemDB.npcDrops` | Large; build lazily |
| 7b | NPC page: what it sells | 🔁 | reverse of `ItemDB.vendors` | |
| 7c | NPC page: quests started/ended | ✅ | `NpcDB.questStarts/questEnds` | |
| 7d | Creature type, family, health, abilities | ❌ | none (health removed) | Would need a creature source |
| 8 | Auction / market value | ❌ | out of scope (Auctionator etc., not offline-authoritative) | |

---

## 11. Recommended next steps

1. Run the in-game checks in section 9. They're the gate for the whole design.
2. Approve or adjust the architecture (providers → index → query → UI) and the hard vs. optional dependency choice.
3. Decide which gaps (section 10, ❌ rows) matter for v1. My suggestion: ship without drop rates and skinning, and show explicit "unknown" markers.
4. Then implement in this order: providers → small indexes → `/pyro item <id>` chat output for 3182 → UI.

## Sources

- LibItemDB v1.9.0 README and Forever data: https://www.curseforge.com/wow/addons/libitemdb
- AtlasLootClassic Continued: https://www.curseforge.com/wow/addons/atlasloot-continued
- AtlasLoot Classic Forever: https://www.curseforge.com/wow/addons/atlasloot-forever/files/9049680
- Lexicon client article (Warcraft Tavern): https://www.warcrafttavern.com/forever/news/help-build-a-better-database-for-wow-forever-with-the-lexicon-client/
- CMaNGOS classic-db (GPL-3.0): https://github.com/cmangos/classic-db
- QuestieDB repository and `docs/api.md`, `docs/forever.md`, `docs/read-performance.md`, `LICENSE.md`: https://github.com/Questie/QuestieDB
- LibProfessionDB project, v1.10.0 README and data: https://www.curseforge.com/wow/addons/libprofessiondb
- TOC format and the 16001 Forever interface example: https://warcraft.wiki.gg/wiki/TOC_format
