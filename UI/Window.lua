-- The lookup window: search box and results on the left, the selected item's page on the
-- right. Built on first use with the same stock templates PyroLooter uses on Forever.
local _, ns = ...

local Window = {}
ns.Window = Window

local U, L = ns.Util, ns.L

local WIDTH, HEIGHT = 840, 540
local LEFT_W = 250
local ROW_H = 20
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local frame

-- Search --------------------------------------------------------------------------------

local function itemRows(text)
    local IDB, Q = ns.Providers.LibItemDB, ns.Providers.Questie
    if IDB:IsAvailable() and IDB.lib.BuildWhereSearchRows then
        local rows, capped = IDB.lib:BuildWhereSearchRows(text)
        return rows or {}, capped
    end
    local id = Q:FindItemByName(text)          -- exact name only without LibItemDB
    if id then return { { id = id, name = Q:GetItemName(id) } }, false end
    return {}, false
end

-- One result row's text. kind: "header" (section title), "item" or "npc".
local function rowText(row)
    if row.kind == "header" then return U.Gold(row.text) end
    if row.kind == "npc" then
        local npc = ns.Providers.Questie:GetNpc(row.id)
        local lvl = npc and U.LevelRange(npc.minLevel, npc.maxLevel)
        return "|cff7fc8ff" .. (npc and npc.name or tostring(row.id)) .. "|r" .. (lvl and U.Gray(" " .. lvl) or "")
    end
    local extra = row.itemLevel and row.itemLevel > 0 and U.Gray(" " .. row.itemLevel) or ""
    return U.QualityName(row.id, row.plainName or row.name) .. extra
end

