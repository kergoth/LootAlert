-- LootAlert is a simple addon that displays what items you've looted, how
-- many, and what the total number of that item is in your inventory. It
-- colors the item name in the message by item rarity, and displays looted
-- gold (colored by gold/silver/copper). It supports showing an icon for sct &
-- msbt. It can output to sct, msbt, blizzard fct, or the UIErrorsFrame.

-- Locals {{{1
local moneyicon = "Interface\\Icons\\INV_Ore_Gold_01"
local iconpath = "Interface\\AddOns\\LootAlert\\Icons"
local white = {r=1, g=1, b=1}
local match, format, gsub, sub = string.match, string.format, string.gsub, string.sub
local GetItemCount = GetItemCount
local select = select
local config, cfg, msg
local lootmessage, moneymessage, moneyformat
local db
-- }}}1

-- Utility Functions {{{1
local _tostring, _tonumber = tostring, tonumber
local tostring, tonumber
do
    function tostring(...)
        if select('#', ...) == 0 then
            return
        end
        return _tostring((select(1, ...))), tostring(select(2, ...))
    end
    function tonumber(...)
        if select('#', ...) == 0 then
            return
        end
        return _tonumber((select(1, ...))), tonumber(select(2, ...))
    end
end

local function print(...)
    DEFAULT_CHAT_FRAME:AddMessage(strjoin(" ", tostring(...)))
end

local isminver, twofour
do
    local version = GetBuildInfo()
    local vmaj, vmin, vrev = tonumber(strsplit(".", version))

    function isminver(maj, min, rev)
        if (not maj or vmaj >= maj) and
           (not min or vmin >= min) and
           (not rev or vrev >= rev) then
            return true
        else
            return false
        end
    end
    twofour = isminver(2, 4)
end

local function texlink(...)
    if not twofour or not db.icon then
        return ""
    end
    return "|T"..strjoin(":", ...).."|t"
end
-- }}}1

-- Localization {{{1
if GetLocale() == 'zhTW' then
    lootmessage = '拾取: %s%%s%s|r%s'
    moneymessage = '拾取: %s%s%s'
else
    lootmessage = 'Loot: %s%%s%s|r%s'
    moneymessage = 'Loot: %s%s%s'
end
-- }}}1

-- Chat {{{1
local function chatmsg(chattype, message, tex)
    local f = _G["ChatFrame"..db.chatframe]
    local font, height = f:GetFont()
    local texlink = tex and texlink(tex, height, height, 2, -5) or ""
    f:AddMessage(format(message, texlink), white.r, white.g, white.b)
end
-- }}}1

