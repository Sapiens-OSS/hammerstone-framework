actionUI.wheelButtonsCount = nil
actionUI.wheelButtonsMaxCount = 6
actionUI.innerWheels = {}
actionUI.currentInnerWheelIndex = nil
actionUI.wheelPageIndex = 1
actionUI.innerWheelHasPages = false

actionUI.innerSegmentsInfos = {
    [2] = {
        [1] = {
            modelName = "ui_radialMenu_centerLeft", 
            controllerShortcut = "menuLeft", 
            controllerShortcutKeyImageOffset = vec3(4, 2, 0),
            iconName = "icon_multiSelect",
            iconOffset = vec2(-actionUI.innerSegmentIconCenterDistance, 0),
            clickFunction = function() actionUI:multiselectShortcut() end, 
            tooltipInfos = {
                offset = vec3(-actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_selectMore"),
            }
        }, 
        [2] = {
            modelName = "ui_radialMenu_centerRight",
            controllerShortcut = "menuRight",
            controllerShortcutKeyImageOffset = vec3(-4, 2, 0),
            iconName = "icon_inspect",
            iconOffset = vec2(actionUI.innerSegmentIconCenterDistance, 0), 
            clickFunction = function() actionUI:zoomShortcut() end,
            tooltipInfos = {
                offset = vec3(actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_zoom"),
            }
        },
    },
    [4] = {
        [1] = {
            modelName = "ui_radialMenu_inner_4_top",
            controllerShortcut = "menuRightBumper",
            controllerShortcutKeyImageOffset = vec3(0, 0, 0),
            iconName = "icon_upArrow",
            iconOffset = vec2(0, actionUI.innerSegmentIconCenterDistance),
            clickFunction = 
            function()
                actionUI:displayWheelPage(1)
            end, 
            tooltipInfos = {
                offset = vec3(actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_next"),
            }
        },
        [2] = {
            modelName = "ui_radialMenu_inner_4_right",
            controllerShortcut = "menuRight",
            controllerShortcutKeyImageOffset = vec3(-4, 2, 0),
            iconName = "icon_inspect",
            iconOffset = vec2(actionUI.innerSegmentIconCenterDistance, 0), 
            clickFunction = function() actionUI:zoomShortcut() end,
            tooltipInfos = {
                offset = vec3(actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_zoom"),
            }
        },
        [3] = {
            modelName = "ui_radialMenu_inner_4_bottom",
            controllerShortcut = "menuLeftBumper",
            controllerShortcutKeyImageOffset = vec3(0, 0, 0),
            iconName = "icon_downArrow",
            iconOffset = vec2(0, -actionUI.innerSegmentIconCenterDistance), 
            clickFunction = 
            function()
                actionUI:displayWheelPage(-1)
            end,
            tooltipInfos = {
                offset = vec3(actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_back"),
            }
        },
        [4] = {
            modelName = "ui_radialMenu_inner_4_left", 
            controllerShortcut = "menuLeft", 
            controllerShortcutKeyImageOffset = vec3(4, 2, 0),
            iconName = "icon_multiSelect",
            iconOffset = vec2(-actionUI.innerSegmentIconCenterDistance, 0),
            clickFunction = function() actionUI:multiselectShortcut() end, 
            tooltipInfos = {
                offset = vec3(-actionUI.innerSegmentIconCenterDistance,30.0,8.0),
                relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter),
                text = locale:get("ui_action_selectMore"),
            }
        }
    }
}