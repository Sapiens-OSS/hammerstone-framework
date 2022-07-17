--- Hammerstone: uiBuilder.lua
--- This is an experimental module for building UI in sapiens.
--- It's designed to make building UIs easier

local uiBuilder = {}

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

-- Base
local model = mjrequire "common/model"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"

-- local function addToggleButton(parentView, toggleButtonTitle, toggleValue, changedFunction)
--     local toggleButton = uiStandardButton:create(parentView, vec2(26,26), uiStandardButton.types.toggle)
--     toggleButton.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
--     toggleButton.baseOffset = vec3(elementControlX, elementYOffset, 0)
--     uiStandardButton:setToggleState(toggleButton, toggleValue)
    
--     local textView = TextView.new(parentView)
--     textView.font = Font(uiCommon.fontName, 16)
--     textView.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionTop)
--     textView.baseOffset = vec3(elementTitleX,elementYOffset - 4, 0)
--     textView.text = toggleButtonTitle

--     uiStandardButton:setClickFunction(toggleButton, function()
--         changedFunction(uiStandardButton:getToggleState(toggleButton))
--     end)

--     elementYOffset = elementYOffset - yOffsetBetweenElements
    
--     uiSelectionLayout:addView(parentView, toggleButton)
--     return toggleButton
-- end


-- Util
local function splitByWhitespace (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function uiBuilder:new(baseView, name)
    -- Boilerplate for a class
    o = {
        name = name,
        views = {

        },
        baseView = baseView
    }
    setmetatable(o, self)
    self.__index = self

    return o
end

-- Views are dealt like java packages. See docs
function addView(name)
    local viewPath = splitByWhitespace(name)
    local currentView = self.views
    for i,view in viewPath do
        currentView = currentView[view] or {}
    end
    return self
end

function uiBuilder:getView(viewPath)
    local viewPath = splitByWhitespace(viewPath)
    local currentView = self.views
    for i,view in viewPath do
        currentView = currentView[view] or {}
    end
    return currentView
end


function setViewModel(viewPath, modelName)
    local view = self:getView(viewPath)
    view.model = model:modelIndexForName(modelName)
    return self
end

local function recursiveBuildModule(self, module)
    for v,k in module do
        if k.model ~= nil then
            k = ModelView.new(self.view)
        elseif false then
            -- Add more conditions here
        else
            recursiveBuildModule(self, k)
        end
    end
end

function uiBuilder:build()
    o = {
        view = View.new(self.baseView),
        name = self.name
    }
    recursiveBuildModule(o, self.views)

    return o;
end

return uiBuilder