-- Initialization {{{1
LootAlert = LibStub("AceAddon-3.0"):NewAddon("LootAlert", "AceEvent-3.0", "AceConsole-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
-- local L = LibStub("AceLocale-3.0"):GetLocale("LootAlert")

local ITEM_QUALITY_COLORPATS = {}
local goldpat, silverpat, copperpat
local defaults = {
    profile = {
        enabled = true,

        itemraritycolor = true,
        moneyicons = true,

        chatoutput = true,
        chatframe = 4,

        icon = true,
        iconheight = 18,
        iconwidth = 18,

        msbt = {
            scrollarea = "Static",
            sticky = false,
            color = {
                r = white.r * 255,
                g = white.g * 255,
                b = white.b * 255,
            },
        },
        sct = {
            scrollarea = 1,
            sticky = false,
            color = white,
        },
        fct = {
            sticky = false,
            color = white,
        },
        uierrorsframe = {
            color = white,
        },
    },
}

function LootAlert:SetupMoneyPatterns()
    goldpat = "%s"
    silverpat = "%s"
    copperpat = "%s"

    if twofour and db.moneyicons then
        local height = db.iconheight
        local width = db.iconwidth
        goldpat = goldpat .. texlink(iconpath.."\\UI-GoldIcon", height, width, 2, -5)
        silverpat = silverpat .. texlink(iconpath.."\\UI-SilverIcon", height, width, 2, -5)
        copperpat = copperpat .. texlink(iconpath.."\\UI-CopperIcon", height, width, 2, -5)
    else
        goldpat = goldpat.."|cffffd700g|r "
        silverpat = silverpat.."|cffc7c7cfs|r "
        copperpat = copperpat.."|cffeda55fc|r"
    end
end

function LootAlert:OnInitialize()
    self.db = AceDB:New("LootAlertConfig", defaults)
    db = self.db.profile

    self:SetEnabledState(db.enabled)

    for k, v in pairs(ITEM_QUALITY_COLORS) do
        ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
    end

    self:RegisterEvent("PLAYER_LOGIN", "FirstLoad")
end

local msbteventsettings
function LootAlert:FirstLoad()
    if MikSBT then
        cfg = db.msbt
        msbteventsettings = {
            colorR = cfg.color.r,
            colorG = cfg.color.g,
            colorB = cfg.color.b,
            scrollArea = cfg.scrollarea,
            isCrit = cfg.sticky,
        }
        local DisplayEvent = MikSBT.Animations.DisplayEvent
        function LootAlert:msg(message, tex)
            DisplayEvent(msbteventsettings, format(message, ""), db.icon and tex)
        end
    elseif SCT and SCT.DisplayText then
        cfg = db.sct
        function LootAlert:msg(message, tex)
            SCT:DisplayText(format(message, ""), cfg.color, cfg.sticky, "event", cfg.scrollarea, nil, nil, db.icon and tex)
        end
    elseif CombatText_AddMessage then
        cfg = db.fct
        function LootAlert:msg(message, tex)
            local height = COMBAT_TEXT_HEIGHT
            local texlnk = tex and texlink(tex, height, height, 2, -5) or ""
            CombatText_AddMessage(format(message, texlnk), COMBAT_TEXT_SCROLL_FUNCTION, cfg.color.r, cfg.color.g, cfg.color.b, cfg.sticky and "crit")
        end
    else
        cfg = db.uierrorsframe
        function LootAlert:msg(message, tex)
            local f = UIErrorsFrame
            local _, height = f:GetFont()
            local texlnk = tex and texlink(tex, height, height, 2, -5) or ""
            f:AddMessage(format(message, texlnk), cfg.color.r, cfg.color.g, cfg.color.b)
        end
    end
    self:SetupMoneyPatterns()
end

function LootAlert:OnEnable()
    self:RegisterEvent('CHAT_MSG_LOOT')
    self:RegisterEvent('CHAT_MSG_MONEY')
end
-- }}}1

-- Loot Event Handling {{{1 {{{1
local solo = gsub(YOU_LOOT_MONEY, '%%s', '(.*)')
local grouped = gsub(LOOT_MONEY_SPLIT, '%%s', '(.*)')
local goldmatch = format('(%%d+) %s', GOLD)
local silvermatch = format('(%%d+) %s', SILVER)
local coppermatch = format('(%%d+) %s', COPPER)
function LootAlert:CHAT_MSG_MONEY(event, message)
    local moneys = match(message, solo) or match(message, grouped)
    if not moneys then
        return
    end

    local gold = match(moneys, goldmatch)
    local silver = match(moneys, silvermatch)
    local copper = match(moneys, coppermatch)
    local out = format(moneymessage, gold and format(goldpat, gold) or '',
                                        silver and format(silverpat, silver) or '',
                                        copper and format(copperpat, copper) or '')

    local ico
    if not twofour then
        ico = moneyicon
    end
    self:msg(out, ico)
    if db.chatoutput then
        chatmsg("LOOTALERT_MONEY", out, ico)
    end
end

local linkpat = '|c........(|Hitem:%%d+:.-|h)|r'
local globalpatterns = {
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
}
local patterns = {}
for _, global in ipairs(globalpatterns) do
    local pattern = _G[global]
    table.insert(patterns, (gsub(gsub(pattern, "%%d", "(%%d+)"), "%%s", linkpat)))
end
local npatterns = #patterns
function LootAlert:CHAT_MSG_LOOT(event, message)
    local item, count
    for i=1, npatterns do
        item, count = match(message, patterns[i])
        if item then
            count = count or 1
            break
        end
    end

    local itemid = item and match(item, "item:(%d+)")
    if itemid then
        local oldtotal = GetItemCount(itemid)
        local name, _, rarity, _, _, _, _, _, _, tex = GetItemInfo(itemid)
        local color = db.itemraritycolor and ITEM_QUALITY_COLORPATS[rarity] or ""

        local rest = " "

        if tonumber(count) > 1 then
            rest = " +"..count
        end
        if oldtotal > 0 then
            rest = rest .. "("..oldtotal+count..")"
        end

        self:msg(format(lootmessage, color, name, rest), tex)
        if db.chatoutput then
            local out = format(lootmessage, color, item, rest)
            chatmsg("LOOTALERT_ITEM", out, tex)
        end
    end
end
-- }}}1

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
