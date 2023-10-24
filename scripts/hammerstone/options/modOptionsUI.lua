--- Hammerstone: modOptionsUI.lua
--- @author Witchy

-- Sapiens
-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local material = mjrequire "common/material"
local model = mjrequire "common/model"
local gameObject = mjrequire "common/gameObject"

local uiSlider = mjrequire "mainThread/ui/uiCommon/uiSlider"
local uiPopUpButton = mjrequire "mainThread/ui/uiCommon/uiPopUpButton"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiSelectionLayout = mjrequire "mainThread/ui/uiCommon/uiSelectionLayout"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"

-- Hammerstone
local log = mjrequire "hammerstone/logging"

local modOptionsUI = {
    name = "Mod Options",
	view = nil,
	parent = nil,
	icon = "icon_modOptions",
}

local viewsByEnableCondition = {}

local tabView = nil
local rightView = nil
local tabButtonsView = nil

local activeSelectedControllableSubView = nil
local currentView = nil
local currentButton = nil
local currentPopOversView = nil

local tabWidth = 180.0
local yOffsetBetweenElements = 35
local buttonSize = vec2(200, 40)
local popUpMenuSize = vec2(240, 180)
local elementTitleX = nil
local elementControlX = nil
local elementYOffset = 0

local currentTitle = nil
local manageUI = nil

local modOptionsManager = nil

function modOptionsUI:getTitle()
    return currentTitle or "Mod Options"
end

function modOptionsUI:setModOptionsManager(modOptionsManager_)
    modOptionsManager = modOptionsManager_
end

local function changeActiveSelectedControlView(newControlView)
    --mj:log("changeActiveSelectedControlView:", newControlView)
    if activeSelectedControllableSubView ~= newControlView then
        activeSelectedControllableSubView = newControlView
        if activeSelectedControllableSubView then
            uiSelectionLayout:setActiveSelectionLayoutView(activeSelectedControllableSubView)
        else
            uiSelectionLayout:setActiveSelectionLayoutView(tabButtonsView)
        end
    end 
end

function modOptionsUI:show()
    self.view.hidden = false
    uiSelectionLayout:setActiveSelectionLayoutView(tabButtonsView)
end

function modOptionsUI:hide()
    if activeSelectedControllableSubView then
        changeActiveSelectedControlView(nil)
    end
    uiSelectionLayout:removeActiveSelectionLayoutView(tabButtonsView)
end

function modOptionsUI:init(contentView, manageUI_)
    manageUI = manageUI_

    local mainView = View.new(contentView)
    mainView.size = contentView.size
	mainView.hidden = true

    modOptionsUI.view = mainView

    local rightViewBottomPadding = 20.0
    local tabHeight = mainView.size.y - 80.0

    tabView = ModelView.new(mainView)
    tabView:setModel(model:modelIndexForName("ui_inset_lg_1x4"))
    local tabViewScaleToUse = tabHeight * 0.5
    local tabViewScaleToUseX = tabWidth * (4.0 / 1.0) * 0.5
    tabView.scale3D = vec3(tabViewScaleToUseX,tabViewScaleToUse,tabViewScaleToUse)
    tabView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    tabView.size = vec2(tabWidth, tabHeight)
    tabView.baseOffset = vec3(40, 0, -2)

    rightView = View.new(mainView)
    rightView.size = vec2(mainView.size.x - tabWidth - 80, mainView.size.y - rightViewBottomPadding)
    rightView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionBottom)
    rightView.baseOffset = vec3(-40,rightViewBottomPadding, 0)

    elementTitleX = -rightView.size.x * 0.5 - 10
    elementControlX = rightView.size.x * 0.5

    tabButtonsView = View.new(tabView)
    tabButtonsView.size = tabView.size
    tabButtonsView.baseOffset = vec3(0,0, 4)

    uiSelectionLayout:createForView(tabButtonsView)
end

function modOptionsUI:initOptions()
    if modOptionsManager:hasOptions() then
        modOptionsUI:initModOptionsViews()
    else
        local noOptionsText = TextView.new(rightView)
        noOptionsText.font = Font(uiCommon.fontName, 20)
        noOptionsText.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
        noOptionsText.text = "No mods offer options at this time"
    end
