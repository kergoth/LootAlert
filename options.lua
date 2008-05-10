local L = LibStub("AceLocale-3.0"):GetLocale("LootAlert")
local mod = LibStub("AceAddon-3.0"):GetAddon("LootAlert")
local reg = LibStub("AceConfigRegistry-3.0")

function mod.getOptions()
    local db = mod.db.profile
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
