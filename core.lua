-- Translate these at some point
local lootmessage = '[Loot %s +%d(%d)]'
local moneymessage = '[Loot +%s]'

-- Change this if you don't like the compact money format
local moneyformat = function(g, s, c)
    return ('%s%s%s'):format(gold and ('%sg'):format(gold) or '',
                             silver and ('%ss'):format(silver) or '',
                             copper and ('%sc'):format(copper) or '')
end
local msg

local LootAlert = CreateFrame('Frame', nil, UIParent)
LootAlert:SetScript('OnEvent', function(self, event, ...)
    self[event](self, ...)
end)
LootAlert:RegisterEvent('ADDON_LOADED')

function LootAlert:ADDON_LOADED(name)
    if name == 'LootAlert' then
        if MikSBT then
            msg = function(message, color)
                MikSBT.DisplayMessage(message, MikSBT.DISPLAYTYPE_NOTIFICATION, false, color.r * 255, color.g * 255, color.b * 255)
            end
        elseif SCT_Display then
            msg = SCT_Display_Message
        elseif SCT and SCT.DisplayText then
            msg = function(message, color)
                SCT:DisplayMessage(message, color)
            end
        end
    end

    if name == 'Blizzard_CombatText' or CombatText_AddMessage then
        msg = function(message, color)
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b, 'sticky', nil)
        end
    end

    if msg then
        self:RegisterEvent('CHAT_MSG_LOOT')
        self:RegisterEvent('CHAT_MSG_MONEY')
        self:UnregisterEvent('ADDON_LOADED')
    end
end

local solo = YOU_LOOT_MONEY:gsub('%%s', '(.*)')
local grouped = LOOT_MONEY_SPLIT:gsub('%%s', '(.*)')
local white = {r = 1, g = 1, b = 1}
function LootAlert:CHAT_MSG_MONEY(chatmsg)
    local moneys = chatmsg:match(solo) or chatmsg:match(grouped)
    if not moneys then
        return
    end

    local gold   = moneys:match(('(%%d+) %s'):format(GOLD))
    local silver = moneys:match(('(%%d+) %s'):format(SILVER))
    local copper = moneys:match(('(%%d+) %s'):format(COPPER))
    local out = moneymessage:format(moneyformat(gold, silver, copper))
    msg(out, white)
end

local linkpat = '|c........|Hitem:(%%d+):.-|r'
local single = LOOT_ITEM_SELF:gsub('%%s', linkpat)
local multiple = LOOT_ITEM_SELF_MULTIPLE:gsub('%%d', '(%%d+)'):gsub('%%s', linkpat)
function LootAlert:CHAT_MSG_LOOT(chatmsg)
    local item, count = chatmsg:match(multiple)
    if not item then
        item = chatmsg:match(single)
        count = 1
    end

    if item then
        local oldtotal = GetItemCount(item)
        local name, _, rarity = GetItemInfo(item)
        local color = ITEM_QUALITY_COLORS[rarity]
        local out = lootmessage:format(name, count, oldtotal + count)

        msg(out, color)
    end
end
