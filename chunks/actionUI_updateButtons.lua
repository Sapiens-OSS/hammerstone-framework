local function getDisplayButtonIndex(buttonIndex)
    return ((buttonIndex - 1) % actionUI.wheelButtonsMaxCount) + 1
end

local function getButtonIndexFromDisplayIndex(displayIndex)
    return (actionUI.wheelPageIndex - 1) * actionUI.wheelButtonsMaxCount + displayIndex
end

local function getLastPageIndex()
    return math.ceil(actionUI.wheelButtonsCount / actionUI.wheelButtonsMaxCount)
end

local function getPlanButtonInfos(planInfo, objectOrVertIDs, buttonIndex)
    local buttonFunction = nil
    local cancelClickFunction = nil
    local optionsClickFunction = nil
    local changeAssignedSapienClickFunction = nil
    local prioritizeFunction = nil
    local fillConstructionTypeIndex = actionUI:getFillConstructionTypeIndex(planInfo)

    local function getToolTipText(planTypeIndexToUse, inProgress)
        local toolTipText = nil

        if planTypeIndexToUse == plan.types.manageSapien.index then
            toolTipText = locale:get("ui_action_manageSapien", {name = actionUI.baseObject.sharedState.name})
        elseif planTypeIndexToUse == plan.types.manageTribeRelations.index then
            local tribeName = nil
            if actionUI.baseObject.sharedState and actionUI.baseObject.sharedState.tribeID then
                local info = mainThreadDestination.destinationInfosByID[actionUI.baseObject.sharedState.tribeID]
                if info then
                    tribeName = info.name
                end
            end
            if tribeName then
                toolTipText = locale:get("plan_manageTribeRelationsWithTribeName", {tribeName = tribeName})
            else
                toolTipText = plan.types[planTypeIndexToUse].name
            end
        else
            if inProgress and plan.types[planTypeIndexToUse].inProgress then 
                toolTipText = plan.types[planTypeIndexToUse].inProgress
            else
                toolTipText = plan.types[planTypeIndexToUse].name
            end
                            
            local objectTypeIndex = planInfo.objectTypeIndex
            if objectTypeIndex then
                toolTipText = toolTipText .. " " .. gameObject.types[objectTypeIndex].plural
            elseif fillConstructionTypeIndex then
                toolTipText = toolTipText .. " " .. constructable.types[fillConstructionTypeIndex].name
            elseif planTypeIndexToUse == plan.types.clone.index then
                local constructableTypeIndexToUse = constructable:getConstructableTypeIndexForCloneOrRebuild(actionUI.selectedObjects[1])
                if constructableTypeIndexToUse then
                    local constructableType = constructable.types[constructableTypeIndexToUse]
                    local classificationType = constructable.classifications[constructableType.classification]

                    if not constructableType.plural then
                        mj:error("no plural for constructableType:", constructableType)
                    end
                                    
                    toolTipText = classificationType.actionName .. " " .. constructableType.plural
                end
            end
        end

        if planInfo.cancelIsElsewhere then
            toolTipText = toolTipText .. " " .. locale:get("misc_elsewhere")
        end

        return toolTipText
    end

    local toolTipText = getToolTipText(planInfo.planTypeIndex, false)              
    local cancelToolTipText = locale:get("ui_action_stop") .. " " .. getToolTipText(planInfo.planTypeIndex, true)

    if planInfo.hasNonQueuedAvailable then
        buttonFunction = 
            function(wasQuickSwipeAction)
                audio:playUISound(uiCommon.orderSoundFile)
                actionUI:wheelButtonClicked(planInfo, objectOrVertIDs)

                if actionUI:shouldAnimateOutOnClick(planInfo) then
                    actionUI:animateOutForOptionSelected()
                end

                if not tutorialUI:multiSelectComplete() then
                    local objectCount = #objectOrVertIDs
                    if objectCount > 1 then
                        tutorialUI:multiSelectWasIssued(objectCount)
                    end
                end
            end                      
    end

    local assignedSapienInfo = nil

    if planInfo.hasQueuedPlans then
        cancelClickFunction = function()
            audio:playUISound(uiCommon.cancelSoundFile)

            actionUI:wheelCancelButtonClicked(planInfo, objectOrVertIDs)
                            
            planInfo.hasQueuedPlans = false
            local wheel = actionUI.wheels[actionUI.currentWheelIndex]
            updateVisuals(wheel.segments[getDisplayButtonIndex(buttonIndex)], wheel.segments[getDisplayButtonIndex(buttonIndex)].userData) --todo this is untested, will only show up with lag, needs to be tested
        end

        if (not planInfo.cancelIsFollowerOrderQueue) and (planInfo.planTypeIndex ~= plan.types.wait.index) and (not planInfo.cancelIsElsewhere) then
            prioritizeFunction = function()
                actionUI:wheelPrioritizeButtonClicked(planInfo, objectOrVertIDs)
            end
        end

        if #objectOrVertIDs == 1 and (not planInfo.cancelIsElsewhere) and (planInfo.allQueuedPlansCanComplete) then
            local firstObjectInfo = nil
            if actionUI.baseVert then
                firstObjectInfo = actionUI.baseVert.planObjectInfo
            else
                firstObjectInfo = actionUI.selectedObjects[1]
            end
            if firstObjectInfo and firstObjectInfo.sharedState then
                local assignedSapienIDs = firstObjectInfo.sharedState.assignedSapienIDs
                if assignedSapienIDs then
                    for assignedSapienID,planTypeIndexOrTrue in pairs(assignedSapienIDs) do
                        local sapienInfo = playerSapiens:getInfo(assignedSapienID)
                        if sapienInfo then
                            local orderQueue = sapienInfo.sharedState.orderQueue
                            if orderQueue and orderQueue[1] then
                                local orderContext = orderQueue[1].context
                                if orderContext and orderContext.planObjectID == firstObjectInfo.uniqueID and 
                                orderContext.planTypeIndex == planInfo.planTypeIndex and 
                            ((not planInfo.objectTypeIndex) or (not orderContext.objectTypeIndex) or orderContext.objectTypeIndex == planInfo.objectTypeIndex) then
                                    assignedSapienInfo = {
                                        uniqueID = assignedSapienID,
                                        objectTypeIndex = gameObject.types.sapien.index,
                                        sharedState = sapienInfo.sharedState,
                                    }
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if not planInfo.sapienAssignButtonShouldBeHidden then
                changeAssignedSapienClickFunction = function()
                    actionUI:animateOutForOptionSelected()
                    changeAssignedSapienUI:show(firstObjectInfo, planInfo)
                end
            end
        end
    end

    if planInfo.allowsObjectTypeSelection then
        optionsClickFunction = function()
            actionUI:wheelOptionsButtonClicked(planInfo)
        end
    end

    buttonInfos[buttonIndex] = {
        toolTipText = toolTipText,
        cancelToolTipText = cancelToolTipText,
        clickFunction = buttonFunction,
        cancelClickFunction = cancelClickFunction,
        optionsClickFunction = optionsClickFunction,
        changeAssignedSapienClickFunction = changeAssignedSapienClickFunction,
        prioritizeFunction = prioritizeFunction,
        planTypeIndex = planInfo.planTypeIndex,
        objectTypeIndex = planInfo.objectTypeIndex,
        researchTypeIndex = planInfo.researchTypeIndex,
        fillConstructionTypeIndex = fillConstructionTypeIndex,
        planInfo = planInfo,
        disabled = not planInfo.hasNonQueuedAvailable,
        assignedSapienInfo = assignedSapienInfo,
    }
