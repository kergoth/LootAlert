local iconpath = "Interface\\AddOns\\LootAlert\\Icons"
local match, format, gsub, sub = string.match, string.format, string.gsub, string.sub
local db

-- Addon Object
local mod = LibStub("AceAddon-3.0"):NewAddon("LootAlert", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("LootAlert")
local acedb = LibStub("AceDB-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

-- State
local lootchatcount, lootprocessed = 0, 0
local itemcounts, diff, pending, initialized = {}, {}, {}, {}
local goldpat, silverpat, copperpat, moneysep

-- Options
local defaults = {
    profile = {
        enabled = true,
        chat = true,
        chatthres = false,
        newmethod = false,

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
            sink20OutputSink = "UIErrorsFrame",
        },
    },
}

local function getOptions()
    local updateExamples
    local options = {
        handler = mod,
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
                        mod:Enable()
                    else
                        mod:Disable()
                    end
                end,
            },
            newmethod = {
                order = 2,
                name = L["New method"],
                desc = L["BETA: Use new method of tracking the item counts, to fix the occasional miscount bug."],
                type = "toggle",
                arg = "newmethod",
                set = function(info, v)
                    db[info.arg] = v
                    mod:EnableNewMethod(v)
                end,
            },
            chat = {
                order = 3,
                name = L["Modify chat messages"],
                desc = L["Modify loot chat messages to use LootAlert's formatting."],
                type = "toggle",
                arg = "chat",
                set = function(info, v)
                    db[info.arg] = v
                    mod:EnableChatFilter(v)
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
                type = "group",
                inline = true,
                name = L["Item Quality Threshold"],
                args = {
                    threshold = {
                        order = 0,
                        arg = "itemqualitythres",
                        name = L["Threshold"],
                        desc = L["Hide items looted with a lower quality than this."],
                        type = "select",
                        values = {},
                    },
                    chatthres = {
                        order = 10,
                        name = L["Apply to chat messages"],
                        desc = L["Apply item quality threshold to chat messages"],
                        type = "toggle",
                        arg = "chatthres",
                        disabled = function()
                            return not db.chat
                        end,
                    },
                },
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
                            mod:SetupMoneyPatterns()
                            updateExamples()
                        end,
                    },
                },
            },
        },
    }

    local function setupExample(exnum, itemid, itemname, count, totalcount, quality, tex)
        local msg, quality = mod:GetItemMessage("|Hitem:"..itemid..":0:0:0:0:0:0:0|h", count, itemname, totalcount, quality, tex)
        if msg and quality >= db.itemqualitythres then
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
        setupExample(1, 27442, "Goldenscale Vendorfish", 2, 3, 0, "Interface\\Icons\\INV_Misc_Fish_42")
        setupExample(2, 28108, "Power Infused Mushroom", 1, 1, 3, "Interface\\Icons\\INV_Mushroom_11")
        options.args.examples.args.ex3 = {
            type = "description",
            order = 3,
            name = mod:GetMoneyMessage(5, 1, 24)
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
        options.args.itemqualitythres.args.threshold.values[i] = desc
        i = i + 1
    end

    updateExamples(true)
    return options
end

-- Initialization
local function processMoney(s)
    return false, mod:ProcessMoneyEvent(s)
end
local function processItems(s)
    local out, quality = mod:ProcessItemEvents(s)
    if db.chatthres and quality < db.itemqualitythres then
        return true
    else
        return false, out
    end
end
function mod:EnableChatFilter(val)
    local func = val and ChatFrame_AddMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    func("CHAT_MSG_MONEY", processMoney)
    func("CHAT_MSG_LOOT", processItems)
end

function mod:SetupMoneyPatterns()
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

function mod:OnInitialize()
    self.db = acedb:New("LootAlertConfig", defaults, "Default")
    db = self.db.profile
    self:SetEnabledState(db.enabled)
    self:SetSinkStorage(db.output)
    self:SetupMoneyPatterns()
    self:EnableChatFilter(db.chat)

    reg:RegisterOptionsTable("LootAlert", getOptions)
    reg:RegisterOptionsTable("LootAlert Output", function()
        local opts = self:GetSinkAce3OptionsDataTable()
        opts.args.ChatFrame = nil
        return opts
    end)
    if dialog.AddToBlizOptions then
        dialog:AddToBlizOptions("LootAlert")
        dialog:AddToBlizOptions("LootAlert Output", L["Output"], "LootAlert")
    end
    LibStub("tekKonfig-AboutPanel").new("LootAlert", "LootAlert") -- About subcategory for bliz options

    self:RegisterChatCommand("lootalert", function() InterfaceOptionsFrame_OpenToFrame(dialog.BlizOptions["LootAlert"].frame) end)
    self:RegisterChatCommand("la", function() InterfaceOptionsFrame_OpenToFrame(dialog.BlizOptions["LootAlert"].frame) end)
end

mod.debugframe = DEFAULT_CHAT_FRAME
function mod:Debug(...)
    self.debugframe:AddMessage(strjoin(" ", ...))
end

function mod:OnEnable()
    self:RegisterEvent("CHAT_MSG_LOOT", "Loot")
    self:RegisterEvent("CHAT_MSG_MONEY", "Money")

    self:EnableNewMethod(db.newmethod, true)

    if tekDebug then
        self.debugframe = tekDebug:GetFrame("LootAlert")
    end
end

-- Pause/Unpause, to ensure that situations where we can gain items in the
-- inventory from something other than a loot are handled (bank)
local paused = 0
local function ispaused()
    return paused > 0
end
local function pause()
    paused = paused + 1
end
local function unpause()
    paused = paused - 1
    if paused == 0 then
        mod:ScanAllBags(true)
    end
end
function mod:EnableNewMethod(state, first)
    if state then
        self:RegisterEvent("BANKFRAME_SHOW", pause)
        self:RegisterEvent("BANKFRAME_CLOSED", unpause)

        self:RegisterEvent("UNIT_INVENTORY_CHANGED", "InventoryChanged")
        self:RegisterEvent("PLAYER_LEAVING_WORLD", "PLW")
        self:RegisterEvent("BAG_UPDATE", "BagUpdate")

        if first then
            self:ScanBags(0)
        else
            self:ScanAllBags(true)
        end
        self:InventoryChanged(nil, "player")

        self:Hook("ChatFrame_AddMessageGroup", true)
        self:Hook("ChatFrame_RemoveMessageGroup", true)
        self:SecureHook("SetChatWindowShown", "UpdateLootChatCount")
        self:UpdateLootChatCount()
    elseif not first then
        self:UnregisterEvent("BANKFRAME_SHOW")
        self:UnregisterEvent("BANKFRAME_CLOSED")
        self:UnregisterEvent("MERCHANT_SHOW")
        self:UnregisterEvent("MERCHANT_CLOSED")
        self:UnregisterEvent("TRADE_SHOW")
        self:UnregisterEvent("TRADE_CLOSED")

        self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        self:UnregisterEvent("PLAYER_LEAVING_WORLD")
        self:UnregisterEvent("BAG_UPDATE")

        self:Unhook("ChatFrame_AddMessageGroup")
        self:Unhook("ChatFrame_RemoveMessageGroup")
        self:Unhook("SetChatWindowShown")
    end
end

-- Keep track of how many chat frames are showing loot info
function mod:UpdateLootChatCount()
    lootchatcount = 0
    for i=1,FCF_GetNumActiveChatFrames() do
        local f = _G["ChatFrame"..i]
        local found
        for k,v in pairs(f.messageTypeList) do
            if strupper(v) == "LOOT" then
                found = true
            end
        end
        if found then
            lootchatcount = lootchatcount + 1
        end
    end
    lootprocessed = 0
end

function mod:ChatFrame_AddMessageGroup(frame, group)
    if group == "LOOT" then
        local wasregistered
        for k,v in pairs(frame.messageTypeList) do
            if strupper(v) == group then
                wasregistered = true
            end
        end
        if not wasregistered then
            lootchatcount = lootchatcount + 1
            lootprocessed = 0
        end
    end
    self.hooks.ChatFrame_AddMessageGroup(frame, group)
end

function mod:ChatFrame_RemoveMessageGroup(frame, group)
    if group == "LOOT" then
        local wasregistered
        for k,v in pairs(frame.messageTypeList) do
            if strupper(v) == group then
                wasregistered = true
            end
        end
        if wasregistered then
            lootchatcount = lootchatcount - 1
            lootprocessed = 0
        end
    end
    self.hooks.ChatFrame_RemoveMessageGroup(frame, group)
end

-- Track equipped stuff
local slots = {
    ["HeadSlot"] = true,
    ["NeckSlot"] = true,
    ["ShoulderSlot"] = true,
    ["BackSlot"] = true,
    ["ChestSlot"] = true,
    ["ShirtSlot"] = true,
    ["TabardSlot"] = true,
    ["WristSlot"] = true,
    ["HandsSlot"] = true,
    ["WaistSlot"] = true,
    ["LegsSlot"] = true,
    ["FeetSlot"] = true,
    ["Finger0Slot"] = true,
    ["Finger1Slot"] = true,
    ["Trinket0Slot"] = true,
    ["Trinket1Slot"] = true,
    ["MainHandSlot"] = true,
    ["SecondaryHandSlot"] = true,
    ["RangedSlot"] = true,
    ["Bag0Slot"] = true,
    ["Bag1Slot"] = true,
    ["Bag2Slot"] = true,
    ["Bag3Slot"] = true,
}
for slotname in pairs(slots) do
    slots[slotname] = GetInventorySlotInfo(slotname)
end
local inventoryitems = {}
function mod:ScanInventory()
    for slotname,slotid in pairs(slots) do
        local olditemstr = inventoryitems[slotid]
        local link = GetInventoryItemLink("player", slotid)
        if link then
            local itemstr = match(link, "(item:%d+:%d+:%d+:%d+:%d+:%d+)")
            itemcounts[itemstr] = (itemcounts[itemstr] or 0) + 1
            inventoryitems[slotid] = itemstr
        else
            inventoryitems[slotid] = nil
        end
        if olditemstr then
            itemcounts[olditemstr] = (itemcounts[olditemstr] or 0) - 1
        end
    end
end

-- Bag Scanning
function mod:ScanAllBags(fresh)
	for bag = 0, 4 do
        self:ScanBags(bag, fresh)
    end
end

local GetContainerNumSlots, GetContainerItemLink = GetContainerNumSlots, GetContainerItemLink
local GetContainerItemInfo = GetContainerItemInfo
function mod:ScanBags(bagnum, fresh)
    if ispaused() or bagnum < 0 or bagnum > 4 then
        return
    end

	for bag = 0, 4, 1 do
		for slot = 1, GetContainerNumSlots(bag), 1 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemstr = match(link, "(item:%d+:%d+:%d+:%d+:%d+:%d+)")
                local _, count = GetContainerItemInfo(bag, slot)
                local current = diff[itemstr] or 0
                diff[itemstr] = current + count
            end
        end
    end

    for item, count in pairs(itemcounts) do
        local newcount = diff[item]
        local diffcount
        if newcount ~= count then
            diffcount = (newcount or 0) - count
        end
        diff[item] = diffcount
    end

    for item, count in pairs(diff) do
        if count > 0 and not fresh and initialized[bagnum] then
            local pendingcount = (pending[item] or 0) - count
            pending[item] = pendingcount
        end

        itemcounts[item] = (itemcounts[item] or 0) + count
        diff[item] = nil
    end
    initialized[bagnum] = true
end

-- Message Formatting
function mod:GetMoneyMessage(gold, silver, copper)
    local moneystr = strjoin(moneysep, (gold and format(goldpat, gold) or ""),
    (silver and format(silverpat, silver) or ""),
    (copper and format(copperpat, copper) or ""))
    return format("|cff%02x%02x%02x%s|r%s|r", db.color.r, db.color.g, db.color.b, db.prefix, moneystr)
end
local solo = gsub(YOU_LOOT_MONEY, "%%s", "(.*)")
local grouped = gsub(LOOT_MONEY_SPLIT, "%%s", "(.*)")
local goldmatch = format("(%%d+) %s", GOLD)
local silvermatch = format("(%%d+) %s", SILVER)
local coppermatch = format("(%%d+) %s", COPPER)
function mod:ProcessMoneyEvent(message)
    local moneys = match(message, solo) or match(message, grouped)
    if not moneys then
        return
    end

    local gold = match(moneys, goldmatch)
    local silver = match(moneys, silvermatch)
    local copper = match(moneys, coppermatch)
    return self:GetMoneyMessage(gold, silver, copper)
end

local ITEM_QUALITY_COLORPATS = {}
for k, v in pairs(ITEM_QUALITY_COLORS) do
    ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
end
function mod:GetItemMessage(itemlink, count, name, totalcount, quality, tex)
    local itemstr = match(itemlink, "(item:%d+:%d+:%d+:%d+:%d+:%d+)")
    if itemstr then
        if not name then
            local _
            name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(itemlink)

            if db.newmethod then
                local pendingcount = pending[itemstr] or 0
                if lootprocessed >= (lootchatcount + 1) then
                    lootprocessed = 0
                end
                if lootprocessed == 0 then
                    pendingcount = pendingcount + count
                    pending[itemstr] = pendingcount
                end
                lootprocessed = lootprocessed + 1
                totalcount = (itemcounts[itemstr] or 0) + pendingcount

                -- For debugging the problems people are seeing with new
                -- method.
                -- if lootprocessed == 1 then
                --     local diff = math.abs(totalcount - (GetItemCount(itemstr) + count))
                --     if diff > 0.2 then
                --         self:Print("Warning: Difference between new method and old method: "..diff)
                --     end
                -- end
            else
                totalcount = GetItemCount(itemstr) + count
            end
        end

        local color = db.itemqualitycolor and ITEM_QUALITY_COLORPATS[quality] or ""
        local countstr = ""
        local totalstr = ""
        if count > 1 then
            countstr = " +"..count
        end
        if totalcount > count then
            totalstr = " ("..totalcount..")"
        end

        local r, g, b = db.color.r, db.color.g, db.color.b
        return format("|cff%02x%02x%02x%s%s|r|cff%02x%02x%02x%s%s|r", r, g, b, db.prefix, color..(db.itemicon and "|T"..tex.."::|t" or "").."|H"..itemstr.."|h"..name.."|h", r, g, b, countstr, totalstr), quality
    end
end

-- Item Loot Patterns
local linkpat = "|c........(|Hitem:%%d+:.-|h)|r"
local patterns = {}
local itemglobals = {
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
}
for _, global in ipairs(itemglobals) do
    local pattern = _G[global]
    table.insert(patterns, (gsub(gsub(pattern, "%%d", "(%%d+)"), "%%s", linkpat)))
end
local npatterns = #patterns
function mod:ProcessItemEvents(message)
    local item, count
    for i=1, npatterns do
        item, count = match(message, patterns[i])
        if item then
            count = tonumber(count) or 1
            break
        end
    end

    if item then
        return self:GetItemMessage(item, count)
    end
end

-- Event Handlers
function mod:PLW()
    -- Handle zoning, which fires a pile of BAG_UPDATEs, by making it ignore
    -- the first update for each bag again.
    for k,v in pairs(initialized) do
        initialized[k] = nil
    end
end

function mod:InventoryChanged(event, unit)
    if unit == "player" then
        self:ScanInventory()
    end
end

function mod:BagUpdate(event, bagnum)
    self:ScanBags(bagnum)
end

function mod:Loot(event, message)
    local out, quality = self:ProcessItemEvents(message)
    if out and quality >= db.itemqualitythres then
        self:Pour(out)
    end
end

function mod:Money(event, message)
    self:Pour(self:ProcessMoneyEvent(message))
end

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
