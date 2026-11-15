# PyroEncyclopedia

An offline, in-game item encyclopedia for **World of Warcraft: Forever**. Look up any item and
see where it drops, who sells it, which chests or nodes have it, which quests reward or need it,
and which recipes make or use it, without alt-tabbing to a database website.

> **Status: early development.** The lookup window works; a mouse-over tooltip is planned.

## How it works

PyroEncyclopedia ships **no item database of its own**. It reads three community-maintained
data libraries at runtime and merges what they know into one view:

| Library | Provides |
| --- | --- |
| [QuestieDB](https://github.com/Questie/QuestieDB) | Quests, NPCs, objects, spawn locations; complete dropper and vendor lists |
| [LibProfessionDB](https://www.curseforge.com/wow/addons/libprofessiondb) (folder `ProfessionDB`) | Every crafting recipe: reagents, results, skill levels, where to learn it |
| [LibItemDB](https://www.curseforge.com/wow/addons/libitemdb) (folder `ItemDB`) | Item properties and stats, drop chances, vendor prices, boss loot |

When those libraries update their data, PyroEncyclopedia shows the new data after a `/reload`.
No PyroEncyclopedia update is needed for data changes.

Each library is **optional**. PyroEncyclopedia shows whatever the installed ones can answer,
but you get the full picture only with all three.

## Installation

1. Install the data libraries (and their own requirements):
   - **QuestieDB**: download the latest release zip from
     [github.com/Questie/QuestieDB/releases](https://github.com/Questie/QuestieDB/releases/latest).
     Use the release zip rather than a git clone; the release is much faster and lighter.
   - **LibProfessionDB** and **LibItemDB** from CurseForge. They require **Ace3**,
     **VersionCheck-1.0** and (LibItemDB) **LibAceGUIWidgets**, which the CurseForge app installs
     automatically.
2. Install PyroEncyclopedia into the Forever client's `Interface/AddOns/` folder, so that the path
   ends in `Interface/AddOns/PyroEncyclopedia/PyroEncyclopedia.toc`.
3. Log in and run `/pyroenc status` to check that every data source is detected.

## Usage

| Command | What it does |
| --- | --- |
| `/pyroenc` | Open or close the lookup window |
| `/pyroenc <name \| id \| item link>` | Open the window and look it up |
| `/pyroenc print <name \| id \| item link>` | Print the lookup to chat instead |
| `/pyroenc status` | Show which databases are loaded, or why one isn't |

In the window, type at least three letters of an item name, or click into the search box and
shift-click any item in your bags, chat or loot window.

Example: Spider's Silk shows its droppers with drop chances and zones, and the 22 Tailoring
and Leatherworking recipes that use it, with where to learn each one.

## Data accuracy

PyroEncyclopedia shows what its sources know, and says so when they don't:

- Much drop and spawn data is derived from **Classic** emulator data and has not been verified
  on Forever.
- Some Forever recipe sources are **borrowed from Vanilla**; these are marked *unconfirmed*.
- Skinning, pickpocketing, fishing and disenchanting yields are not covered by any source yet.
- Loot from Forever's new raids and dungeons is incomplete.

Report data errors to the library that owns the data (see the table above). Report display
problems or crashes [here](../../issues).

## Roadmap

1. **Done:** lookup window with item search and an item page.
2. **Next:** a short mouse-over tooltip line (for example "Used in 22 recipes").
3. Maybe later: clickable NPCs and recipes on the item page, localization.

The technical background is in [docs/research/01-technical-assessment.md](docs/research/01-technical-assessment.md).

## For addon authors

A small public API is available once the addon has loaded:

```lua
PyroEncyclopedia.RequestItemReport(3182, function(report)
    print(report.name, report.drops.total, report.recipesUsing.total)
end)
PyroEncyclopedia.GetProviderStatus()
```

The report table's shape may still change before version 1.0.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License and credits

PyroEncyclopedia's own code is released under the [MIT License](LICENSE).

It **does not include or redistribute** any data from the libraries above. Their data stays
under their own licences and belongs to their authors: QuestieDB (Questie team and
contributors), LibProfessionDB and LibItemDB (Pimptasty, MIT), and the upstream sources they
credit (CMaNGOS, AtlasLoot, WoWSims, AllTheThings, wago.tools). PyroEncyclopedia is not
affiliated with Questie, Blizzard Entertainment or Wowhead.
