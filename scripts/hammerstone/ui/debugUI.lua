local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local vec4 = mjm.vec4

local clientGameSettings = mjrequire "mainThread/clientGameSettings"
local gameConstants = mjrequire "common/gameConstants"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local keyMapping = mjrequire "mainThread/keyMapping"


--local lightManager = mjrequire "mainThread/lightManager"

local debugUI = {
    logs = {}
}

local mainView = nil

function debugUI:load(gameUI, controller)
    mainView = ColorView.new(gameUI.view)
    mainView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
    mainView.size = vec2(gameUI.view.size.x * 0.25,1080)
    mainView.color = vec4(0.0,0.0,0.0,0.7)

    
    local consoleFont = Font(uiCommon.consoleFontName, 12)

    local logView = TextView.new(mainView)
    logView.font = consoleFont
    logView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    logView.baseOffset = vec3(-4,-4, 0)
    
    mainView.update = function(dt)
        local string = table.concat(debugUI.logs, "\n")
        logView.text = string
    end

    local function updateHiddenStatus()
        if clientGameSettings.values.renderLog and gameConstants.showDebugMenu then
            mainView.hidden = false
        else
            mainView.hidden = true
        end
    end

    updateHiddenStatus()

    clientGameSettings:addObserver("renderLog", updateHiddenStatus)


end

function debugUI:log(str)
    debugUI.logs[#(debugUI.logs) + 1] = str
end

function debugUI:show()
    if mainView then
        if clientGameSettings.values.renderLog and gameConstants.showDebugMenu then
            mainView.hidden = false
        end
    end
end
function debugUI:hide()
    if mainView then
        mainView.hidden = true
    end
end

return debugUI