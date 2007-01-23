LootAlert = {}

function LootAlert:ADDON_LOADED(name)
    if name == 'LootAlert' then
        if MikSBT then
            self.msg = function(message, color)
                MikSBT.DisplayMessage(message, MikSBT.DISPLAYTYPE_NOTIFICATION, false, color.r * 255, color.g * 255, color.b * 255)
            end
        elseif SCT_Display then
            self.msg = SCT_Display_Message
        elseif SCT and SCT.DisplayText then
            self.msg = function(message, color)
                SCT:DisplayMessage(message, color)
            end
        elseif CombatText_AddMessage then
            self.msg = function(message, color)
                CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b, 'sticky', nil)
            end
        end

        if self.msg then
            this:RegisterEvent('CHAT_MSG_LOOT')
            this:UnregisterEvent('ADDON_LOADED')
        end
    elseif name == 'Blizzard_CombatText' then
        -- This block is only used if we loaded before Blizzard_CombatText,
        -- and the user does not have sct or msbt.  We don't want to
        -- OptionalDeps on it, or it'll force the LoD addon to load.
        self.msg = function(message, color)
            CombatText_AddMessage(message, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b, 'sticky', nil)
        end

        this:RegisterEvent('CHAT_MSG_LOOT')
        this:UnregisterEvent('ADDON_LOADED')
    end
end

local linkpat = '|c........|Hitem:(%%d+):.*|r'
local single = LOOT_ITEM_SELF:gsub('%%s', linkpat)
local multiple = LOOT_ITEM_SELF_MULTIPLE:gsub('%%d', '(%%d+)'):gsub('%%s', linkpat)

function LootAlert:CHAT_MSG_LOOT(msg)
    local item, count = msg:match(multiple)
    if not item then
        item = msg:match(single)
        count = 1
    end

    if item then
        local oldtotal = GetItemCount(item)
        local name, _, rarity = GetItemInfo(item)
        local message = ('[Loot %s +%d(%d)]'):format(name, count, oldtotal + count)
        local color = ITEM_QUALITY_COLORS[rarity]

        self.msg(message, color)
    end
end

-- Initialization
LootAlert.frame = CreateFrame('Frame', nil, UIParent)
LootAlert.frame:SetScript('OnEvent', function(self, event, ...)
    LootAlert[event](LootAlert, ...)
end)
LootAlert.frame:RegisterEvent('ADDON_LOADED')
