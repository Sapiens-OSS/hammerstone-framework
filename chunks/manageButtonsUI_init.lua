function manageButtonsUI:init(gameUI, manageUI_, hubUI_, world)
    manageUI = manageUI_
    hubUI = hubUI_

    local menuButtonSize = manageButtonsUI.menuButtonSize
    local menuButtonPaddingRatio = manageButtonsUI.menuButtonPaddingRatio

    local menuButtonPadding = menuButtonSize * menuButtonPaddingRatio
    
    local menuButtonsEnabled = 0
    for modeIndex in ipairs(manageUI.modeTypes) do
        if not manageUI.modeInfos[modeIndex].disabled then
            menuButtonsEnabled  = menuButtonsEnabled + 1
        end
    end


    local menuButtonsView = View.new(gameUI.view)
    manageButtonsUI.menuButtonsView = menuButtonsView
    menuButtonsView.hidden = true
    menuButtonsView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    menuButtonsView.size = vec2(
        menuButtonSize * menuButtonsEnabled + menuButtonPadding * (menuButtonsEnabled - 1),
        menuButtonSize)
    menuButtonsView.baseOffset = vec3(0.0, -40.0, 0.0)

    local toolTipOffset = manageButtonsUI.toolTipOffset

    manageButtonsUI.orderedModes = {}

    local lastButton = nil
    for modeIndex in ipairs(manageUI.modeTypes) do
        mj:log("manageButtonsUI: modeIndex=", modeIndex, " title=", manageUI.modeInfos[modeIndex].title)
        table.insert(manageButtonsUI.orderedModes, modeIndex)

        if manageUI.modeInfos[modeIndex].disabled then
            mj:log("manageButton at modeIndex=", modeIndex, " title=", manageUI.modeInfos[modeIndex].title, " is disabled, skipping button creation")
            goto continue
        end



        local horizontalPos = modeIndex == 1 and MJPositionInnerLeft or MJPositionOuterRight

        local button = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize, menuButtonSize),
            uiStandardButton.types.markerLike)
        button.relativePosition = ViewPosition(horizontalPos, MJPositionCenter)
        uiStandardButton:setIconModel(button, manageUI.modeInfos[modeIndex].icon)
        uiToolTip:add(button.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow),
            manageUI.modeInfos[modeIndex].title, nil, toolTipOffset, nil, button)

        if lastButton then
            button.relativeView = lastButton
        end

        if manageUI.modeInfos[modeIndex].keyboardShortcut then
            uiToolTip:addKeyboardShortcut(button.userData.backgroundView, "game",
                manageUI.modeInfos[modeIndex].keyboardShortcut, nil, nil)
        end

        uiStandardButton:setClickFunction(button, function()
            manageUI:show(modeIndex)
            if manageUI.modeInfos[modeIndex].onClick then
                manageUI.modeInfos[modeIndex].onClick()
            end
        end)

        manageButtonsUI.menuButtonsByManageUIModeType[modeIndex] = button
        lastButton = button
        ::continue::
    end

    menuButtonsView.hiddenStateChanged = function(newHiddenState)
        if newHiddenState then
            for modeIndex, button in pairs(manageButtonsUI.menuButtonsByManageUIModeType) do
                uiStandardButton:resetAnimationState(button)
            end
        end
    end


    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuTabLeft", function(isDown)
        if isDown and not menuButtonsView.hidden then
            if manageUI:hidden() then
                manageUI:show(manageUI.modeTypes.build)
            else
                local currentModeIndex = manageUI:getCurrentModeIndex()
                if currentModeIndex then
                    if currentModeIndex > 1 then
                        manageUI:show(currentModeIndex - 1)
                    else
                        manageUI:show(currentModeIndex)
                    end
                else
                    manageUI:show(1)
                end
            end
            return true
        end
    end)

    eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, true, "menuTabRight", function(isDown)
        if isDown and not menuButtonsView.hidden then
            if manageUI:hidden() then
                manageUI:show(manageUI.modeTypes.tribe)
            else
                local currentModeIndex = manageUI:getCurrentModeIndex()
                if currentModeIndex then
                    if currentModeIndex < #manageButtonsUI.orderedModes then
                        manageUI:show(currentModeIndex + 1)
                    else
                        manageUI:show(currentModeIndex)
                    end
                else
                    manageUI:show(#manageButtonsUI.orderedModes)
                end
            end
            return true
        end
    end)
end