end

local function updateSelection(newView, popOversView, newButton, titleText)
    if newView ~= currentView then
        uiSelectionLayout:setSelection(tabButtonsView, newButton)
        changeActiveSelectedControlView(nil)
        
        if currentView then
            currentView.hidden = true
            uiStandardButton:setSelected(currentButton, false)
        end
        if currentPopOversView then
            currentPopOversView.hidden = true
        end
        currentView = newView
        currentPopOversView = popOversView
        currentButton = newButton
        currentView.hidden = false
        uiStandardButton:setSelected(currentButton, true)
        currentTitle = modOptionsUI.name .. ": " .. titleText
        manageUI:changeTitle(currentTitle, modOptionsUI.icon) 

        if currentPopOversView then
            currentPopOversView.hidden = false
        end
    else
        changeActiveSelectedControlView(newView)
    end
end

local function getDisplayNameKey(configKey)
    return string.format("hsOptions_%s_displayName", configKey)
end

local function getLabelKey(optionKey)
    return string.format("hsOptions_%s_label", optionKey)
end

local function getTooltipKey(optionKey)
    return string.format("hsOptions_%s_tooltip", optionKey)
end

local function getDisplayName(modOptions)
    local configKey = modOptions:getStringValue("configKey")
    return modOptions:getStringOrNil("display_name"):asLocalizedString(getDisplayNameKey(configKey))
end

function modOptionsUI:initModOptionsViews()
    local allModOptions = modOptionsManager:getModOptions():valuesToTable()
    local allSortedOptions = {}

    for _, modOptions in allModOptions:ipairs() do 
        table.insert(allSortedOptions, {displayName = getDisplayName(modOptions), modOptions = modOptions })
    end
    
    table.sort(allSortedOptions, function(a,b) return a.displayName < b.displayName end)

    local lastButton = nil
    local firstButtonFunction = nil

    for _, sortedOption in ipairs(allSortedOptions) do
        local modOptions = sortedOption.modOptions
        local displayName = sortedOption.displayName

        local modOptionsView = View.new(rightView)
        modOptionsView.size = vec2(rightView.size.x, rightView.size.y)
        modOptionsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        modOptionsView.hidden = true
        uiSelectionLayout:createForView(modOptionsView)

        local controlsView = View.new(modOptionsView)
        controlsView.size = vec2(modOptionsView.size.x, modOptionsView.size.y - 20)
        controlsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        uiSelectionLayout:createForView(controlsView)

        local popOversView = View.new(modOptionsView)
        popOversView.size = vec2(controlsView.size.x, controlsView.size.y)
        popOversView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
        popOversView.hidden = true

        local function resetButtonClick()
            local values = modOptionsManager:resetModOptions(modOptions)
            uiSelectionLayout:removeAllViews(controlsView)            
            modOptionsView:removeSubview(controlsView)

            controlsView = View.new(modOptionsView)
            controlsView.size = vec2(modOptionsView.size.x, modOptionsView.size.y - 20)
            controlsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
            uiSelectionLayout:createForView(controlsView)            

            elementYOffset = 0
            viewsByEnableCondition = {}
            modOptionsUI:createControls(controlsView, popOversView, modOptions.configKey, modOptions:getTable("options"), values)
        end

        local resetButton = uiStandardButton:create(modOptionsView, vec2(tabWidth, 40))
        resetButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
        resetButton.baseOffset = vec3(0,0,0)
        uiStandardButton:setText(resetButton, "Reset to default")
        uiStandardButton:setClickFunction(resetButton, resetButtonClick)
        uiSelectionLayout:addView(modOptionsView, resetButton)

        local modOptionsButton = uiStandardButton:create(tabButtonsView, vec2(tabWidth, 40))        
        
        local function buttonClick()
            updateSelection(modOptionsView, popOversView, modOptionsButton, displayName)
        end

        if lastButton then 
            modOptionsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionBelow)
            modOptionsButton.relativeView = lastButton 
        else
            firstButtonFunction = buttonClick
            modOptionsButton.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
            modOptionsButton.baseOffset = vec3(0,-10, 0)
            uiSelectionLayout:setSelection(tabButtonsView, modOptionsButton)
        end

        uiStandardButton:setText(modOptionsButton, displayName)
        uiStandardButton:setClickFunction(modOptionsButton, buttonClick)
        uiSelectionLayout:addView(tabButtonsView, modOptionsButton)
        uiSelectionLayout:setItemSelectedFunction(modOptionsButton, buttonClick)

        lastButton = modOptionsButton
        currentButton = currentButton or modOptionsButton

        elementYOffset = 0
        local values = modOptionsManager:getModOptionsValues(modOptions.configKey)
        modOptionsUI:createControls(controlsView, popOversView, modOptions.configKey, modOptions:getTable("options"), values)
    end

    if firstButtonFunction then firstButtonFunction() end