end

local function updateButtons(showForPageChange)
    local buttonCount = actionUI.wheelButtonsCount

    if not showForPageChange then
        buttonInfos = {}
        buttonCount = 0

        if actionUI.selectedObjects or actionUI.selectedVertInfos then

            local availablePlans = nil
            local objectOrVertIDs = {}
            if actionUI.selectedObjects then
                availablePlans = planHelper:availablePlansForObjectInfos(actionUI.selectedObjects, world.tribeID)
                for i,objectInfo in ipairs(actionUI.selectedObjects) do
                    objectOrVertIDs[i] = objectInfo.uniqueID
                end
            else
                availablePlans = planHelper:availablePlansForVertInfos(actionUI.selectedVertInfos, world.tribeID)
                for i,vertInfo in ipairs(actionUI.selectedVertInfos) do
                    objectOrVertIDs[i] = vertInfo.uniqueID
                end
            end

            local availabilityRequest = {
                objectOrVertIDs = objectOrVertIDs,
                plans = {},
            }

            if availablePlans then            
                for i, planInfo in ipairs(availablePlans) do
                    buttonCount = buttonCount + 1
                    getPlanButtonInfos(planInfo, objectOrVertIDs, buttonCount)  
                    
                    if planInfo.hasNonQueuedAvailable then
                        if plan.types[planInfo.planTypeIndex].checkCanCompleteForRadialUI then
                            table.insert(availabilityRequest.plans, actionUI:getAvailibityRequestPlan(planInfo, objectOrVertIDs))
                        end
                    end
                end
            end

            planAvailibilityRequestCounter = planAvailibilityRequestCounter + 1
            local thisRequestCounter = planAvailibilityRequestCounter
            logicInterface:callServerFunction("checkPlanAvailability", availabilityRequest, function(result)
                if thisRequestCounter == planAvailibilityRequestCounter then
                    updatePlanAvailibility(result)
                end
            end)

            -- TODO : Insert registered wheel elements here
                
        else
            mj:error("No selectedVertInfo or actionUI.selectedObjects")
            return false
        end
    end

    local newWheelIndex = actionUI.currentWheelIndex
    local newInnerWheelIndex = actionUI.currentInnerWheelIndex

    if not showForPageChange then
        actionUI.wheelButtonsCount = buttonCount
        actionUI.wheelPageIndex = 1

        if actionUI.wheelButtonsCount > actionUI.wheelButtonsMaxCount then
            actionUI.innerWheelHasPages = true
            newInnerWheelIndex = 4
        else
            actionUI.innerWheelHasPages = false
            newInnerWheelIndex = 2
        end
    end

    if actionUI.wheelButtonsCount > actionUI.wheelButtonsMaxCount then
        actionUI.innerWheels[4].segments[1].userData.disabled = actionUI.wheelPageIndex == getLastPageIndex()
        actionUI.innerWheels[4].segments[3].userData.disabled = actionUI.wheelPageIndex == 1
    end

    if actionUI.currentInnerWheelIndex ~= newInnerWheelIndex then
        if actionUI.currentInnerWheelIndex then
            actionUI.innerWheels[actionUI.currentInnerWheelIndex].view.hidden = true
        end

        actionUI.currentInnerWheelIndex = newInnerWheelIndex
        actionUI.innerWheels[actionUI.currentInnerWheelIndex].view.hidden = false
    end

    if actionUI.currentInnerWheelIndex == 4 then
        if actionUI.wheelPageIndex == getLastPageIndex() then
            newWheelIndex = getDisplayButtonIndex(actionUI.wheelButtonsCount)
        else
            newWheelIndex = actionUI.wheelButtonsMaxCount
        end
    else
        newWheelIndex = actionUI.wheelButtonsCount
    end

    if actionUI.currentWheelIndex ~= newWheelIndex then
        if buttonCount < 1 then
            mj:error("No buttons to display")
            error()
            return false
        end

        if actionUI.currentWheelIndex then
            actionUI.wheels[actionUI.currentWheelIndex].view.hidden = true
        end

        actionUI.currentWheelIndex = newWheelIndex
        actionUI.wheels[actionUI.currentWheelIndex].view.hidden = false
    end

    local wheel = actionUI.wheels[actionUI.currentWheelIndex]
    for segmentIndex = 1, actionUI.currentWheelIndex do
       local segment = wheel.segments[segmentIndex]
       local segmentTable = segment.userData
       local buttonIndex = getButtonIndexFromDisplayIndex(segmentIndex)

       segmentTable.clickFunction = buttonInfos[buttonIndex].clickFunction
       segmentTable.toolTipText = buttonInfos[buttonIndex].toolTipText
       segmentTable.cancelToolTipText = buttonInfos[buttonIndex].cancelToolTipText
       segmentTable.planTypeIndex = buttonInfos[buttonIndex].planTypeIndex
       segmentTable.objectTypeIndex = buttonInfos[buttonIndex].objectTypeIndex
       segmentTable.researchTypeIndex = buttonInfos[buttonIndex].researchTypeIndex
       segmentTable.fillConstructionTypeIndex = buttonInfos[buttonIndex].fillConstructionTypeIndex
       segmentTable.planInfo = buttonInfos[buttonIndex].planInfo
       segmentTable.disabled = buttonInfos[buttonIndex].disabled
       segmentTable.assignedSapienInfo = buttonInfos[buttonIndex].assignedSapienInfo
       segmentTable.cancelClickFunction = buttonInfos[buttonIndex].cancelClickFunction
       segmentTable.optionsClickFunction = buttonInfos[buttonIndex].optionsClickFunction
       segmentTable.changeAssignedSapienClickFunction = buttonInfos[buttonIndex].changeAssignedSapienClickFunction
       segmentTable.prioritizeFunction = buttonInfos[buttonIndex].prioritizeFunction
       segmentTable.availibilityResult = nil
       uiStandardButton:setClickFunction(segmentTable.cancelButton, buttonInfos[buttonIndex].cancelClickFunction)
       uiStandardButton:setClickFunction(segmentTable.optionsButton, buttonInfos[buttonIndex].optionsClickFunction)
       uiStandardButton:setClickFunction(segmentTable.changeAssignedSapienButton, buttonInfos[buttonIndex].changeAssignedSapienClickFunction)
       uiStandardButton:setClickFunction(segmentTable.prioritizeButton, buttonInfos[buttonIndex].prioritizeFunction)
       
       updateVisuals(segment, segmentTable)
    end

    local innerWheel = actionUI.innerWheels[actionUI.currentInnerWheelIndex]
    for innerSegmentIndex = 1, actionUI.currentInnerWheelIndex do 
        local innerSegment = innerWheel.segments[innerSegmentIndex]
        local innerSegmentTable = innerSegment.userData

        updateInnerSegmentVisuals(innerSegment, innerSegmentTable)
    end

    return true
