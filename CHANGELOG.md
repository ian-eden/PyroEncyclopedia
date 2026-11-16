# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/); releases are cut from `v*` git tags.

## [Unreleased]

### Added
- Data providers for QuestieDB, LibProfessionDB, LibItemDB and the game client, each optional
  and feature-detected.
- Runtime reverse indexes: recipes that use / create / are taught by an item, and quests that
  need an item. Built in the background without stalling the game.
- Lookup window (`/pyroenc`): item search, shift-click an item to look it up, item page with
  drops, vendors, recipes and quests. `/pyroenc print <item>` prints the same to chat.
- `/pyroenc status` explains why a database addon is not loaded.
- Item tooltip lines: best drop, vendor and price, recipes using it, related quests
  (`/pyroenc tooltip` toggles them).
- Titan Panel / data-broker button: click opens the window, right-click toggles tooltip lines.
- Clickable names in the window: quest, NPC and recipe pages, item links everywhere, and a
  Back button.
- Monster / NPC search: the search box lists matching monsters next to items; click one to
  see its level, zones, quests, drops and wares.
- Public API: `PyroEncyclopedia.RequestItemReport`, `GetItemReport`, `GetProviderStatus`.
