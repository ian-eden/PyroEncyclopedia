# Contributing

Thanks for helping. A few ground rules keep the project maintainable.

## Principles

- **No shipped data.** PyroEncyclopedia reads QuestieDB, LibProfessionDB and LibItemDB at
  runtime through their public APIs. Do not copy their data files, or tables generated from
  them, into this repository. Indexes are built in memory at runtime.
- **All upstream access goes through `Providers/`.** Feature-detect every library function
  before calling it, and degrade to "unknown" instead of erroring.
- **Never stall the game.** Anything that scans a whole database runs as a `Scheduler` job
  and yields. Tooltip code may only use constant-time lookups.
- **Report data errors upstream.** If an item's data is wrong, it is usually wrong in a
  library; open the issue there.

## Layout

```
PyroEncyclopedia.toc   load order
Locales/               user-facing strings (enUS is the fallback)
Core/                  utilities, scheduler, zone naming, startup and slash commands
Providers/             one adapter per data source
Index/                 runtime reverse indexes
Query/                 report builders that merge providers (plain data, no UI)
UI/                    renderers (chat today; tooltip and window next)
docs/                  design notes and research (not packaged)
```

## Development setup

1. Clone into the Forever client's `Interface/AddOns/PyroEncyclopedia` folder, or symlink
   (Windows: directory junction) the clone there.
2. Install the data libraries listed in the README.
3. Edit, then `/reload` in game. `/pyroenc status` shows provider and index state.
4. Lint with [luacheck](https://github.com/lunarmodules/luacheck): `luacheck .` (CI runs this
   on every push).

For editor completion, point LuaLS at QuestieDB's shipped declarations: `.luarc.json` already
adds `../QuestieDB/Types` to the workspace library.

## Releases

Push a `vX.Y.Z` tag. The GitHub workflow runs the BigWigs packager, which replaces
`@project-version@` in the TOC and attaches a zip to a GitHub release. CurseForge upload
starts automatically once a `CF_API_KEY` secret and an `X-Curse-Project-ID` TOC line exist.
