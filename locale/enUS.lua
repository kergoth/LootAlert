local L = LibStub("AceLocale-3.0"):NewLocale("LootAlert", "enUS", true)
if L then
    L["Enabled"] = true
    L["Enable/Disable the addon."] = true
    L["Modify chat messages"] = true
    L["Modify loot chat messages to use LootAlert's formatting."] = true
    L["Item Quality Threshold"] = true
    L["Threshold"] = true
    L["Hide items looted with a lower quality than this."] = true
    L["Apply to chat messages"] = true
    L["Apply item quality threshold to chat messages"] = true
    L["Item Quality Coloring"] = true
    L["Color the item based on its quality, like an item link."] = true
    L["Item Icon"] = true
    L["Text Color"] = true

    L["Money Format"] = true
    L["Condensed"] = true
    L["Text"] = true
    L["Full"] = true

    L["Example Messages"] = true
    L["Formatting Options"] = true

    L["Prefix"] = true
    L["Enable a text prefix (i.e. 'Loot: ')"] = true
    L["Prefix Text"] = true

    L["Output"] = true
    L["Loot: "] = true

    L["New method"] = true
    L["BETA: Use new method of tracking the item counts, to fix the occasional miscount bug."] = true
end
