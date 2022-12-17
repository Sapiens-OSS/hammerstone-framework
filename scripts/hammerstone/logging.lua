--- Hammerstone: logging.lua
--- @author SirLich

local logging = {}

local function enforceValid(msg)
	if msg == nil  then
		return "Nil"
	else
		return msg
	end
end

function logging:log(msg)
	mj:log("[Hammerstone] ", enforceValid(msg))
end

--- @deprecated, use logging:warn instead
function logging:warning(msg)
	mj:warn("[Hammerstone] ", enforceValid(msg))
end

function logging:warn(msg)
	mj:warn("[Hammerstone] ", enforceValid(msg))
end

function logging:error(msg)
	mj:error("[Hammerstone] ", enforceValid(msg))
end

return logging