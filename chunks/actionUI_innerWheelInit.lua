for innerWheelIndex, innerSegmentInfos in pairs(actionUI.innerSegmentsInfos) do
	actionUI.innerWheels[innerWheelIndex] = {}
	actionUI.innerWheels[innerWheelIndex].view = View.new(actionUI.backgroundView)
	actionUI.innerWheels[innerWheelIndex].view.hidden = true
	actionUI.innerWheels[innerWheelIndex].segments = {}
	actionUI.innerWheels[innerWheelIndex].selectedInnerSegment = nil

	for i = 1, innerWheelIndex do
		actionUI.innerWheels[innerWheelIndex].segments[i] = addInnerSegment(actionUI.innerWheels[innerWheelIndex].view, innerSegmentInfos[i])
	end
end

eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, false, "menuLeftBumper", function(pos)
        if (not actionUI.mainView.hidden) and ((not animatingInOrOut) or animatingIn) then
            if isDown and actionUI.innerWheelHasPages and actionUI.wheelPageIndex > 1 then
                actionUI:displayWheelPage(-1)
                return true
            end
        end
        return false
    end)

eventManager:addControllerCallback(eventManager.controllerSetIndexMenu, false, "menuRightBumper", function(pos)
        if (not actionUI.mainView.hidden) and ((not animatingInOrOut) or animatingIn) then
            if isDown and actionUI.innerWheelHasPages and actionUI.wheelPageIndex ~= getLastPageIndex() then
                actionUI:displayWheelPage(1)
                return true
            end
        end
        return false
    end)