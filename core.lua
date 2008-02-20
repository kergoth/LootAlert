-- LootAlert is a simple addon that displays what items you've looted, how
-- many, and what the total number of that item is in your inventory. It
-- colors the item name in the message by item rarity, and displays looted
-- gold (colored by gold/silver/copper). It supports showing an icon for sct &
-- msbt. It can output to sct, msbt, blizzard fct, or the UIErrorsFrame.

-- Locals {{{1
local moneyicon = "Interface\\Icons\\INV_Ore_Gold_01"
local white = {r=1, g=1, b=1}
local match, format, gsub, sub = string.match, string.format, string.gsub, string.sub
local GetItemCount = GetItemCount
local config, cfg, msg
local lootmessage, moneymessage, moneyformat

local vercheck, twofour
do
    local version = GetBuildInfo()
    local vmaj, vmin, vrev = strsplit(".", version)
    vmaj, vmin, vrev = tonumber(vmaj), tonumber(vmin), tonumber(vrev)

    function vercheck(maj, min, rev)
        if not maj or maj >= vmaj then
            if not min or min >= vmin then
                if not rev or rev >= vrev then
                    return true
                end
            end
        end
        return false
    end
    twofour = vercheck(2, 4)
end
-- }}}1

-- Localization {{{1
if GetLocale() == 'zhTW' then
    lootmessage = '拾取: %s%s|r%s'
    moneymessage = '拾取: +%s%s%s'
    LOOTREFORMATTED = "Loot [Reformatted]"
else
    lootmessage = 'Loot: %s%s|r%s'
    moneymessage = 'Loot: +%s%s%s'
    LOOTREFORMATTED = "Loot [Reformatted]"
end

CHAT_MSG_LOOTALERT_ITEM = CHAT_MSG_LOOT
CHAT_MSG_LOOTALERT_MONEY = CHAT_MSG_MONEY
-- }}}1