end

local function addTitleHeader(parentView, title)
    if elementYOffset ~= 0 then
        elementYOffset = elementYOffset - 20
    end

    local textView = TextView.new(parentView)
    textView.font = Font(uiCommon.fontName, 20)
    textView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    textView.baseOffset = vec3(0,elementYOffset - 4, 0)
    textView.text = title

    elementYOffset = elementYOffset - yOffsetBetweenElements
    
    return textView
end

local function addLabel(parentView, text, labelYOffset)
    local textView = TextView.new(parentView)
    textView.font = Font(uiCommon.fontName, 16)
    textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    textView.baseOffset = vec3(elementTitleX, labelYOffset - 4, 0)
    textView.text = text
end

local function addToggleButton(parentView, toggleValue, changedFunction)
    local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
    toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
    uiStandardButton:setToggleState(toggleButton, toggleValue) 

    uiStandardButton:setClickFunction(toggleButton, function()
        changedFunction(uiStandardButton:getToggleState(toggleButton))
    end)
    
    elementYOffset = elementYOffset - yOffsetBetweenElements
    uiSelectionLayout:addView(parentView, toggleButton)

    return toggleButton, uiStandardButton
end

local function addSlider(parentView, min, max, value, changedFunction)
    local valueTextView = TextView.new(parentView)

    local options = {
        continuous = true,
        releasedFunction = changedFunction
    }

    local baseFunction = function(newValue) valueTextView.text = string.format("%d", newValue) end
    
    local sliderView = uiSlider:create(parentView, vec2(200, 20), min, max, value, options, baseFunction)
    sliderView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    sliderView.baseOffset = vec3(elementControlX, elementYOffset - 6, 0)
    uiSelectionLayout:addView(parentView, sliderView)

    valueTextView.font = Font(uiCommon.fontName, 16)
    valueTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    valueTextView.relativeView = sliderView
    valueTextView.baseOffset = vec3(2,0, 0)
    valueTextView.text = string.format("%d", value)

    elementYOffset = elementYOffset - yOffsetBetweenElements    

    return sliderView, uiSlider
end

local function addPopUpButton(parentView, popOversView, itemList, selectionFunction)

    local function popupHiddenFunction()
        uiSelectionLayout:setActiveSelectionLayoutView(activeSelectedControllableSubView)
    end

    local popUpButtonView = uiPopUpButton:create(parentView, popOversView, buttonSize, popUpMenuSize, popupHiddenFunction)
    popUpButtonView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    popUpButtonView.baseOffset = vec3(elementControlX + 4, elementYOffset + 6, 0)
    uiPopUpButton:setItems(popUpButtonView, itemList)
    uiPopUpButton:setSelection(popUpButtonView, 1)
    uiPopUpButton:setSelectionFunction(popUpButtonView, selectionFunction)

    elementYOffset = elementYOffset - yOffsetBetweenElements
    uiSelectionLayout:addView(parentView, popUpButtonView)

    return popUpButtonView, uiPopUpButton
end