end

-- used to display the previous or next page of buttons in the wheel
function actionUI:displayWheelPage(pageOffset)
	actionUI.wheelPageIndex = actionUI.wheelPageIndex + pageOffset	
	updateButtons(true)
end

function actionUI:wheelOptionsButtonClicked(planInfo)
    inspectUI:showInspectPanelForActionUIOptionsButton(planInfo.planTypeIndex)
end

function actionUI:getFillConstructionTypeIndex(planInfo)
    local fillConstructionTypeIndex = nil

    if planInfo.planTypeIndex == plan.types.fill.index then
        if planInfo.hasQueuedPlans then
            if actionUI.baseVert and actionUI.baseVert.planObjectInfo then
                local planStates = actionUI.baseVert.planObjectInfo.sharedState.planStates
                if planStates and planStates[world.tribeID] then
                    for j, planState in ipairs(planStates[world.tribeID]) do
                        if planState.planTypeIndex == planTypeIndex then
                            fillConstructionTypeIndex = planState.constructableTypeIndex
                            break
                        end
                    end
                end
            end
        end

        if not fillConstructionTypeIndex then
            fillConstructionTypeIndex = constructableUIHelper:getTerrainFillConstructableTypeIndex()
        end
    end

    return fillConstructionTypeIndex
end

