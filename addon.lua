-- LootAlert is a simple addon that displays what items you've looted, how
-- many, and what the total number of that item is in your inventory. It
-- colors the item name in the message by item quality, and displays looted
-- gold (colored by gold/silver/copper). It supports showing an icon for sct &
-- msbt. It can output to sct, msbt, blizzard fct, or the UIErrorsFrame.

-- Locals {{{1
local iconpath = "Interface\\AddOns\\LootAlert\\Icons"
local match, format, gsub, sub = string.match, string.format, string.gsub, string.sub
local db
-- }}}1

-- Initialization {{{1
LootAlert = LibStub("AceAddon-3.0"):NewAddon("LootAlert", "AceEvent-3.0", "AceConsole-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("LootAlert")
local acedb = LibStub("AceDB-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

local goldpat, silverpat, copperpat, moneysep
local defaults = {
    profile = {
        enabled = true,

        color = {
            r = 255,
            g = 255,
            b = 255,
        },
        itemqualitythres = 0,

        itemqualitycolor = true,
        itemicon = true,
        moneyformat = 3,
        prefix = L["Loot: "],

        output = {
            sink20OutputSink = "Default",
        },
    },
}

local function getOptions()
    local updateExamples
    local options = {
        handler = LootAlert,
        name = "LootAlert",
        type = "group",
        get = function(info)
            return db[info.arg]
        end,
        set = function(info, v)
            db[info.arg] = v
            updateExamples()
        end,
        args = {
            enabled = {
                order = 0,
                name = L["Enabled"],
                desc = L["Enable/Disable the addon."],
                type = "toggle",
                get = function()
                    return db.enabled
                end,
                set = function(info, v)
                    db.enabled = v
                    if v then
                        LootAlert:Enable()
                    else
                        LootAlert:Disable()
                    end
                end,
            },
            examples = {
                order = 5,
                type = "group",
                inline = true,
                name = L["Example Messages"],
                args = {
                },
            },
            itemqualitythres = {
                order = 20,
                arg = "itemqualitythres",
                name = L["Item Quality Threshold"],
                desc = L["Hide items looted with a lower quality than this."],
                type = "select",
                values = {},
            },
            format = {
                order = 30,
                type = "group",
                inline = true,
                name = L["Formatting Options"],
                args = {
                    lootprefix = {
                        name = L["Prefix Text"],
                        type = "input",
                        arg = "prefix",
                    },
                    textcolor = {
                        order = 10,
                        name = L["Text Color"],
                        type = "color",
                        get = function(info)
                            return db.color.r / 255, db.color.g / 255, db.color.b / 255
                        end,
                        set = function(info, r, g, b)
                            db.color.r = r * 255
                            db.color.g = g * 255
                            db.color.b = b * 255
                            updateExamples()
                        end,
                    },
                    itemqualitycolor = {
                        name = L["Item Quality Coloring"],
                        desc = L["Color the item based on its quality, like an item link."],
                        type = "toggle",
                        arg = "itemqualitycolor",
                    },
                    itemicon = {
                        name = L["Item Icon"],
                        type = "toggle",
                        arg = "itemicon",
                    },
                    moneyformat = {
                        name = L["Money Format"],
                        type = "select",
                        arg = "moneyformat",
                        values = {
                            L["Condensed"],
                            L["Text"],
                            L["Full"],
                        },
                        set = function(info, v)
                            db.moneyformat = v
                            LootAlert:SetupMoneyPatterns()
                            updateExamples()
                        end,
                    },
                },
            },
        },
    }

    local function setupExample(exnum, itemid, itemname, count, oldtotal, quality, tex)
        local msg = LootAlert:GetItemMessage("|Hitem:"..itemid..":0:0:0:0:0:0:0|h", count, itemname, oldtotal, quality, tex)
        if msg then
            options.args.examples.args["ex"..exnum] = {
                type = "description",
                name = msg,
                order = exnum,
            }
        else
            options.args.examples.args["ex"..exnum] = nil
        end
    end

    function updateExamples(dontnotify)
        setupExample(1, 27442, "Goldenscale Vendorfish", 2, 1, 0, "Interface\\Icons\\INV_Misc_Fish_42")
        setupExample(2, 28108, "Power Infused Mushroom", 1, 0, 3, "Interface\\Icons\\INV_Mushroom_11")
        options.args.examples.args.ex3 = {
            type = "description",
            order = 3,
            name = LootAlert:GetMoneyMessage(5, 1, 24)
        }
        if not dontnotify then
            reg:NotifyChange("LootAlert")
        end
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

    updateExamples(true)
    return options
end

function LootAlert:SetupMoneyPatterns()
    if db.moneyformat == 3 then
        goldpat = "%s|T"..iconpath.."\\UI-GoldIcon::|t"
        silverpat = "%s|T"..iconpath.."\\UI-SilverIcon::|t"
        copperpat = "%s|T"..iconpath.."\\UI-CopperIcon::|t"
        moneysep = ""
    elseif db.moneyformat == 2 then
        goldpat = "%s|cffffd700g|r"
        silverpat = "%s|cffc7c7cfs|r"
        copperpat = "%s|cffeda55fc|r"
        moneysep = " "
    elseif db.moneyformat == 1 then
        goldpat = "|cffffd700%s|r"
        silverpat = "|cffc7c7cf%s|r"
        copperpat = "|cffeda55f%s|r"
        moneysep = "."
    end
end

function LootAlert:OnInitialize()
    self.db = acedb:New("LootAlertConfig", defaults, "Default")
    db = self.db.profile
    self:SetEnabledState(db.enabled)
    self:SetSinkStorage(db.output)
    self:SetupMoneyPatterns()

    reg:RegisterOptionsTable("LootAlert", getOptions)
    reg:RegisterOptionsTable("LootAlert Output", function() return self:GetSinkAce3OptionsDataTable() end)
    if dialog.AddToBlizOptions then
        dialog:AddToBlizOptions("LootAlert")
        dialog:AddToBlizOptions("LootAlert Output", L["Output"], "LootAlert")
    end
    LibStub("tekKonfig-AboutPanel").new("LootAlert", "LootAlert") -- About subcategory for bliz options

    self:RegisterChatCommand("lootalert", function() InterfaceOptionsFrame_OpenToFrame(dialog.BlizOptions["LootAlert"].frame) end)
    self:RegisterChatCommand("la", function() InterfaceOptionsFrame_OpenToFrame(dialog.BlizOptions["LootAlert"].frame) end)
end

function LootAlert:OnEnable()
    self:RegisterEvent('CHAT_MSG_LOOT')
    self:RegisterEvent('CHAT_MSG_MONEY')
end
-- }}}1

-- Message Formatting {{{1
function LootAlert:GetMoneyMessage(gold, silver, copper)
    local moneystr = strjoin(moneysep, (gold and format(goldpat, gold) or ''),
                                       (silver and format(silverpat, silver) or ''),
                                       (copper and format(copperpat, copper) or ''))
    return format("|cff%02x%02x%02x%s|r%s|r", db.color.r, db.color.g, db.color.b, db.prefix, moneystr)
end

local ITEM_QUALITY_COLORPATS = {}
for k, v in pairs(ITEM_QUALITY_COLORS) do
    ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
end
function LootAlert:GetItemMessage(itemlink, count, name, total, quality, tex)
    local itemid = itemlink and match(itemlink, "item:(%d+)")
    if itemid then
        local oldtotal = total or GetItemCount(itemid)
        if not name then
            local _
            name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(itemid)
        end
        if quality < db.itemqualitythres then
            return
        end

        local color = db.itemqualitycolor and ITEM_QUALITY_COLORPATS[quality] or ""
        local countstr = ""
        local totalstr = ""
        if tonumber(count) > 1 then
            countstr = " +"..count
        end
        if oldtotal > 0 then
            totalstr = " ("..oldtotal+count..")"
        end

        local r, g, b = db.color.r, db.color.g, db.color.b
        return format("|cff%02x%02x%02x%s%s|r|cff%02x%02x%02x%s%s|r", r, g, b, db.prefix, color..(db.itemicon and "|T"..tex.."::|t" or "")..name, r, g, b, countstr, totalstr)
    end
end
-- }}}1

-- Event Handlers {{{1
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
    self:Pour(self:GetMoneyMessage(gold, silver, copper))
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
local GetItemCount, GetItemInfo = GetItemCount, GetItemInfo
function LootAlert:CHAT_MSG_LOOT(event, message)
    local item, count
    for i=1, npatterns do
        item, count = match(message, patterns[i])
        if item then
            count = count or 1
            break
        end
    end

    if item then
        self:Pour(self:GetItemMessage(item, count))
    end
end
-- }}}1

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
