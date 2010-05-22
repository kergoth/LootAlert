local mod = LibStub("AceAddon-3.0"):GetAddon("LootAlert")
local inventoryitems, initialized, diff = {}, {}, {}
local match = string.match
local itempat = "(item:%d+:%d+:%d+:%d+:%d+:%d+:[-]?%d+)"

local slots = {
    HeadSlot = true,
    NeckSlot = true,
    ShoulderSlot = true,
    BackSlot = true,
    ChestSlot = true,
    ShirtSlot = true,
    TabardSlot = true,
    WristSlot = true,
    HandsSlot = true,
    WaistSlot = true,
    LegsSlot = true,
    FeetSlot = true,
    Finger0Slot = true,
    Finger1Slot = true,
    Trinket0Slot = true,
    Trinket1Slot = true,
    MainHandSlot = true,
    SecondaryHandSlot = true,
    RangedSlot = true,
    Bag0Slot = true,
    Bag1Slot = true,
    Bag2Slot = true,
    Bag3Slot = true,
}
for slotname in pairs(slots) do
    slots[slotname] = GetInventorySlotInfo(slotname)
end
function mod:ScanInventory()
    for slotname,slotid in pairs(slots) do
        local olditemstr = inventoryitems[slotid]
        local link = GetInventoryItemLink("player", slotid)
        if link then
            local itemstr = match(link, itempat)
            self.itemcounts[itemstr] = self.itemcounts[itemstr] + 1
            inventoryitems[slotid] = itemstr
        else
            inventoryitems[slotid] = nil
        end
        if olditemstr then
            self.itemcounts[olditemstr] = self.itemcounts[olditemstr] - 1
        end
    end
end

function mod:InventoryChanged(event, unit)
    if unit == "player" then
        self:ScanInventory()
    end
end


function mod:ScanAllBags(fresh)
    for bag = 0, 4 do
        self:ScanBags(bag, fresh)
    end
end

local GetContainerNumSlots, GetContainerItemLink = GetContainerNumSlots, GetContainerItemLink
local GetContainerItemInfo = GetContainerItemInfo
function mod:ScanBags(bagnum, fresh)
    if mod:ispaused() or bagnum < 0 or bagnum > 4 then
        return
    end

    for bag = 0, 4, 1 do
        for slot = 1, GetContainerNumSlots(bag), 1 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemstr = match(link, itempat)
                local _, count = GetContainerItemInfo(bag, slot)
                local current = diff[itemstr] or 0
                diff[itemstr] = current + count
            end
        end
    end

    for item, count in pairs(self.itemcounts) do
        local newcount = diff[item]
        local diffcount
        if newcount ~= count then
            diffcount = (newcount or 0) - count
        end
        diff[item] = diffcount
    end

    for item, count in pairs(diff) do
        if count > 0 and not fresh and initialized[bagnum] then
            local pendingcount = self.pending[item] - count
            self.pending[item] = pendingcount
        end

        self.itemcounts[item] = self.itemcounts[item] + count
        diff[item] = nil
    end
    initialized[bagnum] = true
end

function mod:BagUpdate(event, bagnum)
    self:ScanBags(bagnum)
end

function mod:PLW()
    -- Handle zoning, which fires a pile of BAG_UPDATEs, by making it ignore
    -- the first update for each bag again.
    for k,v in pairs(initialized) do
        initialized[k] = nil
    end
end