function actionUI:getAvailibityRequestPlan(planInfo, objectOrVertIDs)
    local addInfo = {
        planTypeIndex = planInfo.planTypeIndex,
        objectTypeIndex = planInfo.objectTypeIndex,
        researchTypeIndex = planInfo.researchTypeIndex,
        discoveryCraftableTypeIndex = planInfo.discoveryCraftableTypeIndex,
    }

    if planTypeIndex == plan.types.fill.index then
        addInfo.constructableTypeIndex = actionUI:getFillConstructionTypeIndex(planInfo)
        addInfo.restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(addInfo.constructableTypeIndex, false)
        addInfo.restrictedToolObjectTypes = world:getConstructableRestrictedObjectTypes(addInfo.constructableTypeIndex, true)
    end

    return addInfo
end

function actionUI:wheelPrioritizeButtonClicked(planInfo, objectOrVertIDs)
    local planTypeIndexToUse = planInfo.planTypeIndex

    if planTypeIndexToUse == plan.types.constructWith.index then
        planTypeIndexToUse = plan.types.craft.index
    end

    if planInfo.hasManuallyPrioritizedQueuedPlan then
        logicInterface:callServerFunction("deprioritizePlans", {
            objectOrVertIDs = objectOrVertIDs,
            planTypeIndex = planTypeIndexToUse,
            objectTypeIndex = planInfo.objectTypeIndex,
            researchTypeIndex = planInfo.researchTypeIndex,
            discoveryCraftableTypeIndex = planInfo.discoveryCraftableTypeIndex,
        })
    else
        logicInterface:callServerFunction("prioritizePlans", {
            objectOrVertIDs = objectOrVertIDs,
            planTypeIndex = planTypeIndexToUse,
            objectTypeIndex = planInfo.objectTypeIndex,
            researchTypeIndex = planInfo.researchTypeIndex,
            discoveryCraftableTypeIndex = planInfo.discoveryCraftableTypeIndex,
        })

        tutorialUI:prioritizationWasIssued()
    end
