DoItAll = DoItAll or {}
local DoItAllSlots = DoItAll.Slots:New(DoItAll.ItemFilter:New(true))
local extractFunction, container, craftingTableCtrlVar, craftingTablePanel
local addedToCraftCounter = 0
local goOnLaterWithExtraction = false
local extractNextCalls = 0
--======================================================================================================================
--  Keybindings
--======================================================================================================================
local function GetKeyStripName()
    local mode = SMITHING.mode
    local enchantMode = ENCHANTING.enchantingMode
    local useZOsVanillaUIForMulticraft = DoItAll.IsZOsVanillaUIMultiCraftEnabled() or false
    local retVarStr = ""
    if useZOsVanillaUIForMulticraft then
        retVarStr = "Extract all (Multi)"
    else
        retVarStr = "Extract all (DoItAll)"
    end
    if mode == SMITHING_MODE_REFINMENT then
        if useZOsVanillaUIForMulticraft then
            retVarStr = "Refine all (Multi)"
        else
            retVarStr = "Refine all (DoItAll)"
        end
        return retVarStr
    elseif mode == SMITHING_MODE_DECONSTRUCTION then
        if useZOsVanillaUIForMulticraft then
            retVarStr = "Deconstr. all (Multi)"
        else
            retVarStr = "Deconstr. all (DoItAll)"
        end
        return retVarStr
    end
    if enchantMode == ENCHANTING_MODE_EXTRACTION then
        return retVarStr
    end
    return retVarStr
end

local function ShouldShow()
    local mode = SMITHING.mode
    local enchantMode = ENCHANTING.enchantingMode

    if mode == SMITHING_MODE_REFINMENT then
        return true
    elseif mode == SMITHING_MODE_DECONSTRUCTION then
        return true
    end
    if enchantMode == ENCHANTING_MODE_EXTRACTION then
        return true
    end
    return false
end

local keystripDef = {
    name = function() return GetKeyStripName() end,
    keybind = "SC_BANK_ALL",
    callback = function() DoItAll.ExtractAll() end,
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    visible = function() return ShouldShow() end,
}

table.insert(SMITHING.keybindStripDescriptor, keystripDef)
table.insert(ENCHANTING.keybindStripDescriptor, keystripDef)



--======================================================================================================================
-- Extraction
--======================================================================================================================
function DoItAll.IsShowingExtraction()
	return not ZO_EnchantingTopLevelExtractionSlotContainer:IsHidden()
end

function DoItAll.IsShowingDeconstruction()
	return not ZO_SmithingTopLevelDeconstructionPanelSlotContainer:IsHidden()
end

function DoItAll.IsShowingRefinement()
	return not ZO_SmithingTopLevelRefinementPanelSlotContainer:IsHidden()
end

local function GetExtractionContainerFunctionCtrlAndPanel()
  if DoItAll.IsShowingExtraction() then
    return ZO_EnchantingTopLevelInventoryBackpack, ExtractEnchantingItem, ENCHANTING, ENCHANTING
  elseif DoItAll.IsShowingDeconstruction() then
    return ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack, ExtractOrRefineSmithingItem, SMITHING, SMITHING.deconstructionPanel
  elseif DoItAll.IsShowingRefinement() then
    return ZO_SmithingTopLevelRefinementPanelInventoryBackpack, ExtractOrRefineSmithingItem, SMITHING, SMITHING.refinementPanel
  end
end

local function GetNextSlotToExtract()
  if not DoItAllSlots:Fill(container, 1) then
	DoItAllSlots:ClearNotAllowed()
  	return nil
  end
  return DoItAllSlots:Next()
end

local function ExtractionFinished(wasError)
    wasError = wasError or false
    --No extraction was started? Then unregister old events which might have been get stuck due to lua errors!
    if not DoItAll.extractionActive then
        goOnLaterWithExtraction = false
        EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftCompleted", EVENT_CRAFT_COMPLETED)
        --UNregister the crafting start event to check if an error happened later on
        --EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftStarted", EVENT_CRAFT_STARTED)
        --Unregister the crafting failed event to check if some variables need to be resetted
        EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftFailed", EVENT_CRAFT_FAILED)
        return
    end
    local useZOsVanillaUIForMulticraft
    local wasExtracted = false
