--- Hammerstone: logging.lua
--- @author SirLich

local debugUI = mjrequire "hammerstone/ui/debugUI"

local logging = {}

function logging:log(msg)
	mj:log("[Hammerstone] ", msg)
	debugUI:log("[Info] " .. msg)
end

function logging:warning(msg)
	mj:warn("[Hammerstone] ", msg)
	debugUI:log("[Warning] " .. msg)
end

function logging:error(msg)
	mj:error("[Hammerstone] ", msg)
	debugUI:log("[Error] " .. msg)
end

return logging