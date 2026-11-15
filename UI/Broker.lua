-- LibDataBroker launcher: shows a PyroEncyclopedia button on Titan Panel (and ChocolateBar,
-- Bazooka, ...). Titan: right-click the bar and enable "PyroEncyclopedia" to show it.
local _, ns = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if not LDB then return end

local L = ns.L

LDB:NewDataObject("PyroEncyclopedia", {
    type = "launcher",
    label = "PyroEnc",
    icon = "Interface\\Icons\\INV_Misc_Book_09",

    OnClick = function(_, button)
        if button == "RightButton" then
            ns.Tooltip.SetEnabled(not ns.db.tooltip.enabled)
        else
            ns.Window.Toggle()
        end
    end,

    OnTooltipShow = function(tt)
        tt:AddLine("|cffff7f00Pyro|rEncyclopedia")
        tt:AddLine(L["BROKER_CLICK"], 0.8, 0.8, 0.8)
        tt:AddLine(L["BROKER_RIGHT_CLICK"]:format(
            ns.db.tooltip.enabled and L["ON"] or L["OFF"]), 0.8, 0.8, 0.8)
    end,
})
