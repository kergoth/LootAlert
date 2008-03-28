local L = LibStub("AceLocale-3.0"):NewLocale("LootAlert", "enUS", true)
if L then
    L["Enabled"] = true
    L["Enable/Disable the addon."] = true
    L["Item Quality Threshold"] = true
    L["Hide items looted with a lower quality than this."] = true
    L["Item Quality Coloring"] = true
    L["Color the item based on its quality, like an item link."] = true
    L["Show Item Icon"] = true
    L["Show Money Icons"] = true
    L["Show icons for gold/silver/copper rather than g/s/c."] = true
    L["Text Color"] = true

    L["LOOTMESSAGE"] = "Loot: %s|r%s"
    L["MONEYMESSAGE"] = "Loot: %s%s%s"
end