--d("[DoItAll]ExtractionFinished, wasError: " ..tostring(wasError))
    if not wasError then
        useZOsVanillaUIForMulticraft = DoItAll.IsZOsVanillaUIMultiCraftEnabled() or false
        if useZOsVanillaUIForMulticraft then
            --Extract the slotted items now
            if DoItAll.IsShowingRefinement() and craftingTablePanel.ConfirmRefine then
                craftingTablePanel:ConfirmRefine()
                wasExtracted = true
            else
                if craftingTablePanel.extractionSlot then
                    if craftingTablePanel.extractionSlot:HasOneItem() then
                        if craftingTablePanel.ExtractSingle then
                            craftingTablePanel:ExtractSingle()
                            wasExtracted = true
                        else
                            if craftingTablePanel.ConfirmExtractAll then
                                craftingTablePanel:ConfirmExtractAll()
                                wasExtracted = true
                            end
                        end
                    elseif craftingTablePanel.extractionSlot:HasMultipleItems() then
                        if craftingTablePanel.ConfirmExtractAll then
                            craftingTablePanel:ConfirmExtractAll()
                            wasExtracted = true
                        end
                    else
                        goOnLaterWithExtraction = false
                        wasExtracted = true
                    end
                else
                    goOnLaterWithExtraction = false
                    wasExtracted = true
                end
            end
        else
            goOnLaterWithExtraction = false
            wasExtracted = true
        end
    end
    --Security check toi prevent endless loop if the extraction functions did not work or exist anymore
    if not wasExtracted then
        goOnLaterWithExtraction = false
    end
    --Unregister the events for the extraction but only if we are not waiting for possible next slots to extract after the current ones
    --via ZOs vanilla UI Multicraft
    if not goOnLaterWithExtraction then
        EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftCompleted", EVENT_CRAFT_COMPLETED)
        --UNregister the crafting start event to check if an error happened later on
        --EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftStarted", EVENT_CRAFT_STARTED)
        --Unregister the crafting failed event to check if some variables need to be resetted
        EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftFailed", EVENT_CRAFT_FAILED)
    end
    --Set the global variable to false: Extraction was finished/Aborted
    DoItAll.extractionActive = false
end

--Event handler for EVENT_END_CRAFTING_STATION_INTERACT at extraction
local function OnCraftingEnd(eventCode, wasError)
--d("[DoItAll] OnCraftingEnd - Extraction")
	if DoItAll.extractionActive then
		d("[DoItAll] Extraction was aborted!")
		ExtractionFinished(wasError)
	end
end

--Callback function for EVENT_CRAFT_STARTED
local function OnSingleCraftFailed(eventCode, tradeskillResult)
--d("[DoItAll] CraftFailed - Extraction. TradeskillResult: " ..tostring(tradeskillResult))
    if tradeskillResult == CRAFTING_RESULT_INTERRUPTED then
        OnCraftingEnd(eventCode, true)
    end
end

--Callback function for EVENT_CRAFT_STARTED
--local function OnSingleCraftStarted(eventCode, tradeskillType)
--    d("[DoItAll] CraftStarted - Extraction")
--end

local function ExtractNext(firstExtract)
    extractNextCalls = extractNextCalls +1
    if extractNextCalls > 200 then
        DoItAll.extractionActiv = false
        addedToCraftCounter = 20000
        goOnLaterWithExtraction = false
        return
    end
    firstExtract = firstExtract or false
--d("[DoItAll]ExtractNext, extraction active: " .. tostring(DoItAll.extractionActive) .. ", firstExtract: " ..tostring(firstExtract))
    --Prevent "hang up extractions" from last crafting station visit activating extraction all slots if something else was crafted!
    if not DoItAll.extractionActive then
        d(">1")
        addedToCraftCounter = 999
        goOnLaterWithExtraction = false
        return
    end
    local delayMs = 0
--d(">addedToCraftCounter: " ..tostring(addedToCraftCounter))

    --d("[DoItAll]ExtractNext("..tostring(firstExtract)..")")

    --get the next slot to extract
    local doitall_slot = GetNextSlotToExtract()
    if not doitall_slot then
--d("<<<NO SLOT LEFT-> FINISHED!")
        --No slot left -> Finish here
        goOnLaterWithExtraction = false
        ExtractionFinished()
    else
        local extractable = true
        if craftingTableCtrlVar.CanItemBeAddedToCraft then
            extractable = craftingTableCtrlVar:CanItemBeAddedToCraft(doitall_slot.bagId, doitall_slot.slotIndex)
        else
            --Are we inside refinement?
            --Is the current slot's stackCount < 10 (no refinement is possible then)?
            if DoItAll.IsShowingRefinement() and doitall_slot.stackCount ~= nil and doitall_slot.stackCount < 10 then
                extractable = false
            end
        end
        if extractable then
--d(">item is extractable: " .. GetItemLink(doitall_slot.bagId, doitall_slot.slotIndex))
            --Is the vanilla UI ZOs multicraft (added with Scalebreaker patch) the one to extarct all?
            --Or should DoItAll handle this like before on it's own?
            if DoItAll.IsZOsVanillaUIMultiCraftEnabled() then
                if craftingTableCtrlVar.AddItemToCraft then
                    --Code for max stack count and max deconstructable items taken from function ZO_SharedSmithingExtraction:AddItemToCraft(bagId, slotIndex)
                    -->esoui/ingame/crafting/smithingextraction_shared.lua
                    local extractionSlot = craftingTablePanel.extractionSlot
                    local isInRefineMode = craftingTableCtrlVar.mode == SMITHING_MODE_REFINMENT or false
                    local newStackCount = extractionSlot:GetStackCount() + zo_max(1, craftingTablePanel.inventory:GetStackCount(doitall_slot.bagId, doitall_slot.slotIndex)) -- non virtual items will have a stack count of 0, but still count as 1 item
                    local stackCountPerIteration = isInRefineMode and GetRequiredSmithingRefinementStackSize() or 1
                    local maxStackCount = MAX_ITERATIONS_PER_DECONSTRUCTION * stackCountPerIteration
                    local stackCountCanBeAdded = newStackCount <= maxStackCount or false
--d(">extractionSlot has items: " .. tostring(extractionSlot:HasItems()) .. ", numItems: " .. tostring(extractionSlot:GetNumItems()) ..", stackCountCanBeAdded: " .. tostring(stackCountCanBeAdded) .. " (newStackCount: " ..tostring(newStackCount) .. ", stackCountPerIteration: " ..tostring(stackCountPerIteration) ..")")

                    goOnLaterWithExtraction = false
                    -- Pevent slotting if it would take us above the MAX_ITEM_SLOTS_PER_DECONSTRUCTION or the stackCount iteration limit,
                    -- but allow it if nothing else has been slotted yet so we can support single stacks that are larger than the limit
                    if extractionSlot:GetNumItems() >= MAX_ITEM_SLOTS_PER_DECONSTRUCTION or (extractionSlot:HasItems() and not stackCountCanBeAdded) then
                        --Security check to prevent endless loops!
                        if addedToCraftCounter > 0 then
                            goOnLaterWithExtraction = true
                            --Extract the 100 items now and then goOn with the next up to 100 items
                            ExtractionFinished(false)
                        end
                    else
                        addedToCraftCounter = addedToCraftCounter + 1
                        --Only add the item to the extraction slot
                        craftingTableCtrlVar:AddItemToCraft(doitall_slot.bagId, doitall_slot.slotIndex)
                        --Disallow this item to be tried to added for extraction again in next call to ExtractNext
                        DoItAllSlots:AddToNotAllowed(doitall_slot.bagId, doitall_slot.slotIndex)
                        --Go on with next slot as the event EVENT_CRAFT_COMPLETED won't be called
                        ExtractNext(false)
                    end
                end

            else
                --Use DoItALL to extract 1 item after another
                if not firstExtract then
                    --Get the MS for the delay between extractions
                    delayMs = DoItAll.Settings.GetExtractDelay()
                else
                    delayMs = 0
                end
                --d("[DoItAll]ExtractNext delay: " .. tostring(delayMs))
                if delayMs > 0 then
                    --Call the extraction function with a delay
                    zo_callLater(function() extractFunction(doitall_slot.bagId, doitall_slot.slotIndex) end, delayMs)
                else
                    extractFunction(doitall_slot.bagId, doitall_slot.slotIndex)
                end
            end
        else
            --Disallow this item to be tried to extracted again
            DoItAllSlots:AddToNotAllowed(doitall_slot.bagId, doitall_slot.slotIndex)
            --Go on with next slot as the event EVENT_CRAFT_COMPLETED won't be called
            ExtractNext(false)
        end
    end