end

function actionUI:wheelCancelButtonClicked(planInfo, objectOrVertIDs)
    if planInfo.cancelIsFollowerOrderQueue then
        logicInterface:callServerFunction("cancelSapienOrders", {
            sapienIDs = objectOrVertIDs,
            planTypeIndex = planInfo.planTypeIndex,
        })
    elseif planInfo.planTypeIndex == plan.types.wait.index then
        logicInterface:callServerFunction("cancelWaitOrder", {
            sapienIDs = objectOrVertIDs,
        })
    else
        local planTypeIndexToUseForCancel = planInfo.planTypeIndex

        if planTypeIndexToUseForCancel == plan.types.constructWith.index then
            planTypeIndexToUseForCancel = plan.types.craft.index
        end
        logicInterface:callServerFunction("cancelPlans", {
            planTypeIndex = planTypeIndexToUseForCancel,
            objectTypeIndex = planInfo.objectTypeIndex,
            researchTypeIndex = planInfo.researchTypeIndex,
            discoveryCraftableTypeIndex = planInfo.discoveryCraftableTypeIndex,
            objectOrVertIDs = objectOrVertIDs,
        })
    end
end

function actionUI:shouldAnimateOutOnClick(planInfo)
    if planInfo.planTypeIndex == plan.types.craft.index or 
        planInfo.planTypeIndex == plan.types.manageStorage.index or 
        planInfo.planTypeIndex == plan.types.manageSapien.index or 
        planInfo.planTypeIndex == plan.types.constructWith.index or 
        planInfo.planTypeIndex == plan.types.rebuild.index then
        return false
    end

    return true
end

