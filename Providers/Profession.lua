-- Adapter for LibProfessionDB-1.0 (addon folder "ProfessionDB"). Recipes are keyed by craft
-- spell id. Newer functions are feature-detected, per the library's own guidance.
local _, ns = ...

ns.Providers = ns.Providers or {}
local P = { key = "profession", title = "LibProfessionDB", available = false, status = nil }
ns.Providers.Profession = P

local MAJOR = "LibProfessionDB-1.0"

function P:Detect()
    local lib, minor
    if LibStub then lib, minor = LibStub:GetLibrary(MAJOR, true) end
    if not lib then
        self.available, self.status = false, ns.L["NOT_INSTALLED"]
        return false
    end
    if not lib:IsReady() then
        local game = lib.GetGameVersion and lib:GetGameVersion() or "?"
        self.available, self.status = false, ("loaded, but no data for this client (game version '%s')"):format(game)
        return false
    end
    self.lib, self.minor = lib, minor
    self.available = true
    self.status = ("MINOR %s, %s, %d recipes"):format(tostring(minor),
        lib.GetGameVersion and lib:GetGameVersion() or "?", lib:Count())
    return true
end

function P:IsAvailable() return self.available end

function P:IsBorrowed(spellId, field)
    return self.lib.IsBorrowed and self.lib:IsBorrowed(spellId, field) ~= nil or false
end

-- Normalized recipe for display. `itemId` selects the reagent quantity to report.
function P:GetRecipeInfo(profId, spellId, itemId)
    local r = self.lib:GetRecipe(profId, spellId)
    if not r then return nil end
    local lib = self.lib
    return {
        profId = profId,
        spellId = spellId,
        name = lib:GetName(profId, spellId) or r.name,
        qty = itemId and r.reagents and r.reagents[itemId] or nil,
        reagents = r.reagents,
        craftedItemId = r.craftedItemId,
        requiredSkill = r.requiredSkill,
        requiredSkillBorrowed = self:IsBorrowed(spellId, "requiredSkill"),
        hidden = lib.IsHiddenRecipe and lib:IsHiddenRecipe(spellId) or false,
        autoLearned = lib.IsAutoTaughtRecipe and lib:IsAutoTaughtRecipe(spellId) or false,
    }
end

-- { {kind = "trainer", total = n, entries = {{id, name, faction, cost}, ...}}, ... } or nil.
function P:GetSources(spellId)
    if not self.lib.GetRecipeSources then return nil end
    local src = self.lib:GetRecipeSources(spellId)
    if not src then return nil end
    local out = {}
    for _, kind in ipairs({ "trainer", "vendor", "quest", "container", "drop" }) do
        local list = src[kind]
        if list then out[#out + 1] = { kind = kind, total = list.total or #list, entries = list } end
    end
    out.borrowed = self:IsBorrowed(spellId, "sources")
    return out
end

function P:VersionTag()
    return self.available and ("MINOR" .. tostring(self.minor)) or "none"
end