local function rowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.kind == "item" then
        GameTooltip:SetHyperlink("item:" .. self.id)
    else
        local npc = ns.Providers.Questie:GetNpc(self.id)
        GameTooltip:AddLine(npc and npc.name or tostring(self.id), 0.5, 0.78, 1)
        if npc and npc.subName then GameTooltip:AddLine("<" .. npc.subName .. ">", 1, 1, 1) end
        if npc and npc.zones[1] then GameTooltip:AddLine(ns.Zones.NameForArea(npc.zones[1].areaId), 1, 1, 1) end
        GameTooltip:AddLine(L["WIN_CLICK_TO_OPEN"], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function setResults(rows, message)
    local list = frame.results
    for i, row in ipairs(rows) do
        local b = list.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, list.content)
            b:SetHeight(ROW_H)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            b:SetPoint("RIGHT", list.content, "RIGHT")
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 4, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b:SetScript("OnClick", function(self) if self.id then Window.Show(self.kind, self.id) end end)
            b:SetScript("OnEnter", function(self) if self.id then rowTooltip(self) end end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            list.buttons[i] = b
        end
        b.kind = row.kind
        b.id = row.kind ~= "header" and row.id or nil
        b:SetEnabled(b.id ~= nil)
        b.text:SetText(rowText(row))
        b:Show()
    end
    for i = #rows + 1, #list.buttons do list.buttons[i]:Hide() end
    list.content:SetHeight(math.max(1, #rows * ROW_H))
    list:SetVerticalScroll(0)
    frame.resultInfo:SetText(message or "")
end

local function runSearch()
    local text = (frame.search:GetText() or ""):match("^%s*(.-)%s*$")
    local id = U.ParseItemId(text)
    if id then Window.ShowItem(id); return end
    if #text < 3 then setResults({}, L["WIN_TYPE_MORE"]); return end

    -- The NPC name list is built the first time it's needed; search again once it's ready.
    if ns.Providers.Questie:IsAvailable() and not ns.Index.IsReady("npcNames") then
        ns.Index.Ensure({ "npcNames" }, function()
            if frame.search:GetText():match("^%s*(.-)%s*$") == text then runSearch() end
        end)
    end

    local items, itemsCapped = itemRows(text)
    local npcs, npcsCapped = ns.Index.FindNpcs(text)
    local sections = {
        { title = L["WIN_ITEMS"], kind = "item", rows = items, capped = itemsCapped },
        { title = L["WIN_NPCS"], kind = "npc", rows = npcs, capped = npcsCapped },
    }
    -- Typing a monster's exact name lists the monsters first.
    if npcs[1] and (ns.Providers.Questie.Npc.name(npcs[1]) or ""):lower() == text:lower() then
        sections[1], sections[2] = sections[2], sections[1]
    end

    local rows, capped = {}, false
    for _, s in ipairs(sections) do
        if #s.rows > 0 then
            rows[#rows + 1] = { kind = "header", text = ("%s (%d%s)"):format(s.title, #s.rows, s.capped and "+" or "") }
            for _, r in ipairs(s.rows) do
                if s.kind == "npc" then
                    rows[#rows + 1] = { kind = "npc", id = r }
                else
                    r.kind = "item"
                    rows[#rows + 1] = r
                end
            end
            capped = capped or s.capped
        end
    end
    local message = #rows == 0 and L["WIN_NO_RESULTS"] or capped and L["WIN_RESULTS_CAPPED"] or nil
    setResults(rows, message)
end

-- Pages (item / quest / npc / recipe, see UI/Pages.lua) ----------------------------------

local history = {}

local function render(kind, id)
    local page = frame.page
    if page.kind ~= kind or page.id ~= id then return end   -- user moved on meanwhile
    local ok, result = pcall(ns.Pages[kind].build, id)
    if not ok then
        geterrorhandler()(result)
        result = { title = tostring(id), facts = "", lines = { U.Gray(L["PAGE_UNKNOWN"]) } }
    end
    page.title:SetText(result.title or "")
    page.facts:SetText(result.facts or "")
    page.icon:SetTexture(result.icon or QUESTION_ICON)
    page.body:SetText(table.concat(result.lines or {}, "\n"))
    page.content:SetHeight(page.body:GetStringHeight() + 20)
    page.scroll:SetVerticalScroll(0)
end

--- Show a page. kind: "item" | "quest" | "npc" | "recipe"; id: number, or "profId-spellId".
function Window.Show(kind, id, fromBack)
    local def = ns.Pages[kind]
    if not def or id == nil then return end
    Window.Open()
    local page = frame.page
    if page.kind and not fromBack and not (page.kind == kind and page.id == id) then
        history[#history + 1] = { page.kind, page.id }
    end
    page.kind, page.id = kind, id
    frame.back:SetEnabled(#history > 0)
    page.title:SetText("")
    page.facts:SetText("")
    page.body:SetText(L["BUILDING"])
    ns.Index.Ensure(def.needs, function() render(kind, id) end)
    if kind == "item" then
        -- Names and icons of items the client has never seen arrive a moment later.
        ns.Providers.Client:RequestItem(id, function()
            local ready = true
            for _, name in ipairs(def.needs) do ready = ready and ns.Index.IsReady(name) end
            if ready and frame:IsShown() then render(kind, id) end
        end)
    end
end

function Window.ShowItem(itemId)
    Window.Show("item", tonumber(itemId))
end

function Window.Back()
    local prev = table.remove(history)
    if prev then Window.Show(prev[1], prev[2], true) end
end

local function parseLink(link)
    local kind, id = tostring(link):match("^pyroenc:(%a+):(.+)$")
    if not kind then return nil end
    return kind, kind == "recipe" and id or tonumber(id)
end

-- Construction --------------------------------------------------------------------------

local function createScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll
end

local function create()
    local f = CreateFrame("Frame", "PyroEncyclopediaFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "PyroEncyclopediaFrame") -- Escape closes it

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cffff7f00Pyro|rEncyclopedia")

    -- Left: search box, result count, results list.
    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(LEFT_W - 20, 22)
    search:SetPoint("TOPLEFT", 22, -32)
    search:SetAutoFocus(false)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); runSearch() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then return end
        f.searchSerial = (f.searchSerial or 0) + 1
        local serial = f.searchSerial
        C_Timer.After(0.3, function() if f.searchSerial == serial then runSearch() end end)
    end)
    f.search = search

    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["WIN_SEARCH_HINT"])
    search:HookScript("OnEditFocusGained", function() hint:Hide() end)
    search:HookScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)

    f.resultInfo = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.resultInfo:SetPoint("TOPLEFT", 16, -60)
    f.resultInfo:SetWidth(LEFT_W - 10)
    f.resultInfo:SetJustifyH("LEFT")

    local results = createScroll(f)
    results:SetPoint("TOPLEFT", 12, -76)
    results:SetPoint("BOTTOMLEFT", 12, 10)
    results:SetWidth(LEFT_W - 28)
    results.content:SetWidth(LEFT_W - 28)
    results.buttons = {}
    f.results = results

    -- Right: icon, title, facts line, scrolling body.
    local page = {}
    local x = LEFT_W + 14
    page.icon = f:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(36, 36)
    page.icon:SetPoint("TOPLEFT", x, -32)
    page.icon:SetTexture(QUESTION_ICON)

    local back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    back:SetSize(70, 22)
    back:SetPoint("TOPRIGHT", -16, -32)
    back:SetText(L["WIN_BACK"])
    back:SetEnabled(false)
    back:SetScript("OnClick", Window.Back)
    f.back = back

    local titleButton = CreateFrame("Button", nil, f)
    titleButton:SetPoint("TOPLEFT", page.icon, "TOPRIGHT", 8, 0)
    titleButton:SetPoint("RIGHT", back, "LEFT", -8, 0)
    titleButton:SetHeight(20)
    page.title = titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.title:SetAllPoints()
    page.title:SetJustifyH("LEFT")
    page.title:SetWordWrap(false)
    titleButton:SetScript("OnEnter", function(self)
        if page.kind ~= "item" then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetHyperlink("item:" .. page.id)
        GameTooltip:Show()
    end)
    titleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    page.facts = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.facts:SetPoint("BOTTOMLEFT", page.icon, "BOTTOMRIGHT", 8, 2)
    page.facts:SetJustifyH("LEFT")

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", x, -74)
    divider:SetPoint("TOPRIGHT", -16, -74)

    local bodyWidth = WIDTH - x - 40
    page.scroll = createScroll(f)
    page.scroll:SetPoint("TOPLEFT", x, -80)
    page.scroll:SetPoint("BOTTOMRIGHT", -32, 10)
    page.content = page.scroll.content
    page.content:SetWidth(bodyWidth)
    page.body = page.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.body:SetPoint("TOPLEFT")
    page.body:SetWidth(bodyWidth)
    page.body:SetJustifyH("LEFT")
    page.body:SetJustifyV("TOP")
    page.body:SetSpacing(2)
    page.body:SetText(L["WIN_WELCOME"])
    f.page = page

    -- Clickable names in the page text (see Util.Link): click opens that page; hovering an
    -- item or recipe shows the game's own tooltip for it.
    local content = page.content
    if content.SetHyperlinksEnabled then
        content:EnableMouse(true)
        content:SetHyperlinksEnabled(true)
        content:SetScript("OnHyperlinkClick", function(_, link)
            local kind, id = parseLink(link)
            if kind then Window.Show(kind, id) end
        end)
        content:SetScript("OnHyperlinkEnter", function(self, link)
            local kind, id = parseLink(link)
            if not kind then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            if kind == "item" then
                GameTooltip:SetHyperlink("item:" .. id)
            elseif kind == "recipe" then
                local spellId = tostring(id):match("%-(%d+)$")
                if not pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. spellId) then
                    GameTooltip:AddLine(L["WIN_CLICK_TO_OPEN"])
                end
            else
                GameTooltip:AddLine(L["WIN_CLICK_TO_OPEN"], 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    end

    frame = f   -- setResults below reads the shared `frame`, so register it first
    setResults({}, L["WIN_TYPE_MORE"])
    return f
end

-- Shift-clicking an item (bags, chat, loot) while the search box has focus looks it up.
local function onInsertLink(link)
    if not (frame and frame:IsShown() and frame.search:HasFocus() and type(link) == "string") then return end
    local id = link:match("item:(%d+)")
    if not id then return end
    frame.search:SetText(link:match("%[(.-)%]") or id)
    frame.search:ClearFocus()
    Window.ShowItem(id)
end

function Window.Init()
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onInsertLink) end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink) end
end

function Window.Open()
    frame = frame or create()
    frame:Show()
end

function Window.Toggle()
    frame = frame or create()
    frame:SetShown(not frame:IsShown())
end

--- Open the window on `text`: an item id or link shows that item, anything else searches.
function Window.Search(text)
    Window.Open()
    frame.search:SetText(text or "")
    runSearch()
end
