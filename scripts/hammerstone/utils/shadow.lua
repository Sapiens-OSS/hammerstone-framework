-- Hammerstone: shadow.lua
-- @author SirLich

local shadow = {}

-- Prepares a file to be shadowed by the base game.
-- @param outerModule - The module which you're shadowing.
-- @param loadOrder - The order in which this module should be called
-- @example - 'return shadow:shadow(sapienConstants, 0)' (to shadow sapienConstants)
function shadow:shadow(outerModule, loadOrder)
	-- Provide a load order for the module
	if loadOrder ~= nil then
		outerModule.loadOrder = loadOrder
	end

	-- @param parentModule is the actual base file from Sapiens
	-- @param outerModule is the current outer module (shadow), passed into shadow:shadow
	function outerModule:onload(parentModule)

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

						-- @param FIRST  is the function to run, to access base game functionality
						-- @param 'SECOND is the 'self' param pointing to the module

						local packedArgs = {...}
						table.insert(packedArgs, 2, superFunction) -- Insert super into second position, so it's available, but not treated as the 'self' arg.
						return outerModule[functionName](unpack(packedArgs)) -- Return and call the result
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