DoItAll = DoItAll or {}
DoItAll.Settings = {}
DoItAll.Settings.Options = {}
DoItAll.Settings.DefaultOptions = {
  BatchSize = 20,
  BatchDelay = 200,
  ExtractDelay = 200,
  RespectItemSaver = true,
  --UseISFilterSetChecks = false,
  UseFCOISFilterPanelChecks = false,
  KeepResearchableItems = true,
  SendMailFull = false,
  SendMailEnd = false
}

local function CreateControl(setting, name, tooltip, data, disabledChecks)
  data.name = name
  data.tooltip = tooltip
  data.getFunc = function() return DoItAll.Settings["Get" .. setting]() end
  data.setFunc = function(value) DoItAll.Settings["Set" .. setting](value) end
  data.default = DoItAll.Settings.DefaultOptions[setting]
  data.reference = "DoItAll_" .. setting
    if disabledChecks ~= nil then
        data.disabled = disabledChecks
    end
  return data
end

local function CreateCheckbox(setting, name, tooltip, disabledChecks)
  return CreateControl(setting, name, tooltip, { type = "checkbox" }, disabledChecks)
end

local function CreateSlider(setting, name, tooltip, min, max, step, disabledChecks)
  return CreateControl(setting, name, tooltip, { type = "slider", min = min, max = max, step = step }, disabledChecks)
end

local function CreateHeader(name)
  return { type = "header", name = name }
end

local function SetupOptionsMenu()
  local panelData = {
    type = "panel",
    name = "DoItAll",
    author = "Thenedus, modified by Baertram",
    version = tostring(DoItAll.AddOnVersion),
    registerForDefaults = true,
    slashCommand = "/doitall",
    website = "http://www.esoui.com/downloads/info690-DoItAll.html",
  }

  local optionsData = {
    CreateHeader("General"),
    CreateCheckbox("RespectItemSaver", "Keep saved items", "Do not handle items that are saved with Item Saver/FCO ItemSaver."),
    CreateCheckbox("UseFCOISFilterPanelChecks", "Use FCO ItemSaver panel checks", "Check items marked with FCO ItemSaver for the actual filter panel anti-settings (mail, trade, extract, sell, etc.), instead of only checking if the item got any of the FCOIS marker icons active.\n\nThis will alow you to e.g. deconstruct items even if they are marked with a marker icon, but the marker icon settings allows deconstruction."),
    --CreateCheckbox("UseISFilterSetChecks", "Use ItemSaver set checks", "Check items marked with ItemSaver for the actual filter set settings (mail, trade, extract, sell, etc.), instead of only checking if the item got any of the Itemsaver marker icons active.\n\nThis will alow you to e.g. deconstruct items even if they are marked with a marker icon, but the marker icon settings allows deconstruction in this filter set."),
    CreateHeader("Transfer All"),
    CreateSlider("BatchSize", "Batch Size", "The number of items to transfer in one batch.", 1, 200, 5),
    CreateSlider("BatchDelay", "Batch Delay [ms]", "The number of milliseconds to wait between two batches.", 100, 1000, 10),
    CreateHeader("Extract/Deconstruct/Refine All"),
    CreateSlider("ExtractDelay", "Extract Delay [ms]", "The number of milliseconds to wait between each extraction.", 0, 1000, 10),
    CreateCheckbox("KeepResearchableItems", "Keep researchable items", "Do not deconstruct items that are have a researchable trait (requires Research Assistant)."),
    CreateHeader("Attach All"),
    CreateCheckbox("SendMailFull", "Send full mails", "Send mail when all attachment slots are full."),
    CreateCheckbox("SendMailEnd", "Send mail when done", "Send mail when all items have been attached (even though not all attachment slots may have been used).")
  }

  local LAM2 = DoItAll.LAM
  LAM2:RegisterAddonPanel("DoItAllSettings", panelData)
  LAM2:RegisterOptionControls("DoItAllSettings", optionsData)
end

local function CreateGettersAndSetters()
  for option, _ in pairs(DoItAll.Settings.DefaultOptions) do
    DoItAll.Settings["Get" .. option] = function() return DoItAll.Settings.Options[option] end
    DoItAll.Settings["Set" .. option] = function(value) DoItAll.Settings.Options[option] = value end
  end
end

function DoItAll.Settings.Initialize()
  DoItAll.Settings.Options = ZO_SavedVars:NewCharacterIdSettings("DoItAllSV", 2, nil, DoItAll.Settings.DefaultOptions, GetWorldName())
  CreateGettersAndSetters()
  SetupOptionsMenu()
end
