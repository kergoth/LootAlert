local strmatch, strformat = string.match, string.format
local lootmessage, moneymessage, moneyformat

if GetLocale() == 'zhTW' then
    lootmessage = '拾取: %s%s|r%s'
    moneymessage = '拾取: +%s%s%s'
else
    lootmessage = 'Loot: %s%s|r%s'
    moneymessage = 'Loot: +%s%s%s'
end

local LootAlert = CreateFrame('Frame', nil, UIParent)
LootAlert:SetScript('OnEvent', function(self, event, ...)
    self[event](self, ...)
end)
LootAlert:RegisterEvent('PLAYER_LOGIN')

local function msg(message)
    UIErrorsFrame:AddMessage(message)
end
local ITEM_QUALITY_COLORPATS = {}
local color = {r=1, g=1, b=1}
function LootAlert:PLAYER_LOGIN()
    if MikSBT then
        msg = function(message)
            MikSBT.DisplayMessage(message, MikSBT.DISPLAYTYPE_STATIC, false, color.r * 255, color.g * 255, color.b * 255)
        end
    elseif SCT_Display then
        msg = SCT_Display_Message
    elseif SCT and SCT.DisplayText then
        msg = function(message)
            SCT:DisplayMessage(message, color)
        end
    elseif CombatText_AddMessage then
        msg = function(message)
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b, "sticky")
        end
    end

    self:RegisterEvent('CHAT_MSG_LOOT')
    self:RegisterEvent('CHAT_MSG_MONEY')

    for k, v in pairs(ITEM_QUALITY_COLORS) do
        ITEM_QUALITY_COLORPATS[k] = strformat("|cff%x%x%x", 255 * v.r, 255 * v.g, 255 * v.b)
    end
end

local solo = YOU_LOOT_MONEY:gsub('%%s', '(.*)')
local grouped = LOOT_MONEY_SPLIT:gsub('%%s', '(.*)')
function LootAlert:CHAT_MSG_MONEY(chatmsg)
    local moneys = strmatch(chatmsg, solo) or strmatch(chatmsg, grouped)
    if not moneys then
        return
    end

    local gold = strmatch(moneys, strformat('(%%d+) %s', GOLD))
    local silver = strmatch(moneys, strformat('(%%d+) %s', SILVER))
    local copper = strmatch(moneys, strformat('(%%d+) %s', COPPER))
    local out = strformat(moneymessage, gold and strformat('|cffffd700%sg', gold) or '',
                                        silver and strformat('|cffc7c7cf%ss', silver) or '',
                                        copper and strformat('|cffeda55f%sc', copper) or '')

    msg(out)
end

local linkpat = '|c........|Hitem:(%%d+):.-|r'
local single = LOOT_ITEM_SELF:gsub('%%s', linkpat)
local multiple = LOOT_ITEM_SELF_MULTIPLE:gsub('%%d', '(%%d+)'):gsub('%%s', linkpat)
function LootAlert:CHAT_MSG_LOOT(chatmsg)
    local item, count = strmatch(chatmsg, multiple)
    if not item then
        item = strmatch(chatmsg, single)
        count = 1
    end

    if item then
        local oldtotal = GetItemCount(item)
        local name, _, rarity = GetItemInfo(item)
        local color = ITEM_QUALITY_COLORPATS[rarity]

        local rest = ""
        if oldtotal > 0 then
            rest = strformat(" +%d(%d)", count, oldtotal + count)
        elseif count > 1 then
            rest = strformat(" +%d", count)
        end

        local out = strformat(lootmessage, color, name, rest)
        msg(out)
    end
end