local function createPopUpButton(parentView, popOversView, configKey, optionKey, option, values)
    local optionItemList = option:getTable("items"):notEmpty()
    local itemList = {}
    local selectedKeyIndex = 1

    local function getIconInfos(item)
        local icon = nil
        local materials = nil

        if item:hasKey("icon") then
            icon = item:getStringValueOrNil("icon") 

            -- test the icon
            model:modelIndexForName(icon)

            if item:hasKey("materials") then
                materials = item:getTable("materials"):selectPairs(function(k,v) return k, v:asTypeIndex(material.types, "material") end, hmtPairsMode.valuesOnly):clear()
            end
        end

        return icon, materials
    end

    for i, item in optionItemList:ipairs() do 
        local iconName, iconModelRemap = getIconInfos(item)

        itemList[i] = { 
            name = item:getString("text"):asLocalizedString(string.format("option_%d", i)), 
            iconObjectTypeIndex = item:getStringOrNil("object_type"):asTypeIndex(gameObject.types, "gameObject"), 
            iconModelName = iconName, 
            iconModelMaterialRemapTable = iconModelRemap,
            disabled = item:getBooleanValueOrNil("disabled")
        }

        if item:getStringValue("key") == values[optionKey] then
            selectedKeyIndex = i
        end
    end

    if option:getBooleanValueOrNil("sorted") then
        table.sort(itemList, function(a,b) return a.name < b.name end)
    end

    local function setNewValue(selectedIndex)
        modOptionsManager:setModOptionsValue(configKey, optionKey, optionItemList[selectedIndex]:getStringValue("key"))
    end

    local controlView, controlModule = addPopUpButton(parentView, popOversView, itemList, setNewValue)
    uiPopUpButton:setSelection(controlView, selectedKeyIndex)

    return controlView, controlModule
end

local function getSortedOptions(options)
    for key, option in pairs(options) do 
        option.key = key 
    end 

    local optionValues = options:valuesToTable()
    return optionValues:orderBy("order")
end
    
function modOptionsUI:createControls(parentView, popOversView, configKey, options, values)
    local sortedOptions = getSortedOptions(options)

    for _, option in sortedOptions:ipairs() do 
        local optionKey = option:getStringValue("key")
        local label = option:getStringOrNil("label"):asLocalizedString(getLabelKey(optionKey))
        local enableOn = option:getStringValueOrNil("enable_on")
        local disabled = enableOn and not (values[enableOn] or false)  
        
        local defaultTooltipLocaleKey = getTooltipKey(optionKey)
        local tooltip =  option:getStringOrNil("tooltip"):asLocalizedString(defaultTooltipLocaleKey)
        if tooltip == defaultTooltipLocaleKey then
            tooltip = nil
        end

        local controlView, controlModule = nil
        local labelYOffset = elementYOffset

        switch(option:getStringValue("type")) : caseof {
            ["group"] = function()
                addTitleHeader(parentView, label)
                modOptionsUI:createControls(parentView, popOversView, configKey, option:getTable("options"), values)
            end,

            ["boolean"] = function() 
                local function setNewValue(newValue)
                    modOptionsManager:setModOptionsValue(configKey, optionKey, newValue)
        
                    for _, enableFunction in ipairs(viewsByEnableCondition[optionKey] or {}) do 
                        enableFunction(newValue)
                    end
                end
                controlView, controlModule = addToggleButton(parentView, values[optionKey] or false, setNewValue) 
            end, 

            ["number"] = function() 
                local function setNewValue(newValue)
                    modOptionsManager:setModOptionsValue(configKey, optionKey, newValue)
                end
                controlView, controlModule = addSlider(parentView, option:getNumberValue("min"), option:getNumberValue("max"), values[optionKey] or 0, setNewValue) 
            end,

            ["choice"] = function() 
                controlView, controlModule = createPopUpButton(parentView, popOversView, configKey, optionKey, option, values)
            end,

            default = function(optionType) 
                log:schema("options", "Invalid option type: ", optionType) 
                os.exit(1) 
            end
        }

        if controlView then
            addLabel(parentView, label, labelYOffset)

            controlModule:setDisabled(controlView, disabled)

            if tooltip then
                uiToolTip:add(controlView, ViewPosition(MJPositionCenter, MJPositionAbove), tooltip, nil, vec3(0,8,2), nil, controlView, parentView)
            end

            if enableOn then
                viewsByEnableCondition[enableOn] = viewsByEnableCondition[enableOn] or {}
                table.insert(viewsByEnableCondition[enableOn], function(enabled) controlModule:setDisabled(controlView, not enabled) end)
            end
        end
    end
end

return modOptionsUI