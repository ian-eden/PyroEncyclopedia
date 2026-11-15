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
- Public API: `PyroEncyclopedia.RequestItemReport`, `GetItemReport`, `GetProviderStatus`.
