-- Hammerstone: shadow.lua
-- @author SirLich

-- Hammerstone
local logging = mjrequire "hammerstone/logging"

local shadow = {}

-- Prepares a file to be shadowed by the base game.
-- @param outerModule - The module which you're shadowing.
-- @param loadOrder - The order in which this module should be called
-- @example - 'return shadow:shadow(sapienConstants, 0)' (to shadow sapienConstants)
function shadow:shadow(outerModule, loadOrder)
	-- Provide a load order for the module (optional)
	if loadOrder ~= nil then
		outerModule.loadOrder = loadOrder
	end

	-- @param parentModule is the actual base file from Sapiens
	-- @param outerModule is the current outer module (shadow), passed into shadow:shadow
	function outerModule:onload(parentModule)

		-- if the parentModule is a string, it means an error occured during "require"
		-- (probably due to patching)
		-- the string is the error message returned by pcall(require, ...) in the vanilla code
		-- of common/modManager
		if type(parentModule) == "string" then
			logging:error("Error reading base game file:", parentModule)
			return
		end

		if outerModule.preload ~= nil then
			outerModule:preload(parentModule)
		end

		-- Loop over the parent module, and implement shadows
		for k, v in pairs(parentModule) do

			-- Every function gets shadowed, if possible
			if type(v) == "function" then
				-- Just for clarity
				local functionName = k
				local functionValue = v

				-- If function exists in the outer, configure the shadow
				if outerModule[functionName] ~= nil then

					local superFunction = functionValue
					parentModule[functionName] = function(...)

						local selfArg = select(1, ...)
						return outerModule[functionName](selfArg, superFunction, select(2, ...)) -- Return and call the result
					end
				end
			end
		end

		-- Loop over the outer module, and inject values back into the parent
		for k, v in pairs(outerModule) do
			-- Functions need special care, to avoid overwriting the shadows
			if type(v) == "function" then
				if parentModule[k] == nil then
					parentModule[k] = v
				end

			-- Values are copied over directly
			else
				parentModule[k] = v
			end
		end

		if outerModule.postload ~= nil then
			outerModule:postload(parentModule)
		end
	end



	return outerModule
end

return shadow