-- LootAlert is a simple addon that displays what items you've looted, how
-- many, and what the total number of that item is in your inventory. It
-- colors the item name in the message by item quality, and displays looted
-- gold (colored by gold/silver/copper). It supports showing an icon for sct &
-- msbt. It can output to sct, msbt, blizzard fct, or the UIErrorsFrame.

-- Locals {{{1
local iconpath = "Interface\\AddOns\\LootAlert\\Icons"
local white = {r=1, g=1, b=1}
local match, format, gsub, sub = string.match, string.format, string.gsub, string.sub
local GetItemCount = GetItemCount
local db
-- }}}1

-- Initialization {{{1
LootAlert = LibStub("AceAddon-3.0"):NewAddon("LootAlert", "AceEvent-3.0", "AceConsole-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("LootAlert")
local acedb = LibStub("AceDB-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

local lootmessage, moneymessage = L["LOOTMESSAGE"], L["MONEYMESSAGE"]
local goldpat, silverpat, copperpat
local defaults = {
    profile = {
        enabled = true,

        itemqualitythres = 0,
        itemqualitycolor = true,

        itemicon = true,
        moneyicons = true,

        color = {
            r = 1,
            g = 1,
            b = 1,
            a = 1,
        },

        output = {
            sink20OutputSink = "Default",
        },
    },
}
local options = {
    handler = LootAlert,
    name = "LootAlert",
    type = "group",
    childGroups = "tab",
    set = function (info, v)
        db[info[#info]] = v
    end,
    get = function(info)
        return db[info[#info]]
    end,
    args = {
        enabled = {
            order = 0,
            name = L["Enabled"],
            desc = L["Enable/Disable the addon."],
            type = "toggle",
            set = function(info, v)
                db.enabled = v
                if v then
                    LootAlert:Enable()
                else
                    LootAlert:Disable()
                end
            end,
        },
        textcolor = {
            order = 10,
            name = L["Text Color"],
            type = "color",
            hasAlpha = true,
            get = function(info)
                return db.color.r, db.color.g, db.color.b, db.color.a
            end,
            set = function(info, r, g, b, a)
                db.color.r = r
                db.color.g = g
                db.color.b = b
                db.color.a = a
            end,
        },
        itemqualitythres = {
            order = 20,
            name = L["Item Quality Threshold"],
            desc = L["Hide items looted with a lower quality than this."],
            type = "select",
            values = {},
        },
        itemqualitycolor = {
            order = 30,
            name = L["Item Quality Coloring"],
            desc = L["Color the item based on its quality, like an item link."],
            type = "toggle",
        },
        itemicon = {
            order = 40,
            name = L["Show Item Icon"],
            type = "toggle",
        },
        moneyicons = {
            order = 50,
            name = L["Show Money Icons"],
            desc = L["Show icons for gold/silver/copper rather than g/s/c."],
            type = "toggle",
        },
    },
}

function LootAlert:SetupMoneyPatterns()
    if db.moneyicons then
        goldpat = "%s|T" .. iconpath.."\\UI-GoldIcon::|t"
        silverpat = "%s|T" .. iconpath.."\\UI-SilverIcon::|t"
        copperpat = "%s|T" .. iconpath.."\\UI-CopperIcon::|t"
    else
        goldpat = "%s|cffffd700g|r "
        silverpat = "%s|cffc7c7cfs|r "
        copperpat = "%s|cffeda55fc|r"
    end
end

local ITEM_QUALITY_COLORPATS = {}
for k, v in pairs(ITEM_QUALITY_COLORS) do
    ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
end
local i = 0
while true do
    local desc = _G["ITEM_QUALITY"..i.."_DESC"]
    if not desc then
        break
    end
    options.args.itemqualitythres.values[i] = desc
    i = i + 1
end

function LootAlert:OnInitialize()
    self.db = acedb:New("LootAlertConfig", defaults)
    db = self.db.profile
    self:SetEnabledState(db.enabled)
    self:SetSinkStorage(db.output)

    options.args.output = self:GetSinkAce3OptionsDataTable()
    options.args.output.order = 60
    reg:RegisterOptionsTable("LootAlert", options)
    if dialog.AddToBlizOptions then
        dialog:AddToBlizOptions("LootAlert")
    end
    self:RegisterChatCommand("lootalert", function() dialog:Open("LootAlert") end)
    self:RegisterChatCommand("la", function() dialog:Open("LootAlert") end)

	dialog:SetDefaultSize("LootAlert", 450, 400)
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

    self:Pour(out, db.color.r, db.color.g, db.color.b)
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
        local name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(itemid)
        if quality < db.itemqualitythres then
            return
        end

        local color = db.itemqualitycolor and ITEM_QUALITY_COLORPATS[quality] or ""
        local rest = " "
        if tonumber(count) > 1 then
            rest = " +"..count
        end
        if oldtotal > 0 then
            rest = rest .. "("..oldtotal+count..")"
        end

        self:Pour(format(lootmessage, color..(db.itemicon and "|T"..tex.."::|t" or "")..name, rest), db.color.r, db.color.g, db.color.b)
    end
end
-- }}}1

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