-- Chat {{{1
-- These bits courtesy wowwiki, with modification
local function FireChatEvent(evt, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    local bIsChat = sub(evt, 1, 9) == "CHAT_MSG_"
    local chattype = sub(evt, 10)

    for i=1, NUM_CHAT_WINDOWS do
        if not bIsChat or config.chatsettings[i] then
            this = _G["ChatFrame"..i]
            event = evt
            arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = a1,a2,a3,a4,a5,a6,a7,a8,a9
            ChatFrame_OnEvent(evt)
        end
    end
end

local function chatmsg(chattype, txt)
  assert(config.chatsettings[chattype])
  FireChatEvent("CHAT_MSG_"..chattype, txt, "", "", "", "", "", "", "", "")
end
-- }}}1

-- Initialization {{{1
local LootAlert = CreateFrame('Frame', nil, UIParent)
LootAlert:SetScript('OnEvent', function(self, event, ...)
    self[event](self, ...)
end)
LootAlert:RegisterEvent('PLAYER_LOGIN')

local ITEM_QUALITY_COLORPATS = {}
local goldpat, silverpat, copperpat

function LootAlert:SetupHooks()
    local ORIG_GetChatWindowMessages = GetChatWindowMessages
    function GetChatWindowMessages(n)
        local ret = config.chatsettings[n]
        if config.chatsettings[n] then
            ret = "LOOTREFORMATTED"
        end
        return ORIG_GetChatWindowMessages(n), ret
    end

    local ORIG_AddChatWindowMessages = AddChatWindowMessages
    function AddChatWindowMessages(n, chattype)
        if chattype == "LOOTREFORMATTED" then
            config.chatsettings[n] = true
            local this = _G["ChatFrame"..n]
            table.insert(this.messageTypeList, "LOOTREFORMATTED")
        else
            ORIG_AddChatWindowMessages(n, chattype)
        end
    end

    local ORIG_RemoveChatWindowMessages = RemoveChatWindowMessages
    function RemoveChatWindowMessages(n, chattype)
        if chattype == "LOOTREFORMATTED" then
            config.chatsettings[n] = false
            local this = _G["ChatFrame"..n]
            for index, group in pairs(this.messageTypeList) do
                if group == "LOOTREFORMATTED" then
                    this.messageTypeList[index] = nil
                end
            end
        else
            ORIG_RemoveChatWindowMessages(n,chattype)
        end
    end

    local ORIG_ChangeChatColor = ChangeChatColor
    function ChangeChatColor(chattype, r,g,b)
      if config.chatsettings[chattype] then
        config.chatsettings[chattype].r = r
        config.chatsettings[chattype].g = g
        config.chatsettings[chattype].b = b
        FireChatEvent("UPDATE_CHAT_COLOR", chattype, r, g, b)
      else
        ORIG_ChangeChatColor(chattype,r,g,b)
      end
    end
end

function LootAlert:PLAYER_LOGIN()
    if not LootAlertConfig then
        LootAlertConfig = {
            itemraritycolor = true,
            moneycolor = true,
            chatoutput = true,
            chatsettings = {
--                 [1] = true,
                LOOTALERT_ITEM = {
                    r = 0,
                    g = 2/3,
                    b = 0,
                },
                LOOTALERT_MONEY = {
                    r = 1,
                    g = 1,
                    b = 0,
                },
            },

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
    end
    config = LootAlertConfig

    goldpat = config.moneycolor and '|cffffd700%sg|r ' or '%sg '
    silverpat = config.moneycolor and '|cffc7c7cf%ss|r ' or '%ss '
    copperpat = config.moneycolor and '|cffeda55f%sc|r' or '%sc'

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
        function msg(message, tex)
            DisplayEvent(msbteventsettings, message, cfg.icon and tex)
        end
    elseif SCT and SCT.DisplayText then
        cfg = config.sct
        function msg(message, tex)
            SCT:DisplayText(message, cfg.color, cfg.sticky, "event", cfg.scrollarea, nil, nil, cfg.icon and tex)
        end
    elseif CombatText_AddMessage then
        cfg = config.fct
        function msg(message)
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, cfg.color.r, cfg.color.g, cfg.color.b, cfg.sticky and "crit")
        end
    else
        cfg = config.uierrorsframe
        function msg(message)
            UIErrorsFrame:AddMessage(message, cfg.color.r, cfg.color.g, cfg.color.b)
        end
    end

    self:RegisterEvent('CHAT_MSG_LOOT')
    self:RegisterEvent('CHAT_MSG_MONEY')

    for k, v in pairs(ITEM_QUALITY_COLORS) do
        ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
    end

    ChatTypeGroup.LOOTREFORMATTED = {
        "CHAT_MSG_LOOTALERT_ITEM",
        "CHAT_MSG_LOOTALERT_MONEY",
    }
    table.insert(OtherMenuChatTypeGroups, "LOOTREFORMATTED")

    for chattype, info in pairs(config.chatsettings) do
        if type(info) == "table" then
            ChatTypeInfo[chattype] = info
            _G["CHAT_"..chattype.."_GET"] = ""
            FireChatEvent("UPDATE_CHAT_COLOR", chattype, info.r, info.g, info.b)
        end
    end

    for i=1, NUM_CHAT_WINDOWS do
        local f = _G["ChatFrame"..i]
        if config.chatsettings[i] then
            table.insert(f.messageTypeList, "LOOTREFORMATTED")
        end
    end

    self:SetupHooks()
end
-- }}}1

-- Loot Event Handling {{{1 {{{1
local solo = gsub(YOU_LOOT_MONEY, '%%s', '(.*)')
local grouped = gsub(LOOT_MONEY_SPLIT, '%%s', '(.*)')
local goldmatch = format('(%%d+) %s', GOLD)
local silvermatch = format('(%%d+) %s', SILVER)
local coppermatch = format('(%%d+) %s', COPPER)
local moneyiconlink = "|T"..moneyicon..":32|t"
function LootAlert:CHAT_MSG_MONEY(message)
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

    msg(out, moneyicon)
    if config.chatoutput then
        if twofour then
            out = moneyiconlink .. out
        end
        chatmsg("LOOTALERT_MONEY", out)
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
function LootAlert:CHAT_MSG_LOOT(message)
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
        local color = config.itemraritycolor and ITEM_QUALITY_COLORPATS[rarity] or ""

        local rest = " "
        if tonumber(count) > 1 then
            rest = " +"..count
        end
        if oldtotal > 0 then
            rest = rest .. "("..oldtotal+count..")"
        end

        msg(format(lootmessage, color, name, rest), tex)
        if config.chatoutput then
            local out = format(lootmessage, color, item, rest)
            if twofour then
                out = "|T"..tex..":32|t"..out
            end
            chatmsg("LOOTALERT_ITEM", out)
        end
    end
end
-- }}}1

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
