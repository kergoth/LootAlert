-- Simple addon that displays information about what was looted in Mik's
-- Scrolling Battle Text.  It keeps total counts of all the items in your
-- inventory so as to show that as well as the amount just looted.

local sebags = SpecialEventsEmbed:GetInstance("Bags 1")

local itemidpat = "(%d+):%d+:%d+:%d+"
local function getitemid(itemlink)
    local _, _, itemid = string.find(itemlink or "", itemidpat)
    return itemid
end

MSBTLoot = {}

function MSBTLoot:ADDON_LOADED(arg1)
    self.counts = {}
    self.loots = {}
    sebags:RegisterEvent(self, "SPECIAL_BAGSLOT_UPDATE")
    this:RegisterEvent("CHAT_MSG_LOOT")
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, sebags:GetNumSlots(bag) do
            local item = GetContainerItemLink(bag, slot)
            if item then
                local _, count = GetContainerItemInfo(bag, slot)
                item = getitemid(item)
                self.counts[item] = (self.counts[item] or 0) + count
            end
        end
    end
end

function MSBTLoot:CHAT_MSG_LOOT(arg1)
    local _, _, item, count = string.find(arg1, itemidpat .. ".-x(%d+)\.")
    if not item then
        local _, _, item2 = string.find(arg1, itemidpat .. "\.")
        item = item2
        count = 1
    end

    if item then
        if not self.loots[item] then
            self.loots[item] = 0
        end
        self.loots[item] = self.loots[item] + tonumber(count)
    end
end

function MSBTLoot:SPECIAL_BAGSLOT_UPDATE(bag, slot, itemlink, stack, oldlink, oldstack)
    local itemid = getitemid(itemlink)
    local oldid = getitemid(oldlink)

    if stack then
        self.counts[itemid] = (self.counts[itemid] or 0) + stack
    end
    if oldstack then
        self.counts[oldid] = (self.counts[oldid] or 0) - oldstack
    end


    local count = self.loots[itemid]
    if count then
        local name = GetItemInfo(itemid)
        local message = "[Loot " .. name .. " +" .. count .. "(" .. self.counts[itemid] .. ")]"
        MikSBT.DisplayMessage(message, MikSBT.DISPLAYTYPE_NOTIFICATION, false, 255, 255, 255)
        self.loots[itemid] = nil
    end
end

-- Initialization
MSBTLoot.frame = CreateFrame("Frame", nil, UIParent)
MSBTLoot.frame:SetScript("OnEvent", function() MSBTLoot[event](MSBTLoot, arg1) end)
MSBTLoot.frame:RegisterEvent("ADDON_LOADED")
