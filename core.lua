local moneyicon = "Interface\\Icons\\INV_Ore_Gold_01"
local white = {r=1, g=1, b=1}
local config = {
    itemraritycolor = true,
    moneycolor = true,

    msbt = {
        scrollarea = "Static",
        sticky = false,
        color = white,
        icon = true,
    },
    sct = {
        scrollarea = 1,
        sticky = true,
        color = white,
        icon = true,
    },
    fct = {
        sticky = true,
        color = white,
    },
    uierrorsframe = {
        color = white,
    },
}
local cfg = config.uierrorsframe
local function msg(message)
    UIErrorsFrame:AddMessage(message, cfg.color.r, cfg.color.g, cfg.color.b)
end

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

local ITEM_QUALITY_COLORPATS = {}
function LootAlert:PLAYER_LOGIN()
    if MikSBT then
        cfg = config.msbt
        local msbteventsettings = {
            colorR = cfg.color.r,
            colorG = cfg.color.g,
            colorB = cfg.color.b,
            scrollArea = cfg.scrollarea,
            isCrit = cfg.sticky,
        }
        local DisplayEvent = MikSBT.Animations.DisplayEvent
        msg = function(message, tex)
            DisplayEvent(msbteventsettings, message, cfg.icon and tex)
        end
    elseif SCT and SCT.DisplayText then
        cfg = config.sct
        msg = function(message, tex)
            SCT:DisplayText(message, cfg.color, cfg.sticky, "event", cfg.scrollarea, nil, nil, cfg.icon and tex)
        end
    elseif CombatText_AddMessage then
        cfg = config.fct
        msg = function(message, tex)
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, cfg.color.r, cfg.color.g, cfg.color.b, cfg.sticky and "crit")
        end
    end

    self:RegisterEvent('CHAT_MSG_LOOT')
    self:RegisterEvent('CHAT_MSG_MONEY')

    for k, v in pairs(ITEM_QUALITY_COLORS) do
        ITEM_QUALITY_COLORPATS[k] = strformat("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
    end
end

local solo = YOU_LOOT_MONEY:gsub('%%s', '(.*)')
local grouped = LOOT_MONEY_SPLIT:gsub('%%s', '(.*)')
local goldmatch = strformat('(%%d+) %s', GOLD)
local silvermatch = strformat('(%%d+) %s', SILVER)
local coppermatch = strformat('(%%d+) %s', COPPER)
local goldpat = config.moneycolor and '|cffffd700%sg ' or '%sg '
local silverpat = config.moneycolor and '|cfffc7c7cf%ss ' or '%ss '
local copperpat = config.moneycolor and '|cffeda55f%sc' or '%sc'
function LootAlert:CHAT_MSG_MONEY(chatmsg)
    local moneys = strmatch(chatmsg, solo) or strmatch(chatmsg, grouped)
    if not moneys then
        return
    end

    local gold = strmatch(moneys, goldmatch)
    local silver = strmatch(moneys, silvermatch)
    local copper = strmatch(moneys, coppermatch)
    local out = strformat(moneymessage, gold and strformat(goldpat, gold) or '',
                                        silver and strformat(silverpat, silver) or '',
                                        copper and strformat(copperpat, copper) or '')

    msg(out, moneyicon)
end

local linkpat = '|c........|Hitem:(%%d+):.-|r'
local single = LOOT_ITEM_SELF:gsub('%%s', linkpat)
local multiple = LOOT_ITEM_SELF_MULTIPLE:gsub('%%d', '(%%d+)'):gsub('%%s', linkpat)
function LootAlert:CHAT_MSG_LOOT(chatmsg)
    local item, count = strmatch(chatmsg, multiple)
    if not item then
        item = strmatch(chatmsg, single)
        count = 1
    else
        count = tonumber(count)
    end

    if item then
        local oldtotal = GetItemCount(item)
        local name, _, rarity, _, _, _, _, _, _, tex = GetItemInfo(item)
        local color = config.itemraritycolor and ITEM_QUALITY_COLORPATS[rarity] or ""

        local rest = " "
        if count > 1 then
            rest = " +"..count
        end
        if oldtotal > 0 then
            rest = rest .. "("..oldtotal+count..")"
        end

        local out = strformat(lootmessage, color, name, rest)
        msg(out, tex)
    end
end
