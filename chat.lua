local mod = LibStub("AceAddon-3.0"):GetAddon("LootAlert")

local function processMoney(s)
    return false, mod:ProcessMoneyEvent(s)
end
local function processItems(s)
    -- Filter out chat loot messages that we'll be handling ourselves
    local item, count = mod:ParseChatMessage(s)

    if item then
        return true
    end
    return false, s
end
function mod:EnableChatFilter(val)
    local func = val and ChatFrame_AddMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    func("CHAT_MSG_MONEY", processMoney)
    func("CHAT_MSG_LOOT", processItems)
end

mod.lootframes = {}
function mod:ScanChatFrames()
    for i=1,FCF_GetNumActiveChatFrames() do
        local f = _G["ChatFrame"..i]
        local found
        for k,v in pairs(f.messageTypeList) do
            if strupper(v) == "LOOT" then
                found = true
            end
        end
        if found then
            self.lootframes[f] = true
        else
            self.lootframes[f] = false
        end
    end
end

function mod:ChatFrame_AddMessageGroup(frame, group)
    if group == "LOOT" then
        local wasregistered
        for k,v in pairs(frame.messageTypeList) do
            if strupper(v) == group then
                self.lootframes[frame] = true
            end
        end
    end
    self.hooks.ChatFrame_AddMessageGroup(frame, group)
end

function mod:ChatFrame_RemoveMessageGroup(frame, group)
    if group == "LOOT" then
        local wasregistered
        for k,v in pairs(frame.messageTypeList) do
            if strupper(v) == group then
                self.lootframes[frame] = false
            end
        end
    end
    self.hooks.ChatFrame_RemoveMessageGroup(frame, group)
end