function actionUI:getAddPlansInfos(planInfo, objectOrVertIDs)
    local addInfo = {
        planTypeIndex = planInfo.planTypeIndex,
        objectTypeIndex = planInfo.objectTypeIndex,
        researchTypeIndex = planInfo.researchTypeIndex,
        discoveryCraftableTypeIndex = planInfo.discoveryCraftableTypeIndex,
        objectOrVertIDs = objectOrVertIDs,
    }

    if actionUI.baseVert then
        addInfo.baseVertID = actionUI.baseVert.uniqueID
    end

    if planInfo.planTypeIndex == plan.types.fill.index then
        addInfo.constructableTypeIndex = actionUI:getFillConstructionTypeIndex(planInfo)
        addInfo.restrictedResourceObjectTypes = world:getConstructableRestrictedObjectTypes(addInfo.constructableTypeIndex, false)
        addInfo.restrictedToolObjectTypes = world:getConstructableRestrictedObjectTypes(addInfo.constructableTypeIndex, true)
    end

    if planInfo.planTypeIndex == plan.types.clear.index and actionUI.selectedVertInfos then
                                    
        if not tutorialUI:clearPlanComplete() then
            local function checkForHayOrGrass()
                for j,vertInfo in ipairs(actionUI.selectedVertInfos) do
                    local variations = vertInfo.variations
                    if variations then
                        for terrainVariationTypeIndex,v in pairs(variations) do
                            local terrainVariationType = terrainTypesModule.variations[terrainVariationTypeIndex]
                            if terrainVariationType.canBeCleared and terrainVariationType.clearOutputs then
                                for k,outputInfo in ipairs(terrainVariationType.clearOutputs) do
                                    if outputInfo.objectKeyName == "grass" or outputInfo.objectKeyName == "hay" then
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
                return false
            end
            if checkForHayOrGrass() then
                tutorialUI:clearPlanWasIssued()
            end
        end
    end

    return addInfo
end

function actionUI:wheelButtonClicked(planInfo, objectOrVertIDs)
    if planInfo.researchTypeIndex then
        world:setHasQueuedResearchPlan(true)
    end
                            
    if planInfo.planTypeIndex == plan.types.moveTo.index then
        sapienMoveUI:show(objectOrVertIDs)
    elseif planInfo.planTypeIndex == plan.types.haulObject.index then
        objectMoveUI:show(objectOrVertIDs, inspectUI.baseObjectOrVertInfo)
    elseif planInfo.planTypeIndex == plan.types.stop.index then
        logicInterface:callServerFunction("cancelSapienOrders", {
            sapienIDs = objectOrVertIDs,
        })
    elseif planInfo.planTypeIndex == plan.types.wait.index then
        logicInterface:callServerFunction("addWaitOrder", {
            sapienIDs = objectOrVertIDs,
        })
    elseif planInfo.planTypeIndex == plan.types.clone.index then
        if inspectUI.baseObjectOrVertInfo then
            buildModeInteractUI:showForDuplication(inspectUI.baseObjectOrVertInfo)
        end
    elseif planInfo.planTypeIndex == plan.types.craft.index or 
        planInfo.planTypeIndex == plan.types.manageStorage.index or 
        planInfo.planTypeIndex == plan.types.manageSapien.index or 
        planInfo.planTypeIndex == plan.types.constructWith.index or 
        planInfo.planTypeIndex == plan.types.rebuild.index then
        inspectUI:showInspectPanelForActionUISelectedPlanType(planInfo.planTypeIndex)
    elseif planInfo.planTypeIndex == plan.types.allowUse.index then
        logicInterface:callServerFunction("changeAllowItemUse", {
            objectIDs = objectOrVertIDs,
            allowItemUse = true,
        })
    elseif planInfo.planTypeIndex == plan.types.manageTribeRelations.index then
        tribeRelationsUI:show(mainThreadDestination.destinationInfosByID[actionUI.baseObject.sharedState.tribeID], nil, nil, nil, false)
    elseif planInfo.planTypeIndex == plan.types.startRoute.index then
        logicInterface:createLogisticsRoute(objectOrVertIDs[1], function(uiRouteInfo)
            if uiRouteInfo then
                gameUI:hideAllUI(false)
                storageLogisticsDestinationsUI:show(uiRouteInfo)
            end
        end)
    else
        logicInterface:callServerFunction("addPlans", actionUI:getAddPlansInfos(planInfo, objectOrVertIDs))
    end
end
