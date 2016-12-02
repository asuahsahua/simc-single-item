local _, Addon = ...

Addon = LibStub("AceAddon-3.0"):NewAddon(Addon, "simc-single-item", "AceConsole-3.0", "AceEvent-3.0")

local OFFSET_ITEM_ID = 1
local OFFSET_ENCHANT_ID = 2
local OFFSET_GEM_ID_1 = 3
local OFFSET_GEM_ID_2 = 4
local OFFSET_GEM_ID_3 = 5
local OFFSET_GEM_ID_4 = 6
local OFFSET_SUFFIX_ID = 7
local OFFSET_FLAGS = 11
local OFFSET_BONUS_ID = 13
local OFFSET_UPGRADE_ID = 14 -- Flags = 0x4

local slotLookup = {
    ["INVTYPE_HEAD"] = "head",
    ["INVTYPE_NECK"] = "neck",
    ["INVTYPE_SHOULDER"] = "shoulder",
    ["INVTYPE_CLOAK"] = "back",
    ["INVTYPE_CHEST"] = "chest",
    ["INVTYPE_WRIST"] = "wrist",
    ["INVTYPE_HAND"] = "hands",
    ["INVTYPE_LEGS"] = "legs",
    ["INVTYPE_FEET"] = "feet",
    ["INVTYPE_FINGER"] = "finger1",
    ["INVTYPE_TRINKET"] = "trinket1",
}

function Addon:OnInitialize()
    Addon:RegisterChatCommand('simc-hover', 'PrintItemString')
end

function Addon:PrintItemString()
    local itemName, itemLink = GameTooltip:GetItem()
    if not itemLink then
        print "Not hovering over an item"
    end

    -- if we don't have an item link, we don't care
    local itemString = string.match(itemLink, "item:([%-?%d:]+)")
    local itemSplit = {}
    local simcItemOptions = {}

    -- Split data into a table
    for v in string.gmatch(itemString, "(%d*:?)") do
        if v == ":" then
            itemSplit[#itemSplit + 1] = 0
        else
            itemSplit[#itemSplit + 1] = string.gsub(v, ':', '')
        end
    end

    -- Item id
    local itemId = itemSplit[OFFSET_ITEM_ID]
    simcItemOptions[#simcItemOptions + 1] = ',id=' .. itemId

    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(itemId);

    -- Enchant
    if tonumber(itemSplit[OFFSET_ENCHANT_ID]) > 0 then
        simcItemOptions[#simcItemOptions + 1] = 'enchant_id=' .. itemSplit[OFFSET_ENCHANT_ID]
    end

    -- New style item suffix, old suffix style not supported
    if tonumber(itemSplit[OFFSET_SUFFIX_ID]) ~= 0 then
        simcItemOptions[#simcItemOptions + 1] = 'suffix=' .. itemSplit[OFFSET_SUFFIX_ID]
    end

    local flags = tonumber(itemSplit[OFFSET_FLAGS])

    local bonuses = {}

    for index=1, tonumber(itemSplit[OFFSET_BONUS_ID]) do
        bonuses[#bonuses + 1] = itemSplit[OFFSET_BONUS_ID + index]
    end

    if #bonuses > 0 then
        simcItemOptions[#simcItemOptions + 1] = 'bonus_id=' .. table.concat(bonuses, '/')
    end

    local rest_offset = OFFSET_BONUS_ID + #bonuses + 1

    -- Upgrade level
    if bit.band(flags, 4) == 4 then
        local upgrade_id = tonumber(itemSplit[rest_offset])
        if self.upgradeTable[upgrade_id] ~= nil and self.upgradeTable[upgrade_id] > 0 then
            simcItemOptions[#simcItemOptions + 1] = 'upgrade=' .. self.upgradeTable[upgrade_id]
        end
        rest_offset = rest_offset + 1
    end

    -- Artifacts use this
    if bit.band(flags, 256) == 256 then
        rest_offset = rest_offset + 1 -- An unknown field
        local relic_str = ''
        while rest_offset < #itemSplit do
            local n_bonus_ids = tonumber(itemSplit[rest_offset])
            rest_offset = rest_offset + 1

            if n_bonus_ids == 0 then
                relic_str = relic_str .. 0
            else
                for rbid = 1, n_bonus_ids do
                    relic_str = relic_str .. itemSplit[rest_offset]
                    if rbid < n_bonus_ids then
                        relic_str = relic_str .. ':'
                    end
                    rest_offset = rest_offset + 1
                end
            end

            if rest_offset < #itemSplit then
                relic_str = relic_str .. '/'
            end
        end

        if relic_str ~= '' then
            simcItemOptions[#simcItemOptions + 1] = 'relic_id=' .. relic_str
        end
    end

    -- Some leveling quest items seem to use this, it'll include the drop level of the item
    if bit.band(flags, 512) == 512 then
        simcItemOptions[#simcItemOptions + 1] = 'drop_level=' .. itemSplit[rest_offset]
        rest_offset = rest_offset + 1
    end

    -- Gems
    local gems = {}
    for i=1, 4 do -- hardcoded here to just grab all 4 sockets
    local _,gemLink = GetItemGem(itemLink, i)
    if gemLink then
        local gemDetail = string.match(gemLink, "item[%-?%d:]+")
        gems[#gems + 1] = string.match(gemDetail, "item:(%d+):" )
    elseif flags == 256 then
        gems[#gems + 1] = "0"
    end
    end
    if #gems > 0 then
        simcItemOptions[#simcItemOptions + 1] = 'gem_id=' .. table.concat(gems, '/')
    end

    -- determine slot number...
    local simulationcraftProfile = slotLookup[equipSlot] .. "=" .. table.concat(simcItemOptions, ',')

    -- show the appropriate frames
    SimcCopyFrame:Show()
    SimcCopyFrameScroll:Show()
    SimcCopyFrameScrollText:Show()
    SimcCopyFrameScrollText:SetText(simulationcraftProfile)
    SimcCopyFrameScrollText:HighlightText()
end
