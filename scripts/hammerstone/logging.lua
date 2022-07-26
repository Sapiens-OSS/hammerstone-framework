--- Hammerstone: logging.lua
--- @author SirLich

local logging = {}

function logging:log(msg)
	mj:log("[Hammerstone] ", msg)
end

function logging:warning(msg)
	mj:warning("[Hammerstone] ", msg)
end

function logging:error(msg)
	mj:error("[Hammerstone] ", msg)
end

return logging