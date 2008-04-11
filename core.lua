-- Simple addon that displays information about what was looted in Mik's
-- Scrolling Battle Text.  It keeps total counts of all the items in your
-- inventory so as to show that as well as the amount just looted.

local itemidpat = "(%d+):%d+:%d+:%d+"
local linkpat = '|c........|Hitem:'..itemidpat..'.*|r'
local function getitemid(itemlink)
    local _, _, itemid = string.find(itemlink or "", itemidpat)
    return itemid
end


LootAlert = {}

function LootAlert:ADDON_LOADED(arg1)
    if arg1 == "LootAlert" and (MikSBT or SCT_Display or SCT) then
        this:RegisterEvent("CHAT_MSG_LOOT")
        this:UnregisterEvent("ADDON_LOADED")
    end
end

local escaped = string.gsub(linkpat, '%%', '%%%%')
local single = string.gsub(LOOT_ITEM_SELF, '%%s', escaped)
local multiple = string.gsub(string.gsub(LOOT_ITEM_SELF_MULTIPLE, '%%d', '(%%d+)'),
                             '%%s', escaped)

function LootAlert:CHAT_MSG_LOOT(msg)
    local _, _, item, count = string.find(msg, multiple)
    if not item then
        _, _, item = string.find(msg, single)
        count = 1
    end

    if item then
        local oldtotal = GetItemCount(item)
        local name, _, rarity = GetItemInfo(item)
        local message = "[Loot " .. name .. " +" .. count .. "(" .. oldtotal + count .. ")]"
        local color = ITEM_QUALITY_COLORS[rarity]

        if MikSBT then
            MikSBT.DisplayMessage(message, MikSBT.DISPLAYTYPE_NOTIFICATION, false, color.r * 255, color.g * 255, color.b * 255)
        elseif SCT_Display or (SCT and SCT.DisplayText) then
            if SCT_Display then
                SCT_Display_Message(message, color)
            else
                SCT:DisplayMessage(message, color)
            end
        elseif CombatText_AddMessage then
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b, "sticky", nil)
        end
    end
end

-- Initialization
LootAlert.frame = CreateFrame("Frame", nil, UIParent)
LootAlert.frame:SetScript("OnEvent", function(self, event, ...)
    LootAlert[event](LootAlert, ...)
end)
LootAlert.frame:RegisterEvent("ADDON_LOADED")
