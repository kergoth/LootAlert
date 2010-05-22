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
local lootframes = {}
local goldpat, silverpat, copperpat, moneysep
mod.itemcounts = {}
mod.pending = {}

local defaults = {
    profile = {
        enabled = true,
        chat = true,
        chatthres = false,
        newmethod = true,

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

-- Initialization
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

-- Pause/Unpause, to ensure that situations where we can gain items in the
-- inventory from something other than a loot are handled (bank)
local paused = 0
local function pause()
    paused = paused + 1
end
local function unpause()
    paused = paused - 1
    if paused == 0 then
        mod:ScanAllBags(true)
    end
end
function mod:ispaused()
    return paused > 0
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

        for i=1,FCF_GetNumActiveChatFrames() do
            local f = _G["ChatFrame"..i]
            local found
            for k,v in pairs(f.messageTypeList) do
                if strupper(v) == "LOOT" then
                    found = true
                end
            end
            lootframes[f] = found
        end
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
    end
end

function mod:OnInitialize()
    self.db = acedb:New("LootAlertConfig", defaults, "Default")
    db = self.db.profile
    self:SetEnabledState(db.enabled)
    self:SetSinkStorage(db.output)
    self:SetupMoneyPatterns()
    self:EnableChatFilter(db.chat)

    reg:RegisterOptionsTable("LootAlert", mod.getOptions)
    reg:RegisterOptionsTable("LootAlert Output", function()
        local opts = self:GetSinkAce3OptionsDataTable()
        opts.args.ChatFrame = nil
        return opts
    end)
    dialog:AddToBlizOptions("LootAlert")
    dialog:AddToBlizOptions("LootAlert Output", L["Output"], "LootAlert")
    LibStub("tekKonfig-AboutPanel").new("LootAlert", "LootAlert")

    self:RegisterChatCommand("lootalert", function() InterfaceOptionsFrame_OpenToCategory("LootAlert") end)
    self:RegisterChatCommand("la", function() InterfaceOptionsFrame_OpenToCategory("LootAlert") end)

    mod.getOptions = nil
end

function mod:OnEnable()
    self:RegisterEvent("CHAT_MSG_LOOT", "Loot")
    self:RegisterEvent("CHAT_MSG_MONEY", "Money")

    self:EnableNewMethod(db.newmethod, true)
end


-- Chat
local function processMoney(frame, event, message, ...)
    return false, mod:ProcessMoneyEvent(message), ...
end
local function processItems(frame, event, message, ...)
    -- Filter out chat loot messages that we'll be handling ourselves
    local item, count = mod:ParseChatMessage(message)

    if item then
        return true
    end
    return false, message, ...
end
function mod:EnableChatFilter(val)
    local func = val and ChatFrame_AddMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    func("CHAT_MSG_MONEY", processMoney)
    func("CHAT_MSG_LOOT", processItems)
end

function mod:ChatFrame_AddMessageGroup(frame, group)
    if group == "LOOT" then
        lootframes[frame] = true
    end
    return self.hooks.ChatFrame_AddMessageGroup(frame, group)
end

function mod:ChatFrame_RemoveMessageGroup(frame, group)
    if group == "LOOT" then
        lootframes[frame] = nil
    end
    return self.hooks.ChatFrame_RemoveMessageGroup(frame, group)
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
local goldmatch = gsub(GOLD_AMOUNT, "%%d", "(%%d+)")
local silvermatch = gsub(SILVER_AMOUNT, "%%d", "(%%d+)")
local coppermatch = gsub(COPPER_AMOUNT, "%%d", "(%%d+)")
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

local band = bit.band
function mod:GetItemStr(itemlink)
    local itempat = "(item:%d+:%d+:%d+:%d+:%d+:%d+:([-]?%d+)):([-]?%d+)"
    local itemstr, suffixid, uniqueid = match(itemlink, itempat)
    if (tonumber(suffixid) or 0) < 0 then
        -- scaled random suffixes, see http://www.wowwiki.com/ItemString
        uniqueid = band(tonumber(uniqueid) or 0, 65535)
    else
        uniqueid = 0
    end
    return itemstr..":"..uniqueid
end

local ITEM_QUALITY_COLORPATS = {}
for k, v in pairs(ITEM_QUALITY_COLORS) do
    ITEM_QUALITY_COLORPATS[k] = format("|cff%02x%02x%02x", 255 * v.r, 255 * v.g, 255 * v.b)
end
function mod:GetItemMessage(itemlink, count, name, totalcount, quality, tex)
    local itemstr = self:GetItemStr(itemlink)
    if itemstr then
        if not name then
            local _
            name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(itemlink)

            if db.newmethod then
                local pendingcount = self.pending[itemstr] or 0
                pendingcount = pendingcount + count
                self.pending[itemstr] = pendingcount
                totalcount = (self.itemcounts[itemstr] or 0) + pendingcount
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
function mod:ParseChatMessage(message)
    local item, count
    for i=1, npatterns do
        item, count = match(message, patterns[i])
        if item then
            count = tonumber(count) or 1
            break
        end
    end
    return item, count
end
function mod:ProcessItemEvents(message)
    local item, count = mod:ParseChatMessage(message)

    if item then
        return self:GetItemMessage(item, count)
    end
end


-- Event Handlers
function mod:Loot(event, message)
    local out, quality = self:ProcessItemEvents(message)
    if out then
        if quality >= db.itemqualitythres then
            self:Pour(out)
        end
        if db.chat then
            local qualitythres = not db.chatthres or quality >= db.itemqualitythres
            if qualitythres then
                for frame in pairs(lootframes) do
                    frame:AddMessage(out)
                end
            end
        end
    end
end

function mod:Money(event, message)
    self:Pour(self:ProcessMoneyEvent(message))
end

--  vim: set fenc=utf-8 sts=4 sw=4 et fdm=marker:
