DoItAll = DoItAll or {}
local DoItAllSlots = DoItAll.Slots:New(DoItAll.ItemFilter:New(true))
local extractFunction, container

--======================================================================================================================
--  Keybindings
--======================================================================================================================
local function GetKeyStripName()
    local mode = SMITHING.mode
    local enchantMode = ENCHANTING.enchantingMode

    if mode == SMITHING_MODE_REFINMENT then
        return "Refine all"
    elseif mode == SMITHING_MODE_DECONSTRUCTION then
        return "Deconstr. all"
    end
    if enchantMode == ENCHANTING_MODE_EXTRACTION then
        return "Extract all"
    end
    return "Extract all"
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

local function GetExtractionContainerAndFunction()
  if DoItAll.IsShowingExtraction() then
    return ZO_EnchantingTopLevelInventoryBackpack, ExtractEnchantingItem
  elseif DoItAll.IsShowingDeconstruction() then
    return ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack, ExtractOrRefineSmithingItem
  elseif DoItAll.IsShowingRefinement() then
    return ZO_SmithingTopLevelRefinementPanelInventoryBackpack, ExtractOrRefineSmithingItem
  end
end

local function GetNextSlotToExtract()
  if not DoItAllSlots:Fill(container, 1) then
	DoItAllSlots:ClearNotAllowed()
  	return nil
  end
  return DoItAllSlots:Next()
end

local function ExtractionFinished()
	--Set the global variable to false: Extraction was finished/Aborted
	DoItAll.extractionActive = false
	--Unregister the events for the extraction
	EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftCompleted", EVENT_CRAFT_COMPLETED)
    --UNregister the crafting start event to check if an error happened later on
    --EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftStarted", EVENT_CRAFT_STARTED)
    --Unregister the crafting failed event to check if some variables need to be resetted
    EVENT_MANAGER:UnregisterForEvent("DoItAllExtractionCraftFailed", EVENT_CRAFT_FAILED)
end

--Event handler for EVENT_END_CRAFTING_STATION_INTERACT at extraction
local function OnCraftingEnd(eventCode)
--d("[DoItAll] OnCraftingEnd - Extraction")
	if DoItAll.extractionActive then
		d("[DoItAll] Extraction was aborted!")
		ExtractionFinished()
	end
end

--Callback function for EVENT_CRAFT_STARTED
local function OnSingleCraftFailed(eventCode, tradeskillResult)
--d("[DoItAll] CraftFailed - Extraction. TradeskillResult: " ..tostring(tradeskillResult))
    if tradeskillResult == CRAFTING_RESULT_INTERRUPTED then
        OnCraftingEnd()
    end
end

--Callback function for EVENT_CRAFT_STARTED
--local function OnSingleCraftStarted(eventCode, tradeskillType)
--    d("[DoItAll] CraftStarted - Extraction")
--end

local function ExtractNext(firstExtract)
--d("[DoItAll]ExtractNext, extraction active: " .. tostring(DoItAll.extractionActive))
	--Prevent "hang up extractions" from last crafting station visit activating extraction all slots if something else was crafted!
	if not DoItAll.extractionActive then
		return
	end
	local delayMs = 0
	firstExtract = firstExtract or false

--d("[DoItAll]ExtractNext("..tostring(firstExtract)..")")

	--get the next slot to extract
	local doitall_slot = GetNextSlotToExtract()
	if not doitall_slot then
		--No slot left -> Finish here
		ExtractionFinished()
	else
		local extractable = true
		--Are we inside refinement?
	    --Is the current slot's stackCount < 10 (no refinement is possible then)?
		if DoItAll.IsShowingRefinement() and doitall_slot.stackCount < 10 then
	       	extractable = false
		end
		if extractable then
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
		else
			--Disallow this item to be tried to extracted again
			DoItAllSlots:AddToNotAllowed(doitall_slot.bagId, doitall_slot.slotIndex)
            --Go on with next slot as the event EVENT_CRAFT_COMPLETED won't be called
			ExtractNext(false)
	    end
	end
end

local function StartExtraction()
    --Set global variable to see if DoItAll extraction is active
    DoItAll.extractionActive = true

    --Register the crafting start event to check if an error happened later on
    --EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftStarted", EVENT_CRAFT_STARTED, OnSingleCraftStarted)
    --Register the crafting failed event to check if some variables need to be resetted
    EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftFailed", EVENT_CRAFT_FAILED, OnSingleCraftFailed)
	--Register event to check if extraction has been aborted -> Avoid automatic extraction next time an item has been extracted
	EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftCompleted", EVENT_CRAFT_COMPLETED, function() ExtractNext(false) end)

	--Start the extraction. Every next slot will be handled via ExtractNext function from EVENT_CRAFT_COMPLETED then
	ExtractNext(true)
end

function DoItAll.ExtractAll()
  container, extractFunction = GetExtractionContainerAndFunction()
  if container == nil then return end
	--Clear/Initialize the not allowed slot entries
	DoItAllSlots:ClearNotAllowed()
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
EVENT_MANAGER:RegisterForEvent("DoItAllExtractionCraftingEndInteract", EVENT_END_CRAFTING_STATION_INTERACT, function()
    --d("[DoItAll] CraftingStationInteract END - Extraction")
    --Extraction
    OnCraftingEnd()

    --Keybinds
    --Remove the old keybind if there is still one activated
    if DoItAll.currentKeyStripDef ~= nil then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(DoItAll.currentKeyStripDef)
    end
    --Reset the last used one
    DoItAll.currentKeyStripDef = nil
end)