end

local function StartExtraction()
--d("[DoItAll]StartExtraction")
    --Set global variable to see if DoItAll extraction is active
    DoItAll.extractionActive = true
    --Register the crafting start event to check if an error happened later on
    --EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftStarted", EVENT_CRAFT_STARTED, OnSingleCraftStarted)
    --Register the crafting failed event to check if some variables need to be resetted
    EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftFailed", EVENT_CRAFT_FAILED, OnSingleCraftFailed)
	--Register event to check if extraction has been aborted -> Avoid automatic extraction next time an item has been extracted
	EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftCompleted", EVENT_CRAFT_COMPLETED,
            function()
                --Only go on with the next slot to extract if not the ZOs vanilla UI multicraft is used
                if not DoItAll.IsZOsVanillaUIMultiCraftEnabled() then
                    ExtractNext(false)
                else
                    --Shall we go on with the extraction with ZOs vanilla UI multicraft?
                    if goOnLaterWithExtraction == true then
                        DoItAll.ExtractAll()
                    end
                end
            end)
    --Start the extraction. Every next slot will be handled via ExtractNext function from EVENT_CRAFT_COMPLETED then
    ExtractNext(true)
end

function DoItAll.ExtractAll()
--d("[DoItAll]ExtractAll")
    --ZOs UI is handling the extraction
    container, extractFunction, craftingTableCtrlVar, craftingTablePanel = GetExtractionContainerFunctionCtrlAndPanel()
    if container == nil or craftingTableCtrlVar == nil then return end
    --Clear/Initialize the not allowed slot entries
    DoItAllSlots:ClearNotAllowed()
    addedToCraftCounter = 0
    goOnLaterWithExtraction = false
    extractNextCalls = 0
    --Start the extraction
    StartExtraction()
end

--Crafting Station interaction - BEGIN
EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftingInteract", EVENT_CRAFTING_STATION_INTERACT, function(eventCode, TradeskillType , sameStation)
    --d("[DoItAll] CraftingStationInteract BEGIN - Extraction")
    --Extraction
    --Reset the extraction is active variable
    DoItAll.extractionActive = false
    --Supported crafting station?
    if TradeskillType ~= CRAFTING_TYPE_PROVISIONING and TradeskillType ~= CRAFTING_TYPE_ALCHEMY then
        --Keybinds
        --Remove the old keybind if there is still one activated
        if DoItAll.currentKeyStripDef ~= nil then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(DoItAll.currentKeyStripDef)
        end
        --Add the keystrip def to the global vars so we can reach it from everywhere
        DoItAll.currentKeyStripDef = keystripDef
    end
end)
--Crafting Station interaction - END
EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftingEndInteract", EVENT_END_CRAFTING_STATION_INTERACT, function(eventCode)
    --d("[DoItAll] CraftingStationInteract END - Extraction")
    --Extraction
    OnCraftingEnd(eventCode, false)

    --Keybinds
    --Remove the old keybind if there is still one activated
    if DoItAll.currentKeyStripDef ~= nil then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(DoItAll.currentKeyStripDef)
    end
    --Reset the last used one
    DoItAll.currentKeyStripDef = nil
end)