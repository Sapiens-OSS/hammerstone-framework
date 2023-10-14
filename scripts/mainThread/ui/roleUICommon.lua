--- Hammerstone: roleUICommon.lua.
--- @Author Witchy

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local shadow = mjrequire "hammerstone/utils/shadow"

-- Sapiens
local skillModule = mjrequire "common/skill"

local roleUICommon = {}

local nodes = hmt{}
local edges = hmt{}
local dummyIndex = -1
local maxLayer = nil

-- Dave put some hacks to show the lines
-- However, they kinda fuck up the flow of the graph
local function undoHacks(base)
    for _, skill in ipairs(base.skillUIColumns) do 
        switch(skill.skillTypeIndex) : caseof {
            [skillModule.types.fireLighting.index] = function()
                skillModule.requiredSkillTypes[1] = skillModule.types.gathering.index
            end, 

            [skillModule.types.basicHunting.index] = function()
                skillModule.requiredSkillTypes = { skillModule.types.basicBuilding.index, skillModule.types.researching.index }
            end,

            [skillModule.types.rockKnapping.index] = function()
                skillModule.requiredSkillTypes = { skillModule.types.researching.index, skillModule.types.diplomacy.index }
            end, 

            [skillModule.types.thatchBuilding.index] = function()
                skillModule.requiredSkillTypes[1] = skillModule.types.diplomacy.index
            end
        }
    end
end

-- combines the vanilla and modded skills into a list of nodes and edges
local function flattenLists(base)
    for _, column in ipairs(base.skillUIColumns) do 
        for _, row in ipairs(column) do 
            if row.skillTypeIndex then
                nodes[row.skillTypeIndex] = hmt{ index = row.skillTypeIndex, edges = hmt{}}
            end

            for _, requiredSkill in ipairs(row.requiredSkillTypes or {}) do 
                local newEdge = hmt{ from = requiredSkill, to = row.skillTypeIndex }
                edges:insert(newEdge)
            end
        end
    end
    
    for _, moddedSkill in ipairs(skillModule.moddedSkills) do 
        nodes[moddedSkill.index] = hmt{ index = moddedSkill.index, edges = hmt{}}

        for _, parent in ipairs(moddedSkill.parents or {}) do 
            local newEdge = edges:firstOrNil(function(e) return e.from == parent and e.to == moddedSkill.index end)

            if not newEdge then 
                newEdge = hmt{ from = parent, to = moddedSkill.index } 
                edges:insert(newEdge)
            end
        end
    end
end

-- assign layers (columns) according to dependencies
local function assignLayers()
    local layerIndex = 0 

    while nodes:firstOrNil(function(e) return not e.ordered end) do 
        layerIndex = layerIndex + 1
        local foundOne = false
        
        for skillTypeIndex, node in pairs(nodes) do
            if not node.ordered then 
                local canOrder = true

                for _, parent in ipairs(edges:where(function(e) return e.to == skillTypeIndex end)) do 
                    if not nodes[parent.from].ordered then
                        canOrder = false
                        break
                    end
                end

                if canOrder then
                    foundOne = true
                    node.layer = layerIndex
                end
            end
        end

        if not foundOne then
            log:schema("ddapi", "  ERROR: Could not sort skills. This is likely due to a circular dependance between parents and children.")
            os.exit(1)
        end
    end
end

local function getParentNodes(skillTypeIndex)
    local parentNodes = hmt{}

    for _, edge in ipairs(edges:where(function(e) return e.to == skillTypeIndex end)) do 
        local parentNode = nodes[edge.from]
        parentNodes:insert(parentNode)
    end

    return parentNodes
end

local function getChildNodes(skillTypeIndex)
    local childNodes = hmt{}

    for _, edge in ipairs(edges:where(function(e) return e.from == skillTypeIndex end)) do 
        local childNode = nodes[edge.to]
        childNodes:insert(childNode)
    end

    return childNodes
end

-- Handles cases like flax spinning which doesn't have a parent but its child is not on layer 2
local function handleFloatingNodes()
    for _, leafNode in pairs(nodes:wherePairs(function (k,v) return v.layer == 1 end)) do
        local minChildLayer = getChildNodes(leafNode.index):min(function(e) return e.layer end)

        local function push(n)
            n.layer = n.layer + 1

            for _, childNode in ipairs(getChildNodes(n.index)) do 
                push(childNode)
            end
        end

        if minChildLayer > 2 and minChildLayer ~= math.huge then
            push(leafNode)
            leafNode.layer = minChildLayer
        end
    end
end

-- create dummy nodes when the layer difference between a parent and child is greater than one
-- ex:  [A] ----------------> [B]
--      [A] ---> [Dummy] ---> [B]
local function createDummies()
    local edge = edges:firstOrNil(function(e) return nodes[e.to].layer - nodes[e.from].layer > 1 end)

    while edge do 
        local toNode = nodes[edge.to]

        toNode.edges:remove(toNode.edges:indexOf(edge))

        local dummyNode = { index = dummyIndex, edges = {}}
        dummyIndex = dummyIndex - 1
        nodes:insert(dummyNode)
        
        edge.to = dummyNode.index

        local dummyEdge = { from = dummyNode.index, to = toNode.index }
        edges:insert(dummyEdge)

        toNode.edges:insert(dummyEdge)

        edge = edges:firstOrNil(function(e) return nodes[e.to].layer - nodes[e.from].layer > 1 end)
    end
end

local function assignInitialPos()
    maxLayer = nodes:max(function(e) return e.layer end)

    for i = 1, maxLayer do 
        local layerNodes = nodes:where(function(e) return e.layer == i end)
        for pos, node in ipairs(layerNodes) do 
            node.pos = pos
        end
    end
end

local function median(leftToRight)
end        

function roleUICommon:createDerivedTreeDependencies(super)
    -- If we have modded skills, we need to redraw the tree graph to compensate for new relationships
    if next(skillModule.moddedSkills) then
        undoHacks()
        flattenLists()
        assignLayers()
        handleFloatingNodes()
        createDummies()
        assignInitialPos()
              
    end

    super(self)
end

return shadow:shadow(roleUICommon, 0)