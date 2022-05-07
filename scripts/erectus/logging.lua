--- Logging wrappers for the erectus framework
-- @author SirLich

local logging = {}

function logging:log(msg)
	mj:log("[Erectus] " .. msg)
end

function logging:warning(msg)
	mj:warning("[Erectus] " .. msg)
end

function logging:error(msg)
	mj:error("[Erectus] " .. msg)
end


return